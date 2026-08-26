// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {Vm} from "forge-std/Vm.sol";

/**
 * @title Best-effort distribution — finding A-4
 */
contract DistributeBestEffortTest is HelperContract {
    function setUp() public {
        _deployContracts();
    }

    /// @dev two holders with equal balances, claims open, inside the window
    function _twoHolders() internal returns (address[] memory addresses) {
        _performOnlyDeposit();
        vm.prank(CMTAT_ADMIN);
        snapshotEngine.scheduleSnapshot(defaultSnapshotTime);
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.mint(ADDRESS1, ADDRESS1_INITIAL_AMOUNT);
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.mint(ADDRESS2, ADDRESS1_INITIAL_AMOUNT);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);

        addresses = new address[](2);
        addresses[0] = ADDRESS1;
        addresses[1] = ADDRESS2;
    }

    /* ============ the point of the function ============ */
    function testABlockedHolderIsSkippedAndTheRestArePaid() public {
        address[] memory addresses = _twoHolders();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setAddressFrozen(ADDRESS2, true, "");

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        (uint256 paidCount, address[] memory skipped) =
            incomeVault.distributeDividendBestEffort(addresses, defaultSnapshotTime);

        assertEq(paidCount, 1);
        assertEq(skipped.length, 1);
        assertEq(skipped[0], ADDRESS2);

        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount / 2);
        assertEq(tokenPayment.balanceOf(ADDRESS2), 0);
    }

    /**
     * @notice A skipped holder is left completely untouched and can still claim
     * @dev Per-holder atomicity: the self-call rolls back `claimedDividend` along with the transfer,
     * so a holder is never marked as paid without receiving the tokens.
     */
    function testASkippedHolderIsUntouchedAndCanClaimLater() public {
        address[] memory addresses = _twoHolders();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setAddressFrozen(ADDRESS2, true, "");

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividendBestEffort(addresses, defaultSnapshotTime);
        assertEq(incomeVault.claimedDividend(ADDRESS2, defaultSnapshotTime), false);

        // unfreeze, and the holder claims for themselves
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setAddressFrozen(ADDRESS2, false, "");
        vm.prank(ADDRESS2);
        incomeVault.claimDividend(defaultSnapshotTime);
        assertEq(tokenPayment.balanceOf(ADDRESS2), defaultDepositAmount / 2);
    }

    /**
     * @notice The skip is reported with decodable revert data
     */
    function testSkipEmitsTheReason() public {
        address[] memory addresses = _twoHolders();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setAddressFrozen(ADDRESS2, true, "");

        vm.recordLogs();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividendBestEffort(addresses, defaultSnapshotTime);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].topics[0] == DividendDistributionSkipped.selector) {
                found = true;
                assertEq(uint256(logs[i].topics[1]), defaultSnapshotTime);
                assertEq(address(uint160(uint256(logs[i].topics[2]))), ADDRESS2);
                bytes memory reason = abi.decode(logs[i].data, (bytes));
                assertEq(
                    bytes4(reason),
                    IncomeVault_InvalidTransfer.selector,
                    "reason should decode to IncomeVault_InvalidTransfer"
                );
            }
        }
        assertTrue(found, "DividendDistributionSkipped not emitted");
    }

    function testEveryHolderPaidWhenNoneIsBlocked() public {
        address[] memory addresses = _twoHolders();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        (uint256 paidCount, address[] memory skipped) =
            incomeVault.distributeDividendBestEffort(addresses, defaultSnapshotTime);

        assertEq(paidCount, 2);
        assertEq(skipped.length, 0);
        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount / 2);
        assertEq(tokenPayment.balanceOf(ADDRESS2), defaultDepositAmount / 2);
    }

    /* ============ the strict variant is unchanged ============ */
    function testTheStrictVariantStillRevertsOnTheSameInput() public {
        address[] memory addresses = _twoHolders();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setAddressFrozen(ADDRESS2, true, "");

        vm.expectRevert(
            abi.encodeWithSelector(
                IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS2, defaultDepositAmount / 2
            )
        );
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);
    }

    /* ============ the claim window still applies ============ */
    function testBestEffortStillEnforcesTheClaimWindow() public {
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TooEarlyToWithdraw.selector, block.timestamp));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividendBestEffort(addresses, defaultSnapshotTime);
    }

    /* ============ access control ============ */
    function testAttackerCannotRunTheBestEffortDistribution() public {
        address[] memory addresses = _twoHolders();
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_DISTRIBUTE_ROLE)
        );
        vm.prank(ATTACKER);
        incomeVault.distributeDividendBestEffort(addresses, defaultSnapshotTime);
    }

    /**
     * @notice The self-call helper is unreachable from outside — the critical guard
     * @dev It carries no role check of its own, so without this the payout path would be open to
     * anyone. Neither an attacker nor the privileged admin may call it directly.
     */
    function testNobodyCanCallTheSelfHelperDirectly() public {
        _twoHolders();

        vm.expectRevert(abi.encodeWithSelector(IncomeVault_OnlySelfCall.selector));
        vm.prank(ATTACKER);
        incomeVault.transferDividendSelf(defaultSnapshotTime, ATTACKER, defaultDepositAmount);

        vm.expectRevert(abi.encodeWithSelector(IncomeVault_OnlySelfCall.selector));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.transferDividendSelf(defaultSnapshotTime, ADDRESS1, defaultDepositAmount);

        assertEq(tokenPayment.balanceOf(ATTACKER), 0);
    }
}
