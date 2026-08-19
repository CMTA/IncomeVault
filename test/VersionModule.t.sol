// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {IncomeVaultOwnable2Step} from "../src/IncomeVaultOwnable2Step.sol";
import {IERC3643Version} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";

/**
* @title Version string of every deployment variant
* @dev
* Exhaustive on purpose: **every** deployable contract must appear here. A half-covered version
* test reads as authoritative while missing the variant it exists to catch.
*/
contract VersionModuleTest is HelperContract {
    IncomeVaultOwnable2Step ownableVault;

    address constant OWNER = address(11);

    /// @dev must match `VERSION` in src/modules/VersionModule.sol and the CHANGELOG entry
    string constant EXPECTED_VERSION = "1.1.0";

    function setUp() public {
        _deployContracts();

        Options memory opts;
        opts.constructorData = abi.encode(ZERO_ADDRESS);
        address proxy = Upgrades.deployTransparentProxy(
            "IncomeVaultOwnable2Step.sol",
            DEFAULT_ADMIN_ADDRESS,
            abi.encodeCall(
                IncomeVaultOwnable2Step.initialize,
                (
                    OWNER,
                    IERC20(address(tokenPayment)),
                    ISnapshotSource(address(snapshotEngine)),
                    IRuleEngine(ZERO_ADDRESS),
                    TIME_LIMIT_TO_WITHDRAW
                )
            ),
            opts
        );
        ownableVault = IncomeVaultOwnable2Step(proxy);
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
