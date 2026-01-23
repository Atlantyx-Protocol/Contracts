// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HashedTimelockERC20} from "../src/HTLCErc20.sol";
import {USDC} from "../src/USDC.sol";

contract HashedTimelockERC20Test is Test {
    HashedTimelockERC20 private htlcStrict; // disallow withdraw after expiry
    HashedTimelockERC20 private htlcLenient; // allow withdraw after expiry
    USDC private token;

    address private sender = makeAddr("sender");
    address private receiver = makeAddr("receiver");
    address private stranger = makeAddr("stranger");

    bytes32 private constant PREIMAGE = bytes32("super-secret");
    uint256 private constant ONE_TOKEN = 10 ** 6; // USDC decimals

    function setUp() public {
        vm.warp(1_000_000); // predictable timestamps across tests

        token = new USDC();
        htlcStrict = new HashedTimelockERC20(false);
        htlcLenient = new HashedTimelockERC20(true);

        token.transfer(sender, 100_000 * ONE_TOKEN);
    }

    function test_NewContractStoresStateAndEmitsEvent() public {
        uint256 amount = 5_000 * ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;
        bytes32 hashlock = _hashlock();
        uint64 nonceBefore = htlcStrict.nonces(sender);
        bytes32 expectedId = _expectedId(sender, receiver, address(token), amount, hashlock, timelock, nonceBefore);

        vm.prank(sender);
        token.approve(address(htlcStrict), amount);

        vm.expectEmit(true, true, true, true, address(htlcStrict));
        emit HashedTimelockERC20.HTLCNew(
            expectedId, sender, receiver, address(token), amount, hashlock, timelock, nonceBefore
        );

        vm.prank(sender);
        bytes32 id = htlcStrict.newContract(receiver, hashlock, timelock, address(token), amount);

        assertEq(id, expectedId, "id derived from inputs");
        assertEq(htlcStrict.nonces(sender), nonceBefore + 1, "nonce consumed");

        HashedTimelockERC20.LockContract memory c = htlcStrict.getContract(id);
        assertEq(c.sender, sender);
        assertEq(c.receiver, receiver);
        assertEq(c.token, address(token));
        assertEq(c.amount, amount);
        assertEq(uint8(c.status), uint8(HashedTimelockERC20.Status.OPEN));
        assertEq(c.timelock, timelock);
        assertEq(c.hashlock, hashlock);
        assertEq(c.preimage, bytes32(0));
        assertEq(c.nonce, nonceBefore);
    }

    function test_NewContractInvalidParamsRevert() public {
        uint256 amount = ONE_TOKEN;
        uint256 timelock = block.timestamp + 1 days;
        bytes32 hashlock = _hashlock();

        vm.expectRevert(HashedTimelockERC20.ZeroAddress.selector);
        htlcStrict.newContract(address(0), hashlock, timelock, address(token), amount);

        vm.expectRevert(HashedTimelockERC20.ZeroAddress.selector);
        htlcStrict.newContract(receiver, hashlock, timelock, address(0), amount);

        vm.expectRevert(HashedTimelockERC20.AmountZero.selector);
        htlcStrict.newContract(receiver, hashlock, timelock, address(token), 0);

        vm.expectRevert(HashedTimelockERC20.TimelockNotFuture.selector);
        htlcStrict.newContract(receiver, hashlock, block.timestamp, address(token), amount);
    }

    function test_WithdrawWithCorrectPreimage() public {
        (bytes32 id, uint256 amount) = _openLock(htlcStrict, block.timestamp + 1 days, 1_000 * ONE_TOKEN);

        vm.prank(receiver);
        vm.expectEmit(true, true, true, true, address(htlcStrict));
        emit HashedTimelockERC20.HTLCWithdraw(id, PREIMAGE);

        uint256 receiverBalBefore = token.balanceOf(receiver);
        vm.prank(receiver);
        htlcStrict.withdraw(id, PREIMAGE);

        HashedTimelockERC20.LockContract memory c = htlcStrict.getContract(id);
        assertEq(uint8(c.status), uint8(HashedTimelockERC20.Status.WITHDRAWN));
        assertEq(c.preimage, PREIMAGE);
        assertEq(token.balanceOf(receiver), receiverBalBefore + amount);
    }

    function test_WithdrawRejectsWrongCallerOrHash() public {
        (bytes32 id,) = _openLock(htlcStrict, block.timestamp + 1 days, 750 * ONE_TOKEN);

        vm.prank(stranger);
        vm.expectRevert(HashedTimelockERC20.NotReceiver.selector);
        htlcStrict.withdraw(id, PREIMAGE);

        vm.prank(receiver);
        vm.expectRevert(HashedTimelockERC20.HashlockMismatch.selector);
        htlcStrict.withdraw(id, bytes32("bad"));
    }

    function test_WithdrawAfterExpiryHonorsPolicyFlag() public {
        uint256 timelock = block.timestamp + 2 days;

        (bytes32 strictId,) = _openLock(htlcStrict, timelock, 100 * ONE_TOKEN);
        (bytes32 lenientId, uint256 lenientAmount) = _openLock(htlcLenient, timelock, 200 * ONE_TOKEN);

        vm.warp(timelock + 1);

        vm.prank(receiver);
        vm.expectRevert(HashedTimelockERC20.WithdrawAfterExpiryDisallowed.selector);
        htlcStrict.withdraw(strictId, PREIMAGE);

        uint256 receiverBalBefore = token.balanceOf(receiver);
        vm.prank(receiver);
        htlcLenient.withdraw(lenientId, PREIMAGE);

        HashedTimelockERC20.LockContract memory c = htlcLenient.getContract(lenientId);
        assertEq(uint8(c.status), uint8(HashedTimelockERC20.Status.WITHDRAWN));
        assertEq(token.balanceOf(receiver), receiverBalBefore + lenientAmount);
    }

    function test_RefundOnlySenderAfterTimelock() public {
        uint256 timelock = block.timestamp + 12 hours;
        (bytes32 id, uint256 amount) = _openLock(htlcStrict, timelock, 2_500 * ONE_TOKEN);

        vm.expectRevert(HashedTimelockERC20.TimelockNotExpired.selector);
        vm.prank(sender);
        htlcStrict.refund(id);

        vm.warp(timelock + 1);

        vm.expectRevert(HashedTimelockERC20.NotSender.selector);
        vm.prank(receiver);
        htlcStrict.refund(id);

        uint256 senderBalBefore = token.balanceOf(sender);
        vm.expectEmit(true, true, true, true, address(htlcStrict));
        emit HashedTimelockERC20.HTLCRefund(id);
        vm.prank(sender);
        htlcStrict.refund(id);

        HashedTimelockERC20.LockContract memory c = htlcStrict.getContract(id);
        assertEq(uint8(c.status), uint8(HashedTimelockERC20.Status.REFUNDED));
        assertEq(token.balanceOf(sender), senderBalBefore + amount);
    }

    function _openLock(HashedTimelockERC20 target, uint256 timelock, uint256 amount)
        internal
        returns (bytes32 id, uint256 lockedAmount)
    {
        bytes32 hashlock = _hashlock();

        vm.prank(sender);
        token.approve(address(target), amount);

        vm.prank(sender);
        id = target.newContract(receiver, hashlock, timelock, address(token), amount);

        HashedTimelockERC20.LockContract memory c = target.getContract(id);
        lockedAmount = c.amount;
    }

    function _hashlock() internal pure returns (bytes32) {
        return sha256(abi.encodePacked(PREIMAGE));
    }

    function _expectedId(
        address _sender,
        address _receiver,
        address _token,
        uint256 _amount,
        bytes32 hashlock_,
        uint256 _timelock,
        uint64 _nonce
    ) internal pure returns (bytes32) {
        return sha256(abi.encode(_sender, _receiver, _token, _amount, hashlock_, _timelock, _nonce));
    }
}
