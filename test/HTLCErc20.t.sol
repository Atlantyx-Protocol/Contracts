// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HashedTimelockERC20} from "../src/HTLCErc20.sol";
import {USDC} from "../src/USDC.sol";

contract HashedTimelockERC20Test is Test {
    HashedTimelockERC20 private htlcStrict; // disallow claim after expiry
    HashedTimelockERC20 private htlcLenient; // allow claim after expiry
    USDC private token;

    address private sender = makeAddr("sender");
    address private receiver1 = makeAddr("receiver1");
    address private receiver2 = makeAddr("receiver2");
    address private stranger = makeAddr("stranger");

    bytes32 private constant PREIMAGE1 = bytes32("secret-one");
    bytes32 private constant PREIMAGE2 = bytes32("secret-two");
    uint256 private constant ONE_TOKEN = 10 ** 6; // USDC decimals

    function setUp() public {
        vm.warp(1_000_000); // predictable timestamps across tests

        token = new USDC();
        htlcStrict = new HashedTimelockERC20(false);
        htlcLenient = new HashedTimelockERC20(true);

        token.transfer(sender, 100_000 * ONE_TOKEN);
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // ORDER CREATION TESTS
    // ──────────────────────────────────────────────────────────────────────────────

    function test_NewOrderStoresStateAndEmitsEvents() public {
        uint256 amount1 = 3_000 * ONE_TOKEN;
        uint256 amount2 = 2_000 * ONE_TOKEN;
        uint256 totalAmount = amount1 + amount2;
        uint256 timelock = block.timestamp + 1 days;
        bytes32 hashlock1 = _hashlock(PREIMAGE1);
        bytes32 hashlock2 = _hashlock(PREIMAGE2);

        address[] memory receivers = new address[](2);
        receivers[0] = receiver1;
        receivers[1] = receiver2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        bytes32[] memory hashlocks = new bytes32[](2);
        hashlocks[0] = hashlock1;
        hashlocks[1] = hashlock2;

        vm.prank(sender);
        token.approve(address(htlcStrict), totalAmount);

        // Expect OrderCreated event
        vm.expectEmit(true, true, true, true, address(htlcStrict));
        emit HashedTimelockERC20.OrderCreated(1, sender, address(token), totalAmount, timelock, 2);

        vm.prank(sender);
        uint256 orderId = htlcStrict.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(token),
                totalAmount: totalAmount,
                timelock: timelock,
                receivers: receivers,
                amounts: amounts,
                hashlocks: hashlocks,
                onBehalfOf: address(0)
            })
        );

        assertEq(orderId, 1, "first order should have id 1");
        assertEq(htlcStrict.nextOrderId(), 2, "next order id incremented");

        // Verify order state
        HashedTimelockERC20.Order memory order = htlcStrict.getOrder(orderId);
        assertEq(order.sender, sender);
        assertEq(order.token, address(token));
        assertEq(order.totalAmount, totalAmount);
        assertEq(order.remainingAmount, totalAmount);
        assertEq(order.timelock, timelock);
        assertEq(uint8(order.status), uint8(HashedTimelockERC20.OrderStatus.OPEN));
        assertEq(order.fillCount, 2);

        // Verify fill 0
        HashedTimelockERC20.Fill memory fill0 = htlcStrict.getFill(orderId, 0);
        assertEq(fill0.receiver, receiver1);
        assertEq(fill0.amount, amount1);
        assertEq(fill0.hashlock, hashlock1);
        assertFalse(fill0.claimed);

        // Verify fill 1
        HashedTimelockERC20.Fill memory fill1 = htlcStrict.getFill(orderId, 1);
        assertEq(fill1.receiver, receiver2);
        assertEq(fill1.amount, amount2);
        assertEq(fill1.hashlock, hashlock2);
        assertFalse(fill1.claimed);
    }

    function test_NewOrderSingleFill() public {
        uint256 amount = 5_000 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);

        HashedTimelockERC20.Order memory order = htlcStrict.getOrder(orderId);
        assertEq(order.fillCount, 1);
        assertEq(order.totalAmount, amount);
    }

    function test_NewOrderInvalidParamsRevert() public {
        uint256 amount = ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;
        bytes32 hashlock = _hashlock(PREIMAGE1);

        address[] memory receivers = new address[](1);
        receivers[0] = receiver1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes32[] memory hashlocks = new bytes32[](1);
        hashlocks[0] = hashlock;

        // Zero token address
        vm.expectRevert(HashedTimelockERC20.ZeroAddress.selector);
        htlcStrict.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(0),
                totalAmount: amount,
                timelock: timelock,
                receivers: receivers,
                amounts: amounts,
                hashlocks: hashlocks,
                onBehalfOf: address(0)
            })
        );

        // Zero total amount
        vm.expectRevert(HashedTimelockERC20.AmountZero.selector);
        htlcStrict.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(token),
                totalAmount: 0,
                timelock: timelock,
                receivers: receivers,
                amounts: amounts,
                hashlocks: hashlocks,
                onBehalfOf: address(0)
            })
        );

        // Timelock not in future
        vm.expectRevert(HashedTimelockERC20.TimelockNotFuture.selector);
        htlcStrict.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(token),
                totalAmount: amount,
                timelock: block.timestamp,
                receivers: receivers,
                amounts: amounts,
                hashlocks: hashlocks,
                onBehalfOf: address(0)
            })
        );

        // Zero receiver address
        address[] memory badReceivers = new address[](1);
        badReceivers[0] = address(0);

        vm.expectRevert(HashedTimelockERC20.ZeroAddress.selector);
        htlcStrict.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(token),
                totalAmount: amount,
                timelock: timelock,
                receivers: badReceivers,
                amounts: amounts,
                hashlocks: hashlocks,
                onBehalfOf: address(0)
            })
        );

        // Zero fill amount
        uint256[] memory badAmounts = new uint256[](1);
        badAmounts[0] = 0;

        vm.expectRevert(HashedTimelockERC20.AmountZero.selector);
        htlcStrict.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(token),
                totalAmount: amount,
                timelock: timelock,
                receivers: receivers,
                amounts: badAmounts,
                hashlocks: hashlocks,
                onBehalfOf: address(0)
            })
        );

        // Empty fills
        vm.expectRevert(HashedTimelockERC20.EmptyFills.selector);
        htlcStrict.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(token),
                totalAmount: amount,
                timelock: timelock,
                receivers: new address[](0),
                amounts: new uint256[](0),
                hashlocks: new bytes32[](0),
                onBehalfOf: address(0)
            })
        );

        // Array length mismatch
        uint256[] memory twoAmounts = new uint256[](2);
        twoAmounts[0] = amount / 2;
        twoAmounts[1] = amount / 2;

        vm.expectRevert(HashedTimelockERC20.ArrayLengthMismatch.selector);
        htlcStrict.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(token),
                totalAmount: amount,
                timelock: timelock,
                receivers: receivers, // length 1
                amounts: twoAmounts, // length 2
                hashlocks: hashlocks, // length 1
                onBehalfOf: address(0)
            })
        );
    }

    function test_NewOrderTotalAmountMismatchReverts() public {
        uint256 timelock = block.timestamp + 1 days;

        address[] memory receivers = new address[](2);
        receivers[0] = receiver1;
        receivers[1] = receiver2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 600 * ONE_TOKEN;
        amounts[1] = 500 * ONE_TOKEN; // sum = 1100

        bytes32[] memory hashlocks = new bytes32[](2);
        hashlocks[0] = _hashlock(PREIMAGE1);
        hashlocks[1] = _hashlock(PREIMAGE2);

        // Only approve/transfer 1000, but fills sum to 1100
        vm.prank(sender);
        token.approve(address(htlcStrict), 1000 * ONE_TOKEN);

        vm.prank(sender);
        vm.expectRevert(HashedTimelockERC20.TotalAmountMismatch.selector);
        htlcStrict.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(token),
                totalAmount: 1000 * ONE_TOKEN,
                timelock: timelock,
                receivers: receivers,
                amounts: amounts,
                hashlocks: hashlocks,
                onBehalfOf: address(0)
            })
        );
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // CLAIM TESTS
    // ──────────────────────────────────────────────────────────────────────────────

    function test_WithdrawWithCorrectPreimage() public {
        uint256 amount = 1_000 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);

        uint256 receiverBalBefore = token.balanceOf(receiver1);

        vm.expectEmit(true, true, true, true, address(htlcStrict));
        emit HashedTimelockERC20.FillWithdrawn(orderId, 0, receiver1, PREIMAGE1);

        vm.prank(receiver1);
        htlcStrict.withdraw(orderId, 0, PREIMAGE1);

        // Verify fill is claimed
        HashedTimelockERC20.Fill memory fill = htlcStrict.getFill(orderId, 0);
        assertTrue(fill.claimed);

        // Verify order remaining amount decreased
        HashedTimelockERC20.Order memory order = htlcStrict.getOrder(orderId);
        assertEq(order.remainingAmount, 0);

        // Verify receiver got tokens
        assertEq(token.balanceOf(receiver1), receiverBalBefore + amount);
    }

    function test_WithdrawMultipleFillsIndependently() public {
        uint256 amount1 = 600 * ONE_TOKEN;
        uint256 amount2 = 400 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createTwoFillOrder(htlcStrict, amount1, amount2, timelock);

        // Receiver2 claims fill 1 first
        uint256 receiver2BalBefore = token.balanceOf(receiver2);
        vm.prank(receiver2);
        htlcStrict.withdraw(orderId, 1, PREIMAGE2);

        assertEq(token.balanceOf(receiver2), receiver2BalBefore + amount2);

        HashedTimelockERC20.Order memory orderAfterFirst = htlcStrict.getOrder(orderId);
        assertEq(orderAfterFirst.remainingAmount, amount1);

        // Receiver1 claims fill 0
        uint256 receiver1BalBefore = token.balanceOf(receiver1);
        vm.prank(receiver1);
        htlcStrict.withdraw(orderId, 0, PREIMAGE1);

        assertEq(token.balanceOf(receiver1), receiver1BalBefore + amount1);

        HashedTimelockERC20.Order memory orderAfterBoth = htlcStrict.getOrder(orderId);
        assertEq(orderAfterBoth.remainingAmount, 0);

        // Verify claim status
        (uint256 claimed, uint256 total) = htlcStrict.getClaimStatus(orderId);
        assertEq(claimed, 2);
        assertEq(total, 2);
    }

    function test_WithdrawRejectsWrongCallerOrHash() public {
        uint256 amount = 750 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);

        // Stranger cannot claim
        vm.prank(stranger);
        vm.expectRevert(HashedTimelockERC20.NotReceiver.selector);
        htlcStrict.withdraw(orderId, 0, PREIMAGE1);

        // Wrong preimage
        vm.prank(receiver1);
        vm.expectRevert(HashedTimelockERC20.HashlockMismatch.selector);
        htlcStrict.withdraw(orderId, 0, bytes32("wrong"));
    }

    function test_WithdrawRejectsDoubleClaim() public {
        uint256 amount = 500 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);

        vm.prank(receiver1);
        htlcStrict.withdraw(orderId, 0, PREIMAGE1);

        // Try to claim again
        vm.prank(receiver1);
        vm.expectRevert(HashedTimelockERC20.FillAlreadyClaimed.selector);
        htlcStrict.withdraw(orderId, 0, PREIMAGE1);
    }

    function test_WithdrawRejectsInvalidFillId() public {
        uint256 amount = 500 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);

        vm.prank(receiver1);
        vm.expectRevert(HashedTimelockERC20.FillNotFound.selector);
        htlcStrict.withdraw(orderId, 1, PREIMAGE1); // Only fill 0 exists
    }

    function test_WithdrawRejectsNonExistentOrder() public {
        vm.prank(receiver1);
        vm.expectRevert(HashedTimelockERC20.OrderNotFound.selector);
        htlcStrict.withdraw(999, 0, PREIMAGE1);
    }

    function test_WithdrawAfterExpiryHonorsPolicyFlag() public {
        uint256 amount = 100 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 2 days;

        (uint256 strictOrderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);
        (uint256 lenientOrderId, uint256 lenientAmount) =
            _createSingleFillOrder(htlcLenient, receiver1, amount, timelock, PREIMAGE1);

        vm.warp(timelock + 1);

        // Strict: claim after expiry disallowed
        vm.prank(receiver1);
        vm.expectRevert(HashedTimelockERC20.WithdrawAfterExpiryDisallowed.selector);
        htlcStrict.withdraw(strictOrderId, 0, PREIMAGE1);

        // Lenient: claim after expiry allowed
        uint256 receiverBalBefore = token.balanceOf(receiver1);
        vm.prank(receiver1);
        htlcLenient.withdraw(lenientOrderId, 0, PREIMAGE1);

        HashedTimelockERC20.Fill memory fill = htlcLenient.getFill(lenientOrderId, 0);
        assertTrue(fill.claimed);
        assertEq(token.balanceOf(receiver1), receiverBalBefore + lenientAmount);
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // REFUND TESTS
    // ──────────────────────────────────────────────────────────────────────────────

    function test_RefundOnlySenderAfterTimelock() public {
        uint256 amount = 2_500 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 12 hours;

        (uint256 orderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);

        // Before timelock: refund fails
        vm.expectRevert(HashedTimelockERC20.TimelockNotExpired.selector);
        vm.prank(sender);
        htlcStrict.refund(orderId);

        vm.warp(timelock + 1);

        // Non-sender cannot refund
        vm.expectRevert(HashedTimelockERC20.NotSender.selector);
        vm.prank(receiver1);
        htlcStrict.refund(orderId);

        // Sender refunds successfully
        uint256 senderBalBefore = token.balanceOf(sender);

        vm.expectEmit(true, true, true, true, address(htlcStrict));
        emit HashedTimelockERC20.OrderRefunded(orderId, amount);

        vm.prank(sender);
        htlcStrict.refund(orderId);

        HashedTimelockERC20.Order memory order = htlcStrict.getOrder(orderId);
        assertEq(uint8(order.status), uint8(HashedTimelockERC20.OrderStatus.REFUNDED));
        assertEq(order.remainingAmount, 0);
        assertEq(token.balanceOf(sender), senderBalBefore + amount);
    }

    function test_RefundOnlyRemainingAmount() public {
        uint256 amount1 = 600 * ONE_TOKEN;
        uint256 amount2 = 400 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createTwoFillOrder(htlcStrict, amount1, amount2, timelock);

        // Receiver1 claims their fill
        vm.prank(receiver1);
        htlcStrict.withdraw(orderId, 0, PREIMAGE1);

        vm.warp(timelock + 1);

        // Sender refunds only unclaimed amount (receiver2's portion)
        uint256 senderBalBefore = token.balanceOf(sender);

        vm.prank(sender);
        htlcStrict.refund(orderId);

        // Only amount2 should be refunded
        assertEq(token.balanceOf(sender), senderBalBefore + amount2);
    }

    function test_RefundAfterAllClaimsReturnsZero() public {
        uint256 amount = 500 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);

        // Claim the fill
        vm.prank(receiver1);
        htlcStrict.withdraw(orderId, 0, PREIMAGE1);

        vm.warp(timelock + 1);

        // Refund should succeed but transfer 0
        uint256 senderBalBefore = token.balanceOf(sender);

        vm.prank(sender);
        htlcStrict.refund(orderId);

        assertEq(token.balanceOf(sender), senderBalBefore); // No change
    }

    function test_RefundBlocksSubsequentClaims() public {
        uint256 amount1 = 600 * ONE_TOKEN;
        uint256 amount2 = 400 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createTwoFillOrder(htlcStrict, amount1, amount2, timelock);

        vm.warp(timelock + 1);

        // Sender refunds
        vm.prank(sender);
        htlcStrict.refund(orderId);

        // Claims should now fail (order is REFUNDED)
        vm.prank(receiver1);
        vm.expectRevert(HashedTimelockERC20.NotOpen.selector);
        htlcStrict.withdraw(orderId, 0, PREIMAGE1);
    }

    function test_DoubleRefundFails() public {
        uint256 amount = 500 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);

        vm.warp(timelock + 1);

        vm.prank(sender);
        htlcStrict.refund(orderId);

        vm.prank(sender);
        vm.expectRevert(HashedTimelockERC20.NotOpen.selector);
        htlcStrict.refund(orderId);
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // VIEW FUNCTION TESTS
    // ──────────────────────────────────────────────────────────────────────────────

    function test_GetOrderFillsReturnsAllFills() public {
        uint256 amount1 = 600 * ONE_TOKEN;
        uint256 amount2 = 400 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createTwoFillOrder(htlcStrict, amount1, amount2, timelock);

        HashedTimelockERC20.Fill[] memory fills = htlcStrict.getOrderFills(orderId);

        assertEq(fills.length, 2);
        assertEq(fills[0].receiver, receiver1);
        assertEq(fills[0].amount, amount1);
        assertEq(fills[1].receiver, receiver2);
        assertEq(fills[1].amount, amount2);
    }

    function test_OrderExistsCheck() public {
        assertFalse(htlcStrict.orderExistsCheck(1));

        uint256 amount = 500 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);

        assertTrue(htlcStrict.orderExistsCheck(orderId));
        assertFalse(htlcStrict.orderExistsCheck(999));
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // HELPER FUNCTIONS
    // ──────────────────────────────────────────────────────────────────────────────

    function _createSingleFillOrder(
        HashedTimelockERC20 target,
        address receiver,
        uint256 amount,
        uint256 timelock,
        bytes32 preimage
    ) internal returns (uint256 orderId, uint256 lockedAmount) {
        address[] memory receivers = new address[](1);
        receivers[0] = receiver;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes32[] memory hashlocks = new bytes32[](1);
        hashlocks[0] = _hashlock(preimage);

        vm.prank(sender);
        token.approve(address(target), amount);

        vm.prank(sender);
        orderId = target.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(token),
                totalAmount: amount,
                timelock: timelock,
                receivers: receivers,
                amounts: amounts,
                hashlocks: hashlocks,
                onBehalfOf: address(0)
            })
        );

        HashedTimelockERC20.Order memory order = target.getOrder(orderId);
        lockedAmount = order.totalAmount;
    }

    function _createTwoFillOrder(HashedTimelockERC20 target, uint256 amount1, uint256 amount2, uint256 timelock)
        internal
        returns (uint256 orderId, uint256 totalLocked)
    {
        address[] memory receivers = new address[](2);
        receivers[0] = receiver1;
        receivers[1] = receiver2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        bytes32[] memory hashlocks = new bytes32[](2);
        hashlocks[0] = _hashlock(PREIMAGE1);
        hashlocks[1] = _hashlock(PREIMAGE2);

        uint256 totalAmount = amount1 + amount2;

        vm.prank(sender);
        token.approve(address(target), totalAmount);

        vm.prank(sender);
        orderId = target.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(token),
                totalAmount: totalAmount,
                timelock: timelock,
                receivers: receivers,
                amounts: amounts,
                hashlocks: hashlocks,
                onBehalfOf: address(0)
            })
        );

        HashedTimelockERC20.Order memory order = target.getOrder(orderId);
        totalLocked = order.totalAmount;
    }

    function _hashlock(bytes32 preimage) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(preimage));
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // ADMIN TESTS
    // ──────────────────────────────────────────────────────────────────────────────

    address private admin = makeAddr("admin");

    function test_AddAdminOnlyOwner() public {
        // Non-owner cannot add admin
        vm.prank(stranger);
        vm.expectRevert(HashedTimelockERC20.NotOwner.selector);
        htlcStrict.addAdmin(admin);

        // Owner can add admin
        vm.expectEmit(true, false, false, false, address(htlcStrict));
        emit HashedTimelockERC20.AdminAdded(admin);

        htlcStrict.addAdmin(admin);
        assertTrue(htlcStrict.admins(admin));
    }

    function test_AddAdminZeroAddressReverts() public {
        vm.expectRevert(HashedTimelockERC20.ZeroAddress.selector);
        htlcStrict.addAdmin(address(0));
    }

    function test_RemoveAdminOnlyOwner() public {
        htlcStrict.addAdmin(admin);

        // Non-owner cannot remove admin
        vm.prank(stranger);
        vm.expectRevert(HashedTimelockERC20.NotOwner.selector);
        htlcStrict.removeAdmin(admin);

        // Owner can remove admin
        vm.expectEmit(true, false, false, false, address(htlcStrict));
        emit HashedTimelockERC20.AdminRemoved(admin);

        htlcStrict.removeAdmin(admin);
        assertFalse(htlcStrict.admins(admin));
    }

    function test_AdminCanCreateOrderOnBehalfOfUser() public {
        htlcStrict.addAdmin(admin);

        uint256 amount = 1_000 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        address[] memory receivers = new address[](1);
        receivers[0] = receiver1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes32[] memory hashlocks = new bytes32[](1);
        hashlocks[0] = _hashlock(PREIMAGE1);

        // sender approves the contract for the admin to pull from
        vm.prank(sender);
        token.approve(address(htlcStrict), amount);

        vm.prank(admin);
        uint256 orderId = htlcStrict.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(token),
                totalAmount: amount,
                timelock: timelock,
                receivers: receivers,
                amounts: amounts,
                hashlocks: hashlocks,
                onBehalfOf: sender
            })
        );

        HashedTimelockERC20.Order memory order = htlcStrict.getOrder(orderId);
        // Order sender is the user, not the admin
        assertEq(order.sender, sender);
        assertEq(order.totalAmount, amount);
    }

    function test_NonAdminCannotCreateOrderOnBehalfOfUser() public {
        uint256 amount = 1_000 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        address[] memory receivers = new address[](1);
        receivers[0] = receiver1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes32[] memory hashlocks = new bytes32[](1);
        hashlocks[0] = _hashlock(PREIMAGE1);

        vm.prank(stranger);
        vm.expectRevert(HashedTimelockERC20.NotAdmin.selector);
        htlcStrict.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: address(token),
                totalAmount: amount,
                timelock: timelock,
                receivers: receivers,
                amounts: amounts,
                hashlocks: hashlocks,
                onBehalfOf: sender
            })
        );
    }

    function test_AdminCanWithdrawOnBehalfOfReceiver() public {
        htlcStrict.addAdmin(admin);

        uint256 amount = 1_000 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);

        uint256 receiverBalBefore = token.balanceOf(receiver1);

        // Admin calls withdraw; tokens still go to receiver1
        vm.prank(admin);
        htlcStrict.withdraw(orderId, 0, PREIMAGE1);

        HashedTimelockERC20.Fill memory fill = htlcStrict.getFill(orderId, 0);
        assertTrue(fill.claimed);
        assertEq(token.balanceOf(receiver1), receiverBalBefore + amount);
    }

    function test_NonAdminStrangerCannotWithdraw() public {
        uint256 amount = 1_000 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);

        vm.prank(stranger);
        vm.expectRevert(HashedTimelockERC20.NotReceiver.selector);
        htlcStrict.withdraw(orderId, 0, PREIMAGE1);
    }

    function test_RemovedAdminCanNoLongerWithdraw() public {
        htlcStrict.addAdmin(admin);
        htlcStrict.removeAdmin(admin);

        uint256 amount = 1_000 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;

        (uint256 orderId,) = _createSingleFillOrder(htlcStrict, receiver1, amount, timelock, PREIMAGE1);

        vm.prank(admin);
        vm.expectRevert(HashedTimelockERC20.NotReceiver.selector);
        htlcStrict.withdraw(orderId, 0, PREIMAGE1);
    }
}
