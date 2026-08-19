// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {IERC3643Version} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";

/**
* @title Version string of every deployment variant
* @dev
* Exhaustive on purpose: **every** deployable contract must appear here. A half-covered version
* test reads as authoritative while missing the variant it exists to catch.
*/
contract VersionModuleTest is HelperContract {


    /// @dev must match `VERSION` in src/modules/VersionModule.sol and the CHANGELOG entry
    string constant EXPECTED_VERSION = "1.1.0";

    function setUp() public {
        _deployContracts();

        _deployOwnableVault();
    }

    function testIncomeVaultExposesTheVersion() public view {
        assertEq(incomeVault.version(), EXPECTED_VERSION);
    }

    function testIncomeVaultOwnable2StepExposesTheVersion() public view {
        assertEq(ownableVault.version(), EXPECTED_VERSION);
    }

    /**
    * @notice Both variants answer through the ERC-3643 version interface
    */
    function testVersionIsReachableThroughIERC3643Version() public view {
        assertEq(IERC3643Version(address(incomeVault)).version(), EXPECTED_VERSION);
        assertEq(IERC3643Version(address(ownableVault)).version(), EXPECTED_VERSION);
    }

    /**
    * @notice The version is a compile-time constant, identical on the implementation and the proxy
    */
    function testVersionIsTheSameOnTheImplementation() public {
        IncomeVault implementation = new IncomeVault(ZERO_ADDRESS);
        assertEq(implementation.version(), EXPECTED_VERSION);
    }
}
