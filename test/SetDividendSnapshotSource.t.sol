// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {MinimalSnapshotSourceMock} from "./mocks/MinimalSnapshotSourceMock.sol";

/**
* @title Replacing the snapshot source — finding A-3
*/
contract SetDividendSnapshotSourceTest is HelperContract {
    MinimalSnapshotSourceMock newSource;

    function setUp() public {
        _deployContracts();
        newSource = new MinimalSnapshotSourceMock();

        _deployOwnableVault();
    }

    /* ============ the counter is exact ============ */
    function testOpenClaimCountTracksTheOpenPeriods() public {
        assertEq(incomeVault.openClaimCount(), 0);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(100, true);
        assertEq(incomeVault.openClaimCount(), 1);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(200, true);
        assertEq(incomeVault.openClaimCount(), 2);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(100, false);
        assertEq(incomeVault.openClaimCount(), 1);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(200, false);
        assertEq(incomeVault.openClaimCount(), 0);
    }

    /**
    * @notice Repeating a status must not move the counter — otherwise it could never return to zero
    */
    function testRepeatedStatusWritesDoNotDriftTheCounter() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(100, true);
        incomeVault.setStatusClaim(100, true);
        incomeVault.setStatusClaim(100, true);
        assertEq(incomeVault.openClaimCount(), 1);

        incomeVault.setStatusClaim(100, false);
        incomeVault.setStatusClaim(100, false);
        assertEq(incomeVault.openClaimCount(), 0);
        vm.stopPrank();

        // and closing a period that was never opened cannot underflow
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(999, false);
        assertEq(incomeVault.openClaimCount(), 0);
    }

    /* ============ the gate ============ */
    function testCannotReplaceTheSourceWhileAPeriodIsOpen() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        vm.expectRevert(abi.encodeWithSelector(IncomeVault_ClaimPeriodOpen.selector, 1));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setDividendSnapshotSource(ISnapshotSource(address(newSource)));

        assertEq(address(incomeVault.dividendSnapshotSource()), address(snapshotEngine));
    }

    function testCanReplaceTheSourceOnceEveryPeriodIsClosed() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, false);

        vm.expectEmit(true, false, false, false);
        emit DividendSnapshotSourceSet(ISnapshotSource(address(newSource)));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setDividendSnapshotSource(ISnapshotSource(address(newSource)));

        assertEq(address(incomeVault.dividendSnapshotSource()), address(newSource));
    }

    function testCannotReplaceWithTheSameSource() public {
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_SameValue.selector));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setDividendSnapshotSource(ISnapshotSource(address(snapshotEngine)));
    }

    function testCannotReplaceWithTheZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_SnapshotSourceWithAddressZeroNotAllowed.selector));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setDividendSnapshotSource(ISnapshotSource(ZERO_ADDRESS));
    }

    /* ============ access control, both variants ============ */
    function testAttackerCannotReplaceTheSourceRoleVariant() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, bytes32(0)));
        vm.prank(ATTACKER);
        incomeVault.setDividendSnapshotSource(ISnapshotSource(address(newSource)));
    }

    function testAttackerCannotReplaceTheSourceOwnableVariant() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", ATTACKER));
        vm.prank(ATTACKER);
        ownableVault.setDividendSnapshotSource(ISnapshotSource(address(newSource)));
    }

    function testOwnerCanReplaceTheSource() public {
        vm.prank(OWNER);
        ownableVault.setDividendSnapshotSource(ISnapshotSource(address(newSource)));
        assertEq(address(ownableVault.dividendSnapshotSource()), address(newSource));
    }

    /* ============ the replacement is actually used ============ */
    function testClaimsUseTheNewSourceAfterTheSwap() public {
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setDividendSnapshotSource(ISnapshotSource(address(newSource)));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);

        // the mock reports 100/400, so the holder gets a quarter rather than the whole deposit
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);
        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount / 4);
    }
}
