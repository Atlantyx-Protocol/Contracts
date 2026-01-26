// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HashedTimelockERC20} from "../src/HTLCErc20.sol";

// Deploys a HashedTimelockERC20 with a configurable expiry policy.
contract DeployHTLCErc20 is Script {
    function run() public returns (HashedTimelockERC20 htlc) {
        bool allowWithdrawAfterExpiry = vm.envBool("ALLOW_WITHDRAW_AFTER_EXPIRY");

        vm.startBroadcast();
        htlc = new HashedTimelockERC20(allowWithdrawAfterExpiry);
        vm.stopBroadcast();
    }
}
