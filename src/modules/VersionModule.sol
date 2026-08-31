// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== CMTAT === */
import {IERC3643Version} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";

/**
 * @title VersionModule
 * @notice Exposes the IncomeVault release version through the ERC-3643 version interface.
 * @dev
 * Same shape as the CMTAT, RuleEngine and SnapshotEngine version modules: a single compile-time
 * constant read through {IERC3643Version-version}. Bump `VERSION` together with the `CHANGELOG.md`
 * entry of the release.
 */
abstract contract VersionModule is IERC3643Version {
    /* ============ State Variables ============ */
    /**
     * @dev
     * Get the current version of the smart contract
     */
    string private constant VERSION = "2.0.0";

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @inheritdoc IERC3643Version
     */
    function version() public view virtual override(IERC3643Version) returns (string memory version_) {
        return VERSION;
    }
}
