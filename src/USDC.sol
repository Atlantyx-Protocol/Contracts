// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20 {
    uint8 private constant DECIMALS = 6;

    constructor() ERC20("USD Coin", "USDC") {
        _mint(_msgSender(), 1_000_000_000 * 10 ** uint256(DECIMALS));
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    function faucet(address to, uint256 amount) external returns (bool) {
        _mint(to, amount);
        return true;
    }
}
