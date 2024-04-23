// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./HelperContract.sol";
import "CMTAT/interfaces/engine/IRuleEngine.sol";
import "CMTAT/interfaces/engine/IAuthorizationEngine.sol";
import {IncomeVault} from "../src/IncomeVault.sol";
//import {Upgrades,} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/**
* @title Test for DebtVault
*/
contract IncomeVaultRestrictedTest is Test, HelperContract {
    uint256 resUint256;
    uint8 resUint8;
    bool resBool;
    bool resCallBool;
    string resString;
    uint8 CODE_NONEXISTENT = 255;

    // ADMIN balance payment
    uint256 tokenBalance = 5000;

    // Arrange
    function setUp() public {
        // Deploy CMTAT
            CMTAT_CONTRACT = new CMTAT_STANDALONE(
            ZERO_ADDRESS,
            CMTAT_ADMIN,
            IAuthorizationEngine(address(0)),
            "CMTA Token",
            "CMTAT",
            DECIMALS,
            "CMTAT_ISIN",
            "https://cmta.ch",
            IRuleEngine(address(0)),
            "CMTAT_info",
            FLAG
        );

        // Token payment
        tokenPayment = new CMTAT_STANDALONE(
            ZERO_ADDRESS,
            TOKEN_PAYMENT_ADMIN,
            IAuthorizationEngine(address(0)),
            "CMTA Token",
            "CMTAT",
            DECIMALS,
            "CMTAT_ISIN",
            "https://cmta.ch",
            IRuleEngine(address(0)),
            "CMTAT_info",
            FLAG
        );
        Options memory opts;
        opts.constructorData = abi.encode(ZERO_ADDRESS);
        address proxy = Upgrades.deployTransparentProxy(
            "IncomeVault.sol",
            DEFAULT_ADMIN_ADDRESS,
            abi.encodeCall(IncomeVault.initialize, ( DEFAULT_ADMIN_ADDRESS,
            tokenPayment,
            ICMTATSnapshot(address(CMTAT_CONTRACT)),
            IRuleEngine(ZERO_ADDRESS),
            IAuthorizationEngine(ZERO_ADDRESS),
            TIME_LIMIT_TO_WITHDRAW)),
            opts
        );
        debtVault = IncomeVault(proxy);
        // Deploy DebtVault
        /*debtVault = new DebtVault(
            ZERO_ADDRESS
        );*/
        /*debtVault.initialize(
            DEFAULT_ADMIN_ADDRESS,
            tokenPayment,
            ICMTATSnapshot(address(CMTAT_CONTRACT)),
            IRuleEngine(ZERO_ADDRESS),
            IAuthorizationEngine(ZERO_ADDRESS)
        );*/
        /**
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.mint(DEFAULT_ADMIN_ADDRESS, ADDRESS1_INITIAL_AMOUNT);
        */
        vm.prank(TOKEN_PAYMENT_ADMIN);
        tokenPayment.mint(DEFAULT_ADMIN_ADDRESS, tokenBalance);

    }

    function testDepositRoleCanPerformDeposit() public {
        uint256 time = 200;
        // Allowance
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(debtVault), defaultDepositAmount);
        // Act
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        //Event
        vm.expectEmit(true, true, false, true);
        emit newDeposit(
            time,
            DEFAULT_ADMIN_ADDRESS,
            defaultDepositAmount
        );
        debtVault.deposit(time, defaultDepositAmount);
        // Assert
        resUint256 = debtVault.segragatedDividend(time);
        assertEq(resUint256, defaultDepositAmount); 
    }


    function _performOnlyDeposit() internal {
        // Allowance
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(debtVault), defaultDepositAmount);
        // Act
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.deposit(defaultSnapshotTime, defaultDepositAmount);
    }

    function _performDeposit() internal {
        _performOnlyDeposit();
        // Configure snapshot

        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.scheduleSnapshot(defaultSnapshotTime);
        
        // Mint token for Address 1
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.mint(ADDRESS1, ADDRESS1_INITIAL_AMOUNT);
    }

    function testAdminCanWithdrawAll() public {
        // Arrange
        // Deposit
        uint256 snapshotTime1 = block.timestamp + 50;
        uint256 snapshotTime2 = block.timestamp + 50;
        uint256 depositAmount1 = 2000;
        uint256 depositAmount2 = 3000;
        uint256 ALLOWANCE_NEEDED = 2000 + 3000;
        // Allowance
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(debtVault), ALLOWANCE_NEEDED);
        // Deposit 1
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.deposit(snapshotTime1, depositAmount1);
        // Deposit 2
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.deposit(snapshotTime2, depositAmount2);
        
        // Withdraw
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.withdrawAll(ALLOWANCE_NEEDED, ADDRESS2);

        // Assert
        assertEq(tokenPayment.balanceOf(ADDRESS2), ALLOWANCE_NEEDED);
    }

    function testAdminCanWithdrawSpecificTime() public {
        // Arrange
        // Deposit
        uint256 snapshotTime1 = block.timestamp + 50;
        uint256 snapshotTime2 = block.timestamp + 50;
        uint256 depositAmount1 = 2000;
        uint256 depositAmount2 = 3000;
        uint256 ALLOWANCE_NEEDED = 2000 + 3000;
        // Allowance
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(debtVault), ALLOWANCE_NEEDED);
        // Deposit 1
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.deposit(snapshotTime1, depositAmount1);
        // Deposit 2
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.deposit(snapshotTime2, depositAmount2);
        
        // Withdraw
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.withdraw(snapshotTime1, depositAmount1, ADDRESS2);

        // Assert
        assertEq(tokenPayment.balanceOf(ADDRESS2),depositAmount1);
    }

    /****** Attacker */
    function testCannotAttackerSetStatusClaim() public {
        vm.expectRevert(
        abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_OPERATOR_ROLE));  
        vm.prank(ATTACKER);
        debtVault.setStatusClaim(122, true);
    }

    function testCannotAttackerSetTimeLimitToWithdraw() public {
        vm.expectRevert(
        abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_OPERATOR_ROLE));  
        vm.prank(ATTACKER);
        debtVault.setTimeLimitToWithdraw(122);
    }

    function testCannotAttackerDistributeDividend() public {
        vm.expectRevert(
        abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_DISTRIBUTE_ROLE));  
        vm.prank(ATTACKER);
        address[] memory addresses = new address[](0);
        debtVault.distributeDividend(addresses, 12);
    }

    function testCannotAttackerWithdrawAll() public {
        vm.expectRevert(
        abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_WITHDRAW_ROLE));  
        vm.prank(ATTACKER);
        debtVault.withdrawAll(12,ADDRESS2 );
    }

    function testCannotAttackerWithdraw() public {
        vm.expectRevert(
        abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_WITHDRAW_ROLE));  
        vm.prank(ATTACKER);
        debtVault.withdraw(12, 12, ADDRESS2 );
    }

    function testCannotAttackerPerformDeposit() public {
        vm.expectRevert(
        abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_DEPOSIT_ROLE));  
        vm.prank(ATTACKER);
        debtVault.deposit(12, 12);
    }
}
