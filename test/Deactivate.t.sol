// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {IncomeVaultOwnable2Step} from "../src/IncomeVaultOwnable2Step.sol";

/**
* @title `deactivateContract` — finding B-1
* @dev
* The only irreversible action in the system: once deactivated the vault can never be unpaused, so
* with a proxy the sole way back is a new implementation. It was previously untested in both variants.
*/
contract DeactivateTest is HelperContract {
    IncomeVaultOwnable2Step ownableVault;
    address constant OWNER = address(11);

    function setUp() public {
        _deployContracts();

        Options memory opts;
        opts.constructorData = abi.encode(ZERO_ADDRESS);
        address proxy = Upgrades.deployTransparentProxy(
            "IncomeVaultOwnable2Step.sol",
            DEFAULT_ADMIN_ADDRESS,
            abi.encodeCall(
                IncomeVaultOwnable2Step.initialize,
                (OWNER, IERC20(address(tokenPayment)),
                 ISnapshotSource(address(snapshotEngine)), IRuleEngine(ZERO_ADDRESS), TIME_LIMIT_TO_WITHDRAW)
            ),
            opts
        );
        ownableVault = IncomeVaultOwnable2Step(proxy);
    }

    /* ============ role-based variant ============ */
    function testAdminCanDeactivateAPausedVault() public {
        assertEq(incomeVault.deactivated(), false);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.pause();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deactivateContract();

        assertEq(incomeVault.deactivated(), true);
        assertEq(incomeVault.paused(), true);
    }

    /**
    * @notice The vault must be paused first — deactivation is not a shortcut around the pause
    */
    function testCannotDeactivateWithoutPausingFirst() public {
        vm.expectRevert(abi.encodeWithSignature("ExpectedPause()"));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deactivateContract();
        assertEq(incomeVault.deactivated(), false);
    }

    /**
    * @notice Deactivation is irreversible: the vault can never be unpaused again
    */
    function testADeactivatedVaultCanNeverBeUnpaused() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.pause();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deactivateContract();

        vm.expectRevert(abi.encodeWithSignature("CMTAT_PauseModule_ContractIsDeactivated()"));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.unpause();
    }

    function testCannotDeactivateTwice() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.pause();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deactivateContract();

        vm.expectRevert(abi.encodeWithSignature("AlreadyDeactivated()"));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deactivateContract();
    }

    /**
    * @notice A deactivated vault pays nobody — the practical consequence
    */
    function testADeactivatedVaultRefusesEveryPayout() public {
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.pause();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deactivateContract();

        vm.expectRevert(abi.encodeWithSelector(
            IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS1, defaultDepositAmount));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);

        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;
        vm.expectRevert(abi.encodeWithSelector(
            IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS1, defaultDepositAmount));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);
    }

    function testAttackerCannotDeactivate() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.pause();

        vm.expectRevert(abi.encodeWithSelector(
            AccessControlUnauthorizedAccount.selector, ATTACKER, bytes32(0)));
        vm.prank(ATTACKER);
        incomeVault.deactivateContract();
        assertEq(incomeVault.deactivated(), false);
    }

    /**
    * @notice `PAUSER_ROLE` alone is not enough — deactivation needs the admin
    */
    function testPauserRoleAloneCannotDeactivate() public {
        address pauser = address(21);
        // read the role first: a call inside the argument list would consume the prank
        bytes32 pauserRole = incomeVault.PAUSER_ROLE();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.grantRole(pauserRole, pauser);

        vm.prank(pauser);
        incomeVault.pause();

        vm.expectRevert(abi.encodeWithSelector(
            AccessControlUnauthorizedAccount.selector, pauser, bytes32(0)));
        vm.prank(pauser);
        incomeVault.deactivateContract();
    }

    /* ============ single-owner variant ============ */
    function testOwnerCanDeactivate() public {
        vm.prank(OWNER);
        ownableVault.pause();
        vm.prank(OWNER);
        ownableVault.deactivateContract();
        assertEq(ownableVault.deactivated(), true);
    }

    function testAttackerCannotDeactivateOwnableVariant() public {
        vm.prank(OWNER);
        ownableVault.pause();

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", ATTACKER));
        vm.prank(ATTACKER);
        ownableVault.deactivateContract();
        assertEq(ownableVault.deactivated(), false);
    }
}
