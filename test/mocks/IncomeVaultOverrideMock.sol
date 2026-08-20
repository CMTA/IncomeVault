// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {IIncomeVault} from "../../src/interfaces/IIncomeVault.sol";
import {IncomeVault} from "../../src/deployment/IncomeVault.sol";
import {IncomeVaultOpen} from "../../src/public/IncomeVaultOpen.sol";

/**
* @title Compile-time guard for the `virtual` convention on the claim entrypoints
* @dev
* This contract only has to compile: removing `virtual` from any function it overrides breaks the
* build. `claimCount` additionally proves the override is actually reached, which a compile-only
* check would not catch if the function were silently shadowed.
*/
contract IncomeVaultOverrideMock is IncomeVault {
    uint256 public claimCount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address forwarderIrrevocable) IncomeVault(forwarderIrrevocable) {}

    function claimDividend(uint256 time) public virtual override(IIncomeVault, IncomeVaultOpen) {
        ++claimCount;
        super.claimDividend(time);
    }

    function validateTimeCode(uint256 time) public view virtual override(IIncomeVault, IncomeVaultOpen) returns (TIME_ERROR_CODE) {
        return super.validateTimeCode(time);
    }
}
