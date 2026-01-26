// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HashedTimelockERC20} from "../src/HTLCErc20.sol";

// Creates a new HTLC lock. Caller must own and approve the ERC20 being locked.
contract NewHTLCErc20 is Script {
    function run() public returns (bytes32 id) {
        address htlcAddr = vm.envAddress("HTLC");
        address receiver = vm.envAddress("RECEIVER");
        bytes32 hashlock = vm.envBytes32("HASHLOCK");
        uint256 timelock = vm.envUint("TIMELOCK"); // unix seconds
        address token = vm.envAddress("TOKEN");
        uint256 amount = vm.envUint("AMOUNT");

        HashedTimelockERC20 htlc = HashedTimelockERC20(htlcAddr);

        vm.startBroadcast();
        IERC20(token).approve(htlcAddr, amount);
        id = htlc.newContract(receiver, hashlock, timelock, token, amount);
        vm.stopBroadcast();
    }
}
