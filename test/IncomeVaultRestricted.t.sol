// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";

/**
 * @title Test for the restricted functions of IncomeVault
 */
contract IncomeVaultRestrictedTest is HelperContract {
    uint256 resUint256;
    bool resBool;

    // Arrange
    function setUp() public {
        _deployContracts();
    }

    function testDepositRoleCanPerformDeposit() public {
        uint256 time = 200;
        // Allowance
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(incomeVault), defaultDepositAmount);
        // Act
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        //Event
        vm.expectEmit(true, true, false, true);
        emit newDeposit(time, DEFAULT_ADMIN_ADDRESS, defaultDepositAmount);
        incomeVault.deposit(time, defaultDepositAmount);
        // Assert
        resUint256 = incomeVault.segregatedDividend(time);
        assertEq(resUint256, defaultDepositAmount);
    }

    function testCannotDepositZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_NoAmountSend.selector));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deposit(200, 0);
    }

    function testAdminCanWithdrawAll() public {
        // Arrange
        uint256 snapshotTime1 = block.timestamp + 50;
        uint256 snapshotTime2 = block.timestamp + 100;
        uint256 depositAmount1 = 2000;
        uint256 depositAmount2 = 3000;
        uint256 ALLOWANCE_NEEDED = depositAmount1 + depositAmount2;
        // Allowance
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(incomeVault), ALLOWANCE_NEEDED);
        // Deposit 1
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deposit(snapshotTime1, depositAmount1);
        // Deposit 2
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deposit(snapshotTime2, depositAmount2);

        // Withdraw
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.withdrawAll(ALLOWANCE_NEEDED, ADDRESS2);

        // Assert
        assertEq(tokenPayment.balanceOf(ADDRESS2), ALLOWANCE_NEEDED);
    }

    function testAdminCanWithdrawSpecificTime() public {
        // Arrange
        uint256 snapshotTime1 = block.timestamp + 50;
        uint256 snapshotTime2 = block.timestamp + 100;
        uint256 depositAmount1 = 2000;
        uint256 depositAmount2 = 3000;
        uint256 ALLOWANCE_NEEDED = depositAmount1 + depositAmount2;
        // Allowance
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(incomeVault), ALLOWANCE_NEEDED);
        // Deposit 1
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deposit(snapshotTime1, depositAmount1);
        // Deposit 2
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deposit(snapshotTime2, depositAmount2);

        // Withdraw
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.withdraw(snapshotTime1, depositAmount1, ADDRESS2);

        // Assert
        assertEq(tokenPayment.balanceOf(ADDRESS2), depositAmount1);
        assertEq(incomeVault.segregatedDividend(snapshotTime1), 0);
        assertEq(incomeVault.segregatedDividend(snapshotTime2), depositAmount2);
    }

    function testCannotWithdrawMoreThanDepositedForATime() public {
        uint256 time = block.timestamp + 50;
        _performOnlyDeposit(time, defaultDepositAmount);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_NotEnoughAmount.selector));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.withdraw(time, defaultDepositAmount + 1, ADDRESS2);
    }

    function testDistributeRoleCanDistributeDividend() public {
        // Arrange
        _performDeposit();
        vm.warp(defaultSnapshotTime + 50);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Act
        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);

        // Assert
        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount);
        assertEq(incomeVault.claimedDividend(ADDRESS1, defaultSnapshotTime), true);
    }

    function testCanAdminSetStatusClaim() public {
        uint256 time = 122;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(time, true);
        resBool = incomeVault.segregatedClaim(time);
        assertEq(resBool, true);
    }

    function testCanAdminUnsetStatusClaim() public {
        // Arrange
        uint256 time = 122;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(time, true);
        // Act
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(time, false);
        // Assert
        resBool = incomeVault.segregatedClaim(time);
        assertEq(resBool, false);
    }

    function testCanAdminSetTimeLimitToWithdraw() public {
        // Act
        uint256 time = 122;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setTimeLimitToWithdraw(time);
        // Assert
        resUint256 = incomeVault.timeLimitToWithdraw();
        assertEq(resUint256, time);
    }

    /****** Attacker */
    function testCannotAttackerSetStatusClaim() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_OPERATOR_ROLE)
        );
        vm.prank(ATTACKER);
        incomeVault.setStatusClaim(122, true);
    }

    function testCannotAttackerSetTimeLimitToWithdraw() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_OPERATOR_ROLE)
        );
        vm.prank(ATTACKER);
        incomeVault.setTimeLimitToWithdraw(122);
    }

    function testCannotAttackerDistributeDividend() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_DISTRIBUTE_ROLE)
        );
        vm.prank(ATTACKER);
        address[] memory addresses = new address[](0);
        incomeVault.distributeDividend(addresses, 12);
    }

    function testCannotAttackerWithdrawAll() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_WITHDRAW_ROLE)
        );
        vm.prank(ATTACKER);
        incomeVault.withdrawAll(12, ADDRESS2);
    }

    function testCannotAttackerWithdraw() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_WITHDRAW_ROLE)
        );
        vm.prank(ATTACKER);
        incomeVault.withdraw(12, 12, ADDRESS2);
    }

    function testCannotAttackerPerformDeposit() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_DEPOSIT_ROLE)
        );
        vm.prank(ATTACKER);
        incomeVault.deposit(12, 12);
    }

    function testCannotAttackerSetRuleEngine() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, bytes32(0)));
        vm.prank(ATTACKER);
        incomeVault.setRuleEngine(IRuleEngine(ADDRESS3));
    }

    function testCannotAttackerPause() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, incomeVault.PAUSER_ROLE())
        );
        vm.prank(ATTACKER);
        incomeVault.pause();
    }
}
