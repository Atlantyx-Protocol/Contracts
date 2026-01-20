// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {USDC} from "../src/USDC.sol";

contract USDCTest is Test {
    USDC public token;

    address internal user = address(0xBEEF);

    function setUp() public {
        token = new USDC();
    }

    function test_Metadata() public view {
        assertEq(token.decimals(), 6);
        assertEq(token.name(), "USD Coin");
        assertEq(token.symbol(), "USDC");
    }

    function test_InitialSupply() public view {
        uint256 expectedSupply = 1_000_000_000 * 10 ** 6;
        assertEq(token.totalSupply(), expectedSupply);
        assertEq(token.balanceOf(address(this)), expectedSupply);
    }

    function test_FaucetMints() public {
        uint256 amount = 25_000 * 10 ** 6;
        token.faucet(user, amount);

        assertEq(token.balanceOf(user), amount);
        assertEq(token.totalSupply(), 1_000_000_000 * 10 ** 6 + amount);
    }
}
