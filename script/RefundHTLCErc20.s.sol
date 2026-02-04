// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HashedTimelockERC20} from "../src/HTLCErc20.sol";

// Refunds an open HTLC order after expiry. Must be called by the original sender.
// Refunds only the remaining unclaimed amount.
contract RefundHTLCErc20 is Script {
    function run() public {
        address htlcAddr = vm.envAddress("HTLC");
        uint256 orderId = vm.envUint("ORDER_ID");

        HashedTimelockERC20 htlc = HashedTimelockERC20(htlcAddr);

        vm.startBroadcast();
        htlc.refund(orderId);
        vm.stopBroadcast();
    }
}
