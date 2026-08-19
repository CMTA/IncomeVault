// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {Vm} from "forge-std/Vm.sol";

/**
* @title Regression tests for the findings of CLAUDE_ANALYSIS.md
*/
contract CodeQualityTest is HelperContract {
    function setUp() public {
        _deployContracts();
    }

    /* ============ C-1 — the claim switch is evented ============ */
    function testSetStatusClaimEmits() public {
        vm.expectEmit(true, false, false, true);
        emit ClaimStatusSet(defaultSnapshotTime, true);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
    }

    /* ============ C-2 — the payment token is evented like its sibling ============ */
    function testInitializeEmitsBothEngineEvents() public {
        Options memory opts;
        opts.constructorData = abi.encode(ZERO_ADDRESS);

        vm.recordLogs();
        Upgrades.deployTransparentProxy(
            "IncomeVault.sol",
            DEFAULT_ADMIN_ADDRESS,
            abi.encodeCall(
                IncomeVault.initialize,
                (DEFAULT_ADMIN_ADDRESS, IERC20(address(tokenPayment)),
                 ISnapshotState(address(snapshotEngine)), IRuleEngine(ZERO_ADDRESS), TIME_LIMIT_TO_WITHDRAW)
            ),
            opts
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool payment; bool snapshot; bool timeLimit;
        for (uint256 i = 0; i < logs.length; ++i) {
            bytes32 t = logs[i].topics[0];
            if (t == ERC20TokenPaymentSet.selector) payment = true;
            if (t == SnapshotEngineSet.selector) snapshot = true;
            if (t == TimeLimitToWithdrawSet.selector) timeLimit = true;
        }
        assertTrue(payment, "ERC20TokenPaymentSet not emitted at initialize");
        assertTrue(snapshot, "SnapshotEngineSet not emitted at initialize");
        assertTrue(timeLimit, "TimeLimitToWithdrawSet not emitted at initialize");
    }

    /* ============ C-3 — funds leaving the vault are evented ============ */
    function testWithdrawEmits() public {
        _performOnlyDeposit();
        vm.expectEmit(true, true, false, true);
        emit Withdraw(defaultSnapshotTime, ADDRESS2, defaultDepositAmount);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.withdraw(defaultSnapshotTime, defaultDepositAmount, ADDRESS2);
    }

    function testWithdrawAllEmits() public {
        _performOnlyDeposit();
        vm.expectEmit(true, false, false, true);
        emit WithdrawAll(ADDRESS2, defaultDepositAmount);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.withdrawAll(defaultDepositAmount, ADDRESS2);
    }

    function testSetTimeLimitToWithdrawEmits() public {
        vm.expectEmit(false, false, false, true);
        emit TimeLimitToWithdrawSet(1 days);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setTimeLimitToWithdraw(1 days);
    }

    /* ============ A-1 — the batch path still behaves identically ============ */
    function testValidateTimeBatchStillRejectsEachCode() public {
        uint256[] memory times = new uint256[](1);
        times[0] = defaultSnapshotTime;

        vm.expectRevert(abi.encodeWithSelector(IncomeVault_ClaimNotActivated.selector));
        incomeVault.validateTimeBatch(times);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TooEarlyToWithdraw.selector, block.timestamp));
        incomeVault.validateTimeBatch(times);

        vm.warp(defaultSnapshotTime + TIME_LIMIT_TO_WITHDRAW + 1);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TooLateToWithdraw.selector, block.timestamp));
        incomeVault.validateTimeBatch(times);
    }

    /**
    * @notice The hoisted read must not change what a single-element batch reports
    */
    function testValidateTimeBatchMatchesValidateTime() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 10);

        uint256[] memory times = new uint256[](1);
        times[0] = defaultSnapshotTime;
        incomeVault.validateTimeBatch(times);          // does not revert
        incomeVault.validateTime(defaultSnapshotTime); // same verdict
        assertEq(uint256(incomeVault.validateTimeCode(defaultSnapshotTime)), 0);
    }

    /* ============ H-1 — CHARACTERISATION, documents current behaviour ============ */
    /**
    * @notice `distributeDividend` does not apply the claim window, so it can be called before
    * `time`, when the snapshot has not been recorded and {ISnapshotState} falls back to the
    * **live** balance. A holder-initiated `claimDividend` is refused at the same instant.
    * @dev This test pins the behaviour reported as H-1. If H-1 is fixed it must be updated:
    * the distribution should revert with IncomeVault_TooEarlyToWithdraw.
    */
    function testDistributeDividendIgnoresTheClaimWindow() public {
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // before `time`: the holder is refused
        assertLt(block.timestamp, defaultSnapshotTime);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TooEarlyToWithdraw.selector, block.timestamp));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);

        // ... yet the issuer can push the very same payout
        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);

        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount);
        assertEq(incomeVault.claimedDividend(ADDRESS1, defaultSnapshotTime), true);
    }
}
