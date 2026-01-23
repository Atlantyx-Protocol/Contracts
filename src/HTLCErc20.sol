// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title HashedTimelockERC20 (production-grade)
 * @notice Lock ERC20 tokens under a hashlock (SHA-256) and a timelock.
 */
contract HashedTimelockERC20 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------- Errors ----------
    error ZeroAddress();
    error AmountZero();
    error TimelockNotFuture();
    error TimelockNotExpired();
    error NotSender();
    error NotReceiver();
    error NotOpen();
    error HashlockMismatch();
    error ContractNotFound();
    error TransferInFailed();
    error WithdrawAfterExpiryDisallowed();

    // ---------- Events ----------
    event HTLCNew(
        bytes32 indexed id,
        address indexed sender,
        address indexed receiver,
        address token,
        uint256 amount,
        bytes32 hashlock,
        uint256 timelock,
        uint64 nonce
    );

    event HTLCWithdraw(bytes32 indexed id, bytes32 preimage);
    event HTLCRefund(bytes32 indexed id);

    // ---------- Types ----------
    enum Status {
        NONE,
        OPEN,
        WITHDRAWN,
        REFUNDED
    }

    struct LockContract {
        address sender;
        address receiver;
        address token;
        uint256 amount; // actual locked amount (post-fee if fee-on-transfer)
        bytes32 hashlock; // sha256(preimage)
        uint256 timelock; // unix seconds
        Status status;
        bytes32 preimage; // set on withdraw
        uint64 nonce; // per-sender nonce used in id
    }

    // ---------- Storage ----------
    mapping(bytes32 => LockContract) private _contracts;
    mapping(address => uint64) public nonces; // per-sender nonce

    // If false, withdraw allowed even after timelock (as long as not refunded)
    bool public immutable allowWithdrawAfterExpiry;

    constructor(bool _allowWithdrawAfterExpiry) {
        allowWithdrawAfterExpiry = _allowWithdrawAfterExpiry;
    }

    // ---------- Modifiers ----------
    modifier exists(bytes32 id) {
        if (_contracts[id].status == Status.NONE) revert ContractNotFound();
        _;
    }

    // ---------- Public/External ----------

    /**
     * @notice Create a new HTLC and lock tokens in this contract.
     * @dev Sender must approve this contract before calling.
     *
     * @param receiver receiver who can withdraw using preimage
     * @param hashlock sha256(preimage)
     * @param timelock unix timestamp when refund becomes available
     * @param token ERC20 token address
     * @param amount amount to attempt to lock (actual locked may be lower if token charges fees)
     *
     * @return id unique contract id
     */
    function newContract(address receiver, bytes32 hashlock, uint256 timelock, address token, uint256 amount)
        external
        nonReentrant
        returns (bytes32 id)
    {
        if (receiver == address(0) || token == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();
        if (timelock <= block.timestamp) revert TimelockNotFuture();

        // consume nonce first (unique per sender)
        uint64 nonce = nonces[msg.sender]++;
        id = _computeId(msg.sender, receiver, token, amount, hashlock, timelock, nonce);

        // prevent accidental overwrite (should not happen with nonce, but keep it tight)
        if (_contracts[id].status != Status.NONE) revert NotOpen();

        // Pull tokens and record actual received amount (fee-on-transfer support)
        IERC20 t = IERC20(token);
        uint256 balBefore = t.balanceOf(address(this));
        t.safeTransferFrom(msg.sender, address(this), amount);
        uint256 balAfter = t.balanceOf(address(this));
        uint256 received = balAfter - balBefore;
        if (received == 0) revert TransferInFailed();

        _contracts[id] = LockContract({
            sender: msg.sender,
            receiver: receiver,
            token: token,
            amount: received,
            hashlock: hashlock,
            timelock: timelock,
            status: Status.OPEN,
            preimage: bytes32(0),
            nonce: nonce
        });

        emit HTLCNew(id, msg.sender, receiver, token, received, hashlock, timelock, nonce);
    }

    /**
     * @notice Withdraw locked tokens by providing the correct preimage.
     * @param id HTLC id
     * @param preimage preimage x such that sha256(x) == hashlock
     */
    function withdraw(bytes32 id, bytes32 preimage) external nonReentrant exists(id) {
        LockContract storage c = _contracts[id];
        if (c.status != Status.OPEN) revert NotOpen();
        if (msg.sender != c.receiver) revert NotReceiver();

        if (!allowWithdrawAfterExpiry && block.timestamp >= c.timelock) {
            revert WithdrawAfterExpiryDisallowed();
        }

        if (sha256(abi.encodePacked(preimage)) != c.hashlock) revert HashlockMismatch();

        c.status = Status.WITHDRAWN;
        c.preimage = preimage;

        IERC20(c.token).safeTransfer(c.receiver, c.amount);
        emit HTLCWithdraw(id, preimage);
    }

    /**
     * @notice Refund locked tokens to sender after timelock if not withdrawn.
     * @param id HTLC id
     */
    function refund(bytes32 id) external nonReentrant exists(id) {
        LockContract storage c = _contracts[id];
        if (c.status != Status.OPEN) revert NotOpen();
        if (msg.sender != c.sender) revert NotSender();
        if (block.timestamp < c.timelock) revert TimelockNotExpired();

        c.status = Status.REFUNDED;

        IERC20(c.token).safeTransfer(c.sender, c.amount);
        emit HTLCRefund(id);
    }

    /**
     * @notice Read full contract details.
     */
    function getContract(bytes32 id) external view returns (LockContract memory) {
        return _contracts[id];
    }

    /**
     * @notice Convenience: check if an HTLC exists.
     */
    function existsContract(bytes32 id) external view returns (bool) {
        return _contracts[id].status != Status.NONE;
    }

    // ---------- Internal ----------

    function _computeId(
        address sender,
        address receiver,
        address token,
        uint256 amount,
        bytes32 hashlock,
        uint256 timelock,
        uint64 nonce
    ) internal pure returns (bytes32) {
        // Use abi.encode (not packed) to avoid any potential ambiguity.
        return sha256(abi.encode(sender, receiver, token, amount, hashlock, timelock, nonce));
    }
}
