// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract HashedTimelockERC20 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ──────────────────────────────────────────────────────────────────────────────
    // ERRORS
    // ──────────────────────────────────────────────────────────────────────────────
    error ZeroAddress();
    error AmountZero();
    error TimelockNotFuture();
    error TimelockNotExpired();
    error NotSender();
    error NotReceiver();
    error NotOpen();
    error OrderNotFound();
    error FillNotFound();
    error FillAlreadyClaimed();
    error HashlockMismatch();
    error TransferInFailed();
    error WithdrawAfterExpiryDisallowed();
    error ArrayLengthMismatch();
    error EmptyFills();
    error TotalAmountMismatch();
    error NotOwner();
    error NotAdmin();

    // ──────────────────────────────────────────────────────────────────────────────
    // EVENTS
    // ──────────────────────────────────────────────────────────────────────────────
    event OrderCreated(
        uint256 indexed orderId,
        address indexed sender,
        address indexed token,
        uint256 totalAmount,
        uint256 timelock,
        uint256 fillCount
    );

    event FillCreated(
        uint256 indexed orderId, uint256 indexed fillId, address indexed receiver, uint256 amount, bytes32 hashlock
    );

    event FillWithdrawn(uint256 indexed orderId, uint256 indexed fillId, address indexed receiver, bytes32 preimage);

    event OrderRefunded(uint256 indexed orderId, uint256 refundedAmount);

    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);

    // ──────────────────────────────────────────────────────────────────────────────
    // TYPES
    // ──────────────────────────────────────────────────────────────────────────────

    enum OrderStatus {
        NONE,
        OPEN,
        REFUNDED
    }

    struct Order {
        address sender;
        address token;
        uint256 totalAmount;
        uint256 remainingAmount;
        uint256 timelock;
        OrderStatus status;
        uint256 fillCount;
    }

    struct Fill {
        address receiver;
        uint256 amount;
        bytes32 hashlock;
        bool claimed;
    }

    struct NewOrderParams {
        address token;
        uint256 totalAmount;
        uint256 timelock;
        address[] receivers;
        uint256[] amounts;
        bytes32[] hashlocks;
        // If non-zero and different from msg.sender, caller must be a whitelisted admin.
        // Tokens are pulled from this address and it becomes the order sender.
        address onBehalfOf;
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // STORAGE
    // ──────────────────────────────────────────────────────────────────────────────

    uint256 private _nextOrderId = 1;

    mapping(uint256 => Order) private _orders;

    mapping(uint256 => mapping(uint256 => Fill)) private _fills;

    bool public immutable allowWithdrawAfterExpiry;

    address public owner;

    mapping(address => bool) public admins;

    // ──────────────────────────────────────────────────────────────────────────────
    // CONSTRUCTOR
    // ──────────────────────────────────────────────────────────────────────────────

    constructor(bool _allowWithdrawAfterExpiry) {
        allowWithdrawAfterExpiry = _allowWithdrawAfterExpiry;
        owner = msg.sender;
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // MODIFIERS
    // ──────────────────────────────────────────────────────────────────────────────

    modifier orderExists(uint256 orderId) {
        if (_orders[orderId].status == OrderStatus.NONE) revert OrderNotFound();
        _;
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // EXTERNAL FUNCTIONS
    // ──────────────────────────────────────────────────────────────────────────────

    function addAdmin(address admin) external {
        if (msg.sender != owner) revert NotOwner();
        if (admin == address(0)) revert ZeroAddress();
        if (admins[admin]) return;
        admins[admin] = true;
        emit AdminAdded(admin);
    }

    function removeAdmin(address admin) external {
        if (msg.sender != owner) revert NotOwner();
        if (!admins[admin]) return;
        admins[admin] = false;
        emit AdminRemoved(admin);
    }

    function newOrder(NewOrderParams calldata params) external nonReentrant returns (uint256 orderId) {
        if (params.token == address(0)) revert ZeroAddress();
        if (params.totalAmount == 0) revert AmountZero();
        if (params.timelock <= block.timestamp) revert TimelockNotFuture();

        // Determine the effective sender (the user on whose behalf the order is created)
        address effectiveSender = (params.onBehalfOf != address(0)) ? params.onBehalfOf : msg.sender;
        if (effectiveSender != msg.sender && !admins[msg.sender]) revert NotAdmin();

        uint256 fillCount = params.receivers.length;
        if (fillCount == 0) revert EmptyFills();
        if (params.amounts.length != fillCount || params.hashlocks.length != fillCount) {
            revert ArrayLengthMismatch();
        }

        uint256 fillsSum = _validateAndSumFills(params.receivers, params.amounts);

        uint256 actualReceived = _transferIn(params.token, params.totalAmount, effectiveSender);

        // Sum of fill amounts must not exceed actual received tokens
        if (fillsSum > actualReceived) revert TotalAmountMismatch();

        // Create order
        orderId = _nextOrderId++;
        _orders[orderId] = Order({
            sender: effectiveSender,
            token: params.token,
            totalAmount: actualReceived,
            remainingAmount: fillsSum,
            timelock: params.timelock,
            status: OrderStatus.OPEN,
            fillCount: fillCount
        });

        emit OrderCreated(orderId, effectiveSender, params.token, actualReceived, params.timelock, fillCount);

        // Create fills
        _createFills(orderId, params.receivers, params.amounts, params.hashlocks);

        // Handle dust (return extra to effectiveSender if actualReceived > fillsSum)
        _returnDust(params.token, actualReceived, fillsSum, effectiveSender);
    }

    function withdraw(uint256 orderId, uint256 fillId, bytes32 preimage) external nonReentrant orderExists(orderId) {
        Order storage order = _orders[orderId];

        // Order validations
        if (order.status != OrderStatus.OPEN) revert NotOpen();

        if (!allowWithdrawAfterExpiry && block.timestamp >= order.timelock) {
            revert WithdrawAfterExpiryDisallowed();
        }

        // Fill validations
        if (fillId >= order.fillCount) revert FillNotFound();

        Fill storage fill = _fills[orderId][fillId];

        if (msg.sender != fill.receiver && !admins[msg.sender]) revert NotReceiver();
        if (fill.claimed) revert FillAlreadyClaimed();
        if (sha256(abi.encodePacked(preimage)) != fill.hashlock) revert HashlockMismatch();

        // Update state before transfer (CEI pattern)
        fill.claimed = true;
        order.remainingAmount -= fill.amount;

        // Transfer tokens to receiver
        IERC20(order.token).safeTransfer(fill.receiver, fill.amount);

        emit FillWithdrawn(orderId, fillId, fill.receiver, preimage);
    }

    function refund(uint256 orderId) external nonReentrant orderExists(orderId) {
        Order storage order = _orders[orderId];

        if (order.status != OrderStatus.OPEN) revert NotOpen();
        if (msg.sender != order.sender && !admins[msg.sender]) revert NotSender();
        if (block.timestamp < order.timelock) revert TimelockNotExpired();

        uint256 refundAmount = order.remainingAmount;

        // Update state before transfer (CEI pattern)
        order.status = OrderStatus.REFUNDED;
        order.remainingAmount = 0;

        // Transfer remaining tokens to sender
        if (refundAmount > 0) {
            IERC20(order.token).safeTransfer(order.sender, refundAmount);
        }

        emit OrderRefunded(orderId, refundAmount);
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // INTERNAL FUNCTIONS
    // ──────────────────────────────────────────────────────────────────────────────

    function _validateAndSumFills(address[] calldata receivers, uint256[] calldata amounts)
        internal
        pure
        returns (uint256 fillsSum)
    {
        uint256 len = receivers.length;
        for (uint256 i = 0; i < len; ++i) {
            if (receivers[i] == address(0)) revert ZeroAddress();
            if (amounts[i] == 0) revert AmountZero();
            fillsSum += amounts[i];
        }
    }

    function _transferIn(address token, uint256 amount, address from) internal returns (uint256 received) {
        IERC20 tokenContract = IERC20(token);
        uint256 balBefore = tokenContract.balanceOf(address(this));
        tokenContract.safeTransferFrom(from, address(this), amount);
        received = tokenContract.balanceOf(address(this)) - balBefore;
        if (received == 0) revert TransferInFailed();
    }

    function _createFills(
        uint256 orderId,
        address[] calldata receivers,
        uint256[] calldata amounts,
        bytes32[] calldata hashlocks
    ) internal {
        uint256 len = receivers.length;
        for (uint256 i = 0; i < len; ++i) {
            _fills[orderId][i] =
                Fill({receiver: receivers[i], amount: amounts[i], hashlock: hashlocks[i], claimed: false});

            emit FillCreated(orderId, i, receivers[i], amounts[i], hashlocks[i]);
        }
    }

    function _returnDust(address token, uint256 actualReceived, uint256 fillsSum, address to) internal {
        unchecked {
            uint256 dust = actualReceived - fillsSum;
            if (dust > 0) {
                IERC20(token).safeTransfer(to, dust);
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ──────────────────────────────────────────────────────────────────────────────

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return _orders[orderId];
    }

    function getFill(uint256 orderId, uint256 fillId) external view returns (Fill memory) {
        return _fills[orderId][fillId];
    }

    function getOrderFills(uint256 orderId) external view returns (Fill[] memory) {
        Order storage order = _orders[orderId];
        uint256 count = order.fillCount;

        Fill[] memory fills = new Fill[](count);
        for (uint256 i = 0; i < count; ++i) {
            fills[i] = _fills[orderId][i];
        }
        return fills;
    }

    function orderExistsCheck(uint256 orderId) external view returns (bool) {
        return _orders[orderId].status != OrderStatus.NONE;
    }

    function nextOrderId() external view returns (uint256) {
        return _nextOrderId;
    }

    function getClaimStatus(uint256 orderId) external view returns (uint256 claimed, uint256 total) {
        Order storage order = _orders[orderId];
        total = order.fillCount;

        for (uint256 i = 0; i < total; ++i) {
            if (_fills[orderId][i].claimed) {
                ++claimed;
            }
        }
    }
}
