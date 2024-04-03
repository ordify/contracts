// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// @dev just used for testing
contract Token is ERC20 {
    uint8 immutable dec; // token decimals

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint8 _dec
    ) ERC20(name, symbol) {
        dec = _dec;
        _mint(msg.sender, totalSupply * (10**_dec));
    }

    function decimals() public view override returns (uint8) {
        return dec;
    }
}
