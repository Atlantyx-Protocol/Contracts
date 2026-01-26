// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HashedTimelockERC20} from "../src/HTLCErc20.sol";

// Withdraws tokens from an HTLC by providing the preimage. Must be called by the receiver.
contract WithdrawHTLCErc20 is Script {
    function run() public {
        address htlcAddr = vm.envAddress("HTLC");
        bytes32 id = vm.envBytes32("ID");
        bytes32 preimage = vm.envBytes32("PREIMAGE");

        HashedTimelockERC20 htlc = HashedTimelockERC20(htlcAddr);

        vm.startBroadcast();
        htlc.withdraw(id, preimage);
        vm.stopBroadcast();
    }
}
