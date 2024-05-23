// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./HelperContract.sol";
import "CMTAT/interfaces/engine/IRuleEngine.sol";
import "CMTAT/interfaces/engine/IAuthorizationEngine.sol";
import {IncomeVault} from "../src/IncomeVault.sol";

/**
* @title Test for IncomeVault
*/
contract IncomeVaultBatchTest is Test, HelperContract {
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
        vm.prank(TOKEN_PAYMENT_ADMIN);
        tokenPayment.mint(DEFAULT_ADMIN_ADDRESS, tokenBalance);

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
        _mintCMTATTokens();
    }

    function _mintCMTATTokens() internal {
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.scheduleSnapshot(defaultSnapshotTime);
        
        // Mint token for Address 1
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.mint(ADDRESS1, ADDRESS1_INITIAL_AMOUNT);
    }

    function testHolderCanBatchClaimWithDepositAndOneHolder() public {
        // Arrange
        // First deposit
        _performDeposit();

        // Second deposit
        uint256 newTime = defaultSnapshotTime + 50;
        uint256[] memory times = new uint256[](2);
        times[0] = defaultSnapshotTime;
        times[1] = newTime;
        // Set the new approval
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(debtVault), defaultDepositAmount * 2);
       
        // Deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.deposit(newTime, defaultDepositAmount);

        // Timeout
        uint256 timeout = newTime + 50;
        vm.warp(timeout);
        
        // Open claim first deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(defaultSnapshotTime, true);

        // Open claim second deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(newTime, true);
        
        // Claim deposit
        vm.prank(ADDRESS1);
        debtVault.claimDividendBatch(times);

        // Check balance
        resUint256 = tokenPayment.balanceOf(ADDRESS1);
        assertEq(resUint256, defaultDepositAmount * 2); 
    }

    function testHolderCanBatchClaimWithZeroDepositAndOneHolder() public {
        // Arrange
        // Mint cmtat tokens without deposit
        _mintCMTATTokens();

        // Second deposit
        uint256 newTime = defaultSnapshotTime + 50;
        uint256[] memory times = new uint256[](2);
        times[0] = defaultSnapshotTime;
        times[1] = newTime;

        // Timeout
        uint256 timeout = newTime + 50;
        vm.warp(timeout);
        
        // Open claim first deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(defaultSnapshotTime, true);

        // Open claim second deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(newTime, true);
        
        // Claim deposit
        vm.prank(ADDRESS1);
        debtVault.claimDividendBatch(times);

        // Check balance
        resUint256 = tokenPayment.balanceOf(ADDRESS1);
        assertEq(resUint256, 0); 
    }
    function testCannotHolderBatchClaimWithDepositAndOneHolderIfClaimNotOpen() public {
        // Arrange
        // First deposit
        _performDeposit();

        // Second deposit
        uint256 newTime = defaultSnapshotTime + 50;
        uint256[] memory times = new uint256[](2);
        times[0] = defaultSnapshotTime;
        times[1] = newTime;
        // Set the new approval
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(debtVault), defaultDepositAmount * 2);
       
        // Deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.deposit(newTime, defaultDepositAmount);

        // Timeout
        uint256 timeout = newTime + 50;
        vm.warp(timeout);
        
        // Open claim first deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(defaultSnapshotTime, true);
        
        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_ClaimNotActivated.selector));
        vm.prank(ADDRESS1);
        debtVault.claimDividendBatch(times);
    }

    function testCannotHolderBatchClaimIfTooLate() public {
        // Arrange
        // First deposit
        _performDeposit();

        // Second deposit
        uint256 newTime = defaultSnapshotTime + TIME_LIMIT_TO_WITHDRAW;
        uint256[] memory times = new uint256[](2);
        times[0] = defaultSnapshotTime;
        times[1] = newTime;
        // Set the new approval
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(debtVault), defaultDepositAmount * 2);
       
        // Deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.deposit(newTime, defaultDepositAmount);

        // Timeout
        uint256 timeout = newTime + 50;
        vm.warp(timeout);

        // Timeout
        timeout = defaultSnapshotTime + TIME_LIMIT_TO_WITHDRAW + 1 seconds;
        vm.warp(timeout);
        
        
        // Open claim first deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(defaultSnapshotTime, true);

        // Open claim second deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(newTime, true);
        
        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_TooLateToWithdraw.selector, block.timestamp));
        vm.prank(ADDRESS1);
        debtVault.claimDividendBatch(times);
    }

    function testCannotHolderBatchClaimIfTooEarly() public {
        // Arrange
        // First deposit
        _performDeposit();

        // Second deposit
        uint256 newTime = defaultSnapshotTime + 50;
        uint256[] memory times = new uint256[](2);
        times[0] = defaultSnapshotTime;
        times[1] = newTime;
        // Set the new approval
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(debtVault), defaultDepositAmount * 2);
       
        // Deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.deposit(newTime, defaultDepositAmount);

        // Timeout
        vm.warp(defaultSnapshotTime);
        
        
        // Open claim first deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(defaultSnapshotTime, true);

        // Open claim second deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(newTime, true);
        
        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_TooEarlyToWithdraw.selector, block.timestamp));
        vm.prank(ADDRESS1);
        debtVault.claimDividendBatch(times);
    }

}
