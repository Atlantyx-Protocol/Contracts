// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HashedTimelockERC20} from "../src/HTLCErc20.sol";

// Claims tokens from an HTLC fill by providing the preimage. Must be called by the fill's receiver.
contract WithdrawHTLCErc20 is Script {
    function run() public {
        address htlcAddr = vm.envAddress("HTLC");
        uint256 orderId = vm.envUint("ORDER_ID");
        uint256 fillId = vm.envUint("FILL_ID");
        bytes32 preimage = vm.envBytes32("PREIMAGE");

        HashedTimelockERC20 htlc = HashedTimelockERC20(htlcAddr);

        vm.startBroadcast();
        htlc.withdraw(orderId, fillId, preimage);
        vm.stopBroadcast();
    }
}
