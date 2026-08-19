// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {IncomeVaultOwnable2Step} from "../src/IncomeVaultOwnable2Step.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
* @title Access-control hooks — both deployment variants
* @dev
* The logic contracts declare the capabilities, the deployment contracts declare the policy.
* These tests pin the policy of each variant: who is accepted, who is rejected, and that the
* role-based variant really separates duties while the single-owner variant really does not.
*/
contract AccessControlHooksTest is HelperContract {
    IncomeVaultOwnable2Step ownableVault;

    address constant OWNER = address(11);
    address constant NEW_OWNER = address(12);
    address constant DEPOSITOR = address(13);
    address constant WITHDRAWER = address(14);

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
        tokenPayment.mint(OWNER, tokenBalance);
    }

    /* ============ Role variant: every hook accepts its intended holder ============ */
    function testDepositRoleHolderCanDeposit() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.grantRole(INCOME_VAULT_DEPOSIT_ROLE, DEPOSITOR);
        tokenPayment.mint(DEPOSITOR, defaultDepositAmount);

        vm.prank(DEPOSITOR);
        tokenPayment.approve(address(incomeVault), defaultDepositAmount);
        vm.prank(DEPOSITOR);
        incomeVault.deposit(defaultSnapshotTime, defaultDepositAmount);

        assertEq(incomeVault.segregatedDividend(defaultSnapshotTime), defaultDepositAmount);
    }

    function testWithdrawRoleHolderCanWithdraw() public {
        _performOnlyDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.grantRole(INCOME_VAULT_WITHDRAW_ROLE, WITHDRAWER);

        vm.prank(WITHDRAWER);
        incomeVault.withdraw(defaultSnapshotTime, defaultDepositAmount, ADDRESS2);
        assertEq(tokenPayment.balanceOf(ADDRESS2), defaultDepositAmount);
    }

    /* ============ Role variant: the separation of duties is real ============ */
    /**
    * @notice A depositor cannot drain the vault — the capability that motivates the role variant
    */
    function testDepositRoleCannotWithdraw() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.grantRole(INCOME_VAULT_DEPOSIT_ROLE, DEPOSITOR);
        _performOnlyDeposit();

        vm.expectRevert(
        abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, DEPOSITOR, INCOME_VAULT_WITHDRAW_ROLE));
        vm.prank(DEPOSITOR);
        incomeVault.withdraw(defaultSnapshotTime, defaultDepositAmount, DEPOSITOR);
    }

    function testWithdrawRoleCannotDeposit() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.grantRole(INCOME_VAULT_WITHDRAW_ROLE, WITHDRAWER);

        vm.expectRevert(
        abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, WITHDRAWER, INCOME_VAULT_DEPOSIT_ROLE));
        vm.prank(WITHDRAWER);
        incomeVault.deposit(defaultSnapshotTime, defaultDepositAmount);
    }

    function testDepositRoleCannotOperateTheClaimWindow() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.grantRole(INCOME_VAULT_DEPOSIT_ROLE, DEPOSITOR);

        vm.expectRevert(
        abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, DEPOSITOR, INCOME_VAULT_OPERATOR_ROLE));
        vm.prank(DEPOSITOR);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
    }

    function testDepositRoleCannotSetTheRuleEngine() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.grantRole(INCOME_VAULT_DEPOSIT_ROLE, DEPOSITOR);

        vm.expectRevert(
        abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, DEPOSITOR, bytes32(0)));
        vm.prank(DEPOSITOR);
        incomeVault.setRuleEngine(IRuleEngine(ADDRESS3));
    }

    function testDepositRoleCannotFreeze() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.grantRole(INCOME_VAULT_DEPOSIT_ROLE, DEPOSITOR);

        vm.expectRevert(
        abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, DEPOSITOR, incomeVault.ENFORCER_ROLE()));
        vm.prank(DEPOSITOR);
        incomeVault.setAddressFrozen(ADDRESS1, true, "");
    }

    /* ============ Ownable variant: the owner holds every capability ============ */
    function testOwnerCanUseEveryCapability() public {
        vm.prank(OWNER);
        tokenPayment.approve(address(ownableVault), defaultDepositAmount);
        vm.prank(OWNER);
        ownableVault.deposit(defaultSnapshotTime, defaultDepositAmount);
        assertEq(ownableVault.segregatedDividend(defaultSnapshotTime), defaultDepositAmount);

        vm.prank(OWNER);
        ownableVault.setStatusClaim(defaultSnapshotTime, true);
        assertEq(ownableVault.segregatedClaim(defaultSnapshotTime), true);

        vm.prank(OWNER);
        ownableVault.setTimeLimitToWithdraw(1 days);
        assertEq(ownableVault.timeLimitToWithdraw(), 1 days);

        vm.prank(OWNER);
        ownableVault.setAddressFrozen(ADDRESS1, true, "");
        assertEq(ownableVault.isFrozen(ADDRESS1), true);

        vm.prank(OWNER);
        ownableVault.pause();
        assertEq(ownableVault.paused(), true);

        vm.prank(OWNER);
        ownableVault.unpause();

        vm.prank(OWNER);
        ownableVault.withdraw(defaultSnapshotTime, defaultDepositAmount, ADDRESS2);
        assertEq(tokenPayment.balanceOf(ADDRESS2), defaultDepositAmount);
    }

    /**
    * @notice The documented limitation: the funder of the vault is also the account that can empty it
    */
    function testOwnableVariantCannotSeparateDepositFromWithdraw() public {
        vm.prank(OWNER);
        tokenPayment.approve(address(ownableVault), defaultDepositAmount);
        vm.prank(OWNER);
        ownableVault.deposit(defaultSnapshotTime, defaultDepositAmount);

        // the very same account drains it, with no role to withhold
        vm.prank(OWNER);
        ownableVault.withdrawAll(defaultDepositAmount, OWNER);
        assertEq(tokenPayment.balanceOf(OWNER), tokenBalance);
    }

    /* ============ Ownable variant: every hook rejects a non-owner ============ */
    function testAttackerCannotDeposit() public {
        _expectNotOwner();
        vm.prank(ATTACKER);
        ownableVault.deposit(defaultSnapshotTime, defaultDepositAmount);
    }

    function testAttackerCannotWithdraw() public {
        _expectNotOwner();
        vm.prank(ATTACKER);
        ownableVault.withdraw(defaultSnapshotTime, 1, ATTACKER);
    }

    function testAttackerCannotWithdrawAll() public {
        _expectNotOwner();
        vm.prank(ATTACKER);
        ownableVault.withdrawAll(1, ATTACKER);
    }

    function testAttackerCannotDistribute() public {
        address[] memory addresses = new address[](0);
        _expectNotOwner();
        vm.prank(ATTACKER);
        ownableVault.distributeDividend(addresses, defaultSnapshotTime);
    }

    function testAttackerCannotOperate() public {
        _expectNotOwner();
        vm.prank(ATTACKER);
        ownableVault.setStatusClaim(defaultSnapshotTime, true);
    }

    function testAttackerCannotSetTimeLimit() public {
        _expectNotOwner();
        vm.prank(ATTACKER);
        ownableVault.setTimeLimitToWithdraw(1 days);
    }

    function testAttackerCannotSetRuleEngine() public {
        _expectNotOwner();
        vm.prank(ATTACKER);
        ownableVault.setRuleEngine(IRuleEngine(ADDRESS3));
    }

    function testAttackerCannotPause() public {
        _expectNotOwner();
        vm.prank(ATTACKER);
        ownableVault.pause();
    }

    function testAttackerCannotFreeze() public {
        _expectNotOwner();
        vm.prank(ATTACKER);
        ownableVault.setAddressFrozen(ADDRESS1, true, "");
    }

    /* ============ Ownable2Step handover ============ */
    function testTransferOwnershipAloneDoesNotMoveControl() public {
        vm.prank(OWNER);
        ownableVault.transferOwnership(NEW_OWNER);

        assertEq(ownableVault.owner(), OWNER);
        assertEq(ownableVault.pendingOwner(), NEW_OWNER);

        // the pending owner has no capability yet
        _expectNotOwner(NEW_OWNER);
        vm.prank(NEW_OWNER);
        ownableVault.setStatusClaim(defaultSnapshotTime, true);
    }

    function testAcceptOwnershipMovesControl() public {
        vm.prank(OWNER);
        ownableVault.transferOwnership(NEW_OWNER);
        vm.prank(NEW_OWNER);
        ownableVault.acceptOwnership();

        assertEq(ownableVault.owner(), NEW_OWNER);

        vm.prank(NEW_OWNER);
        ownableVault.setStatusClaim(defaultSnapshotTime, true);
        assertEq(ownableVault.segregatedClaim(defaultSnapshotTime), true);

        // and the previous owner has lost it
        _expectNotOwner(OWNER);
        vm.prank(OWNER);
        ownableVault.setStatusClaim(defaultSnapshotTime, false);
    }

    /* ============ ERC-165 ============ */
    function testRoleVariantAdvertisesAccessControl() public view {
        assertEq(incomeVault.supportsInterface(type(IAccessControl).interfaceId), true);
    }

    function testOwnableVariantAdvertisesErc173AndOwnable2Step() public view {
        assertEq(ownableVault.supportsInterface(ownableVault.IERC173_INTERFACE_ID()), true);
        assertEq(ownableVault.supportsInterface(ownableVault.IOWNABLE2STEP_INTERFACE_ID()), true);
        assertEq(ownableVault.supportsInterface(0xffffffff), false);
    }

    /* ============ helpers ============ */
    function _expectNotOwner() internal {
        _expectNotOwner(ATTACKER);
    }

    function _expectNotOwner(address caller) internal {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
    }
}
