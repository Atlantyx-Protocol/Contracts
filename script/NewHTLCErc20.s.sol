// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HashedTimelockERC20} from "../src/HTLCErc20.sol";

// Creates a new HTLC order with a single fill. Caller must own and approve the ERC20 being locked.
contract NewHTLCErc20 is Script {
    function run() public returns (uint256 orderId) {
        address htlcAddr = vm.envAddress("HTLC");
        address receiver = vm.envAddress("RECEIVER");
        bytes32 hashlock = vm.envBytes32("HASHLOCK");
        uint256 timelock = vm.envUint("TIMELOCK"); // unix seconds
        address token = vm.envAddress("TOKEN");
        uint256 amount = vm.envUint("AMOUNT");

        HashedTimelockERC20 htlc = HashedTimelockERC20(htlcAddr);

        // Build single-fill order params
        address[] memory receivers = new address[](1);
        receivers[0] = receiver;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes32[] memory hashlocks = new bytes32[](1);
        hashlocks[0] = hashlock;

        vm.startBroadcast();
        IERC20(token).approve(htlcAddr, amount);
        orderId = htlc.newOrder(
            HashedTimelockERC20.NewOrderParams({
                token: token,
                totalAmount: amount,
                timelock: timelock,
                receivers: receivers,
                amounts: amounts,
                hashlocks: hashlocks
            })
        );
        vm.stopBroadcast();
    }
}
