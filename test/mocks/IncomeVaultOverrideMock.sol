// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {IIncomeVault} from "../../src/interfaces/IIncomeVault.sol";
import {IncomeVault} from "../../src/deployment/IncomeVault.sol";
import {IncomeVaultOpen} from "../../src/public/IncomeVaultOpen.sol";
import {IncomeVaultInternal} from "../../src/modules/IncomeVaultInternal.sol";

/**
* @title Compile-time guard for the `virtual` convention on the claim entrypoints
* @dev
* Removing `virtual` from any function this contract overrides breaks the build with
* `Error (4334): Trying to override non-virtual function`. That covers the **public** claim entrypoints
* and, since finding E-1 of `CLAUDE_ANALYSIS_SECOND.md`, the three core **internal** routines as well.
*
* Compiling is not enough on its own: a silently shadowed override compiles and is never called. For
* the two **state-changing** overrides the counters settle it — `test/OverrideMock.t.sol` drives a real
* claim through this contract and asserts both incremented. The `view` overrides cannot count anything,
* so those stay compile-guarded only; that is a real limit of this technique, not an oversight.
*/
contract IncomeVaultOverrideMock is IncomeVault {
    /// @notice Times the public claim entrypoint was overridden through
    uint256 public claimCount;
    /// @notice Times the internal payout routine was overridden through
    uint256 public transferCount;


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address forwarderIrrevocable) IncomeVault(forwarderIrrevocable) {}

    function claimDividend(uint256 time) public virtual override(IIncomeVault, IncomeVaultOpen) {
        ++claimCount;
        super.claimDividend(time);
    }

    function validateTimeCode(uint256 time) public view virtual override(IIncomeVault, IncomeVaultOpen) returns (TIME_ERROR_CODE) {
        return super.validateTimeCode(time);
    }

    /* ============ the internal routines — finding E-1 ============ */
    /**
    * @inheritdoc IncomeVaultInternal
    */
    function _transferDividend(uint256 time, address tokenHolder, uint256 tokenHolderDividend)
        internal
        virtual
        override(IncomeVaultInternal)
    {
        ++transferCount;
        super._transferDividend(time, tokenHolder, tokenHolderDividend);
    }

    /**
    * @inheritdoc IncomeVaultInternal
    */
    function _computeDividend(uint256 time, uint256 senderBalance, uint256 tokenTotalSupply)
        internal
        view
        virtual
        override(IncomeVaultInternal)
        returns (uint256)
    {
        return super._computeDividend(time, senderBalance, tokenTotalSupply);
    }

    /**
    * @inheritdoc IncomeVaultInternal
    */
    function _computeDividendBatch(
        uint256 time,
        address[] calldata tokenHolders,
        uint256[] memory tokenHoldersBalance,
        uint256 tokenTotalSupply
    ) internal view virtual override(IncomeVaultInternal) returns (uint256[] memory) {
        return super._computeDividendBatch(time, tokenHolders, tokenHoldersBalance, tokenTotalSupply);
    }
}
