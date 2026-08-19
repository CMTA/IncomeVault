// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";

/**
* @title Test for the batch functions of IncomeVault
*/
contract IncomeVaultBatchTest is HelperContract {
    uint256 resUint256;

    // Arrange
    function setUp() public {
        _deployContracts();
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
        _performOnlyDeposit(newTime, defaultDepositAmount);

        // Timeout
        vm.warp(newTime + 50);

        // Open claim first deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Open claim second deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(newTime, true);

        // Claim deposit
        vm.prank(ADDRESS1);
        incomeVault.claimDividendBatch(times);

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
        vm.warp(newTime + 50);

        // Open claim first deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Open claim second deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(newTime, true);

        // Claim deposit
        vm.prank(ADDRESS1);
        incomeVault.claimDividendBatch(times);

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
        _performOnlyDeposit(newTime, defaultDepositAmount);

        // Timeout
        vm.warp(newTime + 50);

        // Open claim first deposit only
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_ClaimNotActivated.selector));
        vm.prank(ADDRESS1);
        incomeVault.claimDividendBatch(times);
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
        _performOnlyDeposit(newTime, defaultDepositAmount);

        // Timeout
        vm.warp(defaultSnapshotTime + TIME_LIMIT_TO_WITHDRAW + 1 seconds);

        // Open claim first deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Open claim second deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(newTime, true);

        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_TooLateToWithdraw.selector, block.timestamp));
        vm.prank(ADDRESS1);
        incomeVault.claimDividendBatch(times);
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
        _performOnlyDeposit(newTime, defaultDepositAmount);

        // Timeout
        vm.warp(defaultSnapshotTime);

        // Open claim first deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Open claim second deposit
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(newTime, true);

        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_TooEarlyToWithdraw.selector, block.timestamp));
        vm.prank(ADDRESS1);
        incomeVault.claimDividendBatch(times);
    }
}
