// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Minimal ERC-20 used as payment token in the tests
 * @dev The IncomeVault only requires the payment token to be a standard ERC-20.
 */
contract ERC20PaymentMock is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address account, uint256 value) public {
        _mint(account, value);
    }

    function decimals() public pure override returns (uint8) {
        return 0;
    }
}
