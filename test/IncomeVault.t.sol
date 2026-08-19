// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
* @title Test for IncomeVault
*/
contract IncomeVaultTest is HelperContract {
    uint256 resUint256;
    bool resBool;

    // Arrange
    function setUp() public {
        _deployContracts();
    }

    function testCannotClaimWithZeroDeposit() public {
        // Arrange
        _mintCMTATTokens();

        // Timeout
        vm.warp(defaultSnapshotTime + 50);

        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_NoDividendToClaim.selector));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);

        // Check balance
        resUint256 = tokenPayment.balanceOf(ADDRESS1);
        assertEq(resUint256, 0);
    }

    function testHolderCannotClaimIfClaimNotOpened() public {
        // Arrange
        _mintCMTATTokens();

        // Timeout
        vm.warp(defaultSnapshotTime + 50);

        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_ClaimNotActivated.selector));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);
    }

    function testHolderCanClaimWithDepositAndOneHolder() public {
        // Arrange
        _performDeposit();

        // Timeout
        vm.warp(defaultSnapshotTime + 50);

        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Claim deposit
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);

        // Check balance
        resUint256 = tokenPayment.balanceOf(ADDRESS1);
        assertEq(resUint256, defaultDepositAmount);
    }

    function testHolderCannotClaimTwice() public {
        // Arrange
        _performDeposit();
        vm.warp(defaultSnapshotTime + 50);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);

        // Act & Assert
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_DividendAlreadyClaimed.selector));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);
    }

    function testHolderCannotClaimIfPaused() public {
        // Arrange
        _performDeposit();

        // Timeout
        vm.warp(defaultSnapshotTime + 50);

        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Contract pause
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.pause();

        // Act
        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS1, defaultDepositAmount));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);
    }

    function testHolderCannotClaimIfHolderAddressIsFrozen() public {
        // Arrange
        _performDeposit();

        // Timeout
        vm.warp(defaultSnapshotTime + 50);

        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Freeze the holder
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setAddressFrozen(ADDRESS1, true, "Blacklist");

        // Act
        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS1, defaultDepositAmount));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);
    }

    function testHolderCanClaimWithDepositAndTwoHolders() public {
        // Arrange
        _performOnlyDeposit();

        // Configure snapshot
        vm.prank(CMTAT_ADMIN);
        snapshotEngine.scheduleSnapshot(defaultSnapshotTime);

        // Mint token for Address 1
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.mint(ADDRESS1, ADDRESS1_INITIAL_AMOUNT);
        // Mint tokens for Address 2
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.mint(ADDRESS2, ADDRESS1_INITIAL_AMOUNT);

        // Timeout
        vm.warp(defaultSnapshotTime + 50);

        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Claim deposit Address 1
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);

        // Check balance
        resUint256 = tokenPayment.balanceOf(ADDRESS1);
        // Dividends are shared between the two token holders
        assertEq(resUint256, defaultDepositAmount / 2);

        // Claim deposit Address 2
        vm.prank(ADDRESS2);
        incomeVault.claimDividend(defaultSnapshotTime);

        // Check balance
        resUint256 = tokenPayment.balanceOf(ADDRESS2);
        // Dividends are shared between the two token holders
        assertEq(resUint256, defaultDepositAmount / 2);
    }

    function testCannotHolderClaimIfItIsTooLateToWithdraw() public {
        // Arrange
        _performDeposit();

        // Timeout
        vm.warp(defaultSnapshotTime + 50);

        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Timeout
        vm.warp(defaultSnapshotTime + TIME_LIMIT_TO_WITHDRAW + 1 seconds);

        // Act
        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_TooLateToWithdraw.selector, block.timestamp));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);
    }

    function testCannotHolderClaimWithDepositAndOneHolderIfTooEarly() public {
        // Arrange
        _performDeposit();

        // Timeout
        // No timeout

        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_TooEarlyToWithdraw.selector, block.timestamp));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);
    }

    /* ============ Snapshot source ============ */
    /**
    * @dev the vault is wired to the snapshot engine through {ISnapshotState}, not to the token
    */
    function testSnapshotEngineIsTheConfiguredSource() public view {
        assertEq(address(incomeVault.snapshotEngine()), address(snapshotEngine));
    }

    function testCannotDeployWithSnapshotEngineAddressZero() public {
        IncomeVault implementation = new IncomeVault(ZERO_ADDRESS);
        bytes memory data = abi.encodeCall(
            IncomeVault.initialize,
            (
                DEFAULT_ADMIN_ADDRESS,
                IERC20(address(tokenPayment)),
                ISnapshotState(ZERO_ADDRESS),
                IRuleEngine(ZERO_ADDRESS),
                TIME_LIMIT_TO_WITHDRAW
            )
        );
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_SnapshotEngineWithAddressZeroNotAllowed.selector));
        new TransparentUpgradeableProxy(address(implementation), DEFAULT_ADMIN_ADDRESS, data);
    }
}
