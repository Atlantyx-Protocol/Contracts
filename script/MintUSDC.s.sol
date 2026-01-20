// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {USDC} from "../src/USDC.sol";

contract MintUSDCScript is Script {
    function run() public {
        address tokenAddress = vm.envAddress("USDC");
        address[] memory recipients = vm.envAddress("RECIPIENTS", ",");
        uint256 amount = vm.envUint("AMOUNT");

        vm.startBroadcast();
        USDC token = USDC(tokenAddress);
        for (uint256 i = 0; i < recipients.length; i++) {
            token.faucet(recipients[i], amount);
        }
        vm.stopBroadcast();
    }
}
