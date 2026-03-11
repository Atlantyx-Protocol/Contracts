// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HashedTimelockERC20} from "../src/HTLCErc20.sol";

// Adds an admin to a deployed HashedTimelockERC20. Must be called by the contract owner.
contract AddAdminHTLCErc20 is Script {
    function run() public {
        address htlcAddr = vm.envAddress("HTLC");
        address admin = vm.envAddress("ADMIN");

        HashedTimelockERC20 htlc = HashedTimelockERC20(htlcAddr);

        vm.startBroadcast();
        htlc.addAdmin(admin);
        vm.stopBroadcast();
    }
}
