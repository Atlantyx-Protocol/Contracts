// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HashedTimelockERC20} from "../src/HTLCErc20.sol";

// Refunds an open HTLC after expiry. Must be called by the original sender.
contract RefundHTLCErc20 is Script {
    function run() public {
        address htlcAddr = vm.envAddress("HTLC");
        bytes32 id = vm.envBytes32("ID");

        HashedTimelockERC20 htlc = HashedTimelockERC20(htlcAddr);

        vm.startBroadcast();
        htlc.refund(id);
        vm.stopBroadcast();
    }
}
