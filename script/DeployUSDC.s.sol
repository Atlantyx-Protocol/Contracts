// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {USDC} from "../src/USDC.sol";

contract USDCScript is Script {
    USDC public token;

    function run() public {
        vm.startBroadcast();
        token = new USDC();
        vm.stopBroadcast();
    }
}
