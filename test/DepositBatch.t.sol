// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Batch deposit — finding E-2
 */
contract DepositBatchTest is HelperContract {
    uint256[] times;
    uint256[] amounts;

    function setUp() public {
        _deployContracts();
        times = [uint256(1_000), 2_000, 3_000];
        amounts = [uint256(100), 200, 300];
        tokenPayment.mint(DEFAULT_ADMIN_ADDRESS, 10_000);
    }

    function _approve(uint256 amount) internal {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(incomeVault), amount);
    }

    /* ============ behaviour ============ */
    function testDepositBatchCreditsEveryTime() public {
        _approve(600);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.depositBatch(times, amounts);

        assertEq(incomeVault.segregatedDividend(1_000), 100);
        assertEq(incomeVault.segregatedDividend(2_000), 200);
        assertEq(incomeVault.segregatedDividend(3_000), 300);
        assertEq(tokenPayment.balanceOf(address(incomeVault)), 600);
    }

    /**
     * @notice One transfer for the batch, one event per entry
     */
    function testDepositBatchPullsTheTokenOnceAndEventsEachEntry() public {
        _approve(600);
        vm.recordLogs();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.depositBatch(times, amounts);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 deposits;
        uint256 transfers;
        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].topics[0] == newDeposit.selector) ++deposits;
            if (logs[i].topics[0] == keccak256("Transfer(address,address,uint256)")) ++transfers;
        }
        assertEq(deposits, 3, "one newDeposit per entry");
        assertEq(transfers, 1, "the payment token is pulled once for the total");
    }

    /**
     * @notice Identical outcome to calling `deposit` once per entry
     */
    function testDepositBatchMatchesSeparateDeposits() public {
        _approve(600);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deposit(times[0], amounts[0]);
        incomeVault.deposit(times[1], amounts[1]);
        incomeVault.deposit(times[2], amounts[2]);
        vm.stopPrank();

        uint256[3] memory separate = [
            incomeVault.segregatedDividend(times[0]),
            incomeVault.segregatedDividend(times[1]),
            incomeVault.segregatedDividend(times[2])
        ];
        uint256 separateBalance = tokenPayment.balanceOf(address(incomeVault));

        // same again on a fresh vault, in one call
        _deployContracts();
        tokenPayment.mint(DEFAULT_ADMIN_ADDRESS, 10_000);
        _approve(600);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.depositBatch(times, amounts);

        assertEq(incomeVault.segregatedDividend(times[0]), separate[0]);
        assertEq(incomeVault.segregatedDividend(times[1]), separate[1]);
        assertEq(incomeVault.segregatedDividend(times[2]), separate[2]);
        assertEq(tokenPayment.balanceOf(address(incomeVault)), separateBalance);
    }

    /**
     * @notice A repeated time accumulates, exactly as two separate deposits would
     */
    function testRepeatedTimeAccumulates() public {
        uint256[] memory t = new uint256[](2);
        uint256[] memory a = new uint256[](2);
        t[0] = 500;
        t[1] = 500;
        a[0] = 40;
        a[1] = 60;

        _approve(100);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.depositBatch(t, a);
        assertEq(incomeVault.segregatedDividend(500), 100);
    }

    /* ============ guards ============ */
    function testCannotDepositBatchWithMismatchedLengths() public {
        uint256[] memory a = new uint256[](2);
        a[0] = 1;
        a[1] = 2;
        _approve(600);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_InvalidLengths.selector, 3, 2));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.depositBatch(times, a);
    }

    function testCannotDepositBatchWithAZeroAmount() public {
        uint256[] memory a = new uint256[](3);
        a[0] = 100;
        a[1] = 0;
        a[2] = 300;
        _approve(600);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_NoAmountSend.selector));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.depositBatch(times, a);

        // nothing was credited: the whole batch rolled back
        assertEq(incomeVault.segregatedDividend(times[0]), 0);
    }

    function testCannotDepositAnEmptyBatch() public {
        uint256[] memory t = new uint256[](0);
        uint256[] memory a = new uint256[](0);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_NoAmountSend.selector));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.depositBatch(t, a);
    }

    function testCannotDepositBatchWithoutEnoughAllowance() public {
        _approve(599);
        vm.expectRevert();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.depositBatch(times, amounts);
    }

    function testAttackerCannotDepositBatch() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_DEPOSIT_ROLE)
        );
        vm.prank(ATTACKER);
        incomeVault.depositBatch(times, amounts);
    }

    /* ============ what it actually saves ============ */
    /**
     * @notice The batch is cheaper per *transaction*, not per call
     * @dev
     * Measured, and the naive framing is misleading: **inside a single transaction the batch costs
     * more** than the separate calls, because decoding two dynamic `calldata` arrays outweighs what is
     * saved by pulling the payment token once.
     *
     * The win is the intrinsic transaction cost. An issuer opening N periods sends **one** transaction
     * instead of N, paying 21,000 gas of base cost once rather than N times. This test compares the
     * totals a caller really pays.
     */
    /**
     * @dev Only the per-transaction total is asserted. The in-call figures are printed, not checked:
     * the two sides are measured across a different number of external calls — one for the batch,
     * three for the separate deposits — and Foundry's instrumentation charges per call, so under
     * `--gas-report` (what `make gas` runs) the overhead lands three times as heavily on the second
     * measurement and reverses the comparison on bytecode that has not changed. Asserting a
     * direction that the measurement mode decides would fail the suite for the wrong reason.
     *
     * Gas is read with `vm.lastCallGas()`, the EVM's own accounting, rather than from `gasleft()`
     * deltas around the calls, which also count what the harness spends between them.
     */
    function testBatchIsCheaperPerTransaction() public {
        uint256 intrinsic = 21_000;

        _approve(600);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.depositBatch(times, amounts);
        uint256 batchCall = vm.lastCallGas().gasTotalUsed;

        _deployContracts();
        tokenPayment.mint(DEFAULT_ADMIN_ADDRESS, 10_000);
        _approve(600);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deposit(times[0], amounts[0]);
        uint256 separateCalls = vm.lastCallGas().gasTotalUsed;
        incomeVault.deposit(times[1], amounts[1]);
        separateCalls += vm.lastCallGas().gasTotalUsed;
        incomeVault.deposit(times[2], amounts[2]);
        separateCalls += vm.lastCallGas().gasTotalUsed;
        vm.stopPrank();

        uint256 batchTotal = batchCall + intrinsic;
        uint256 separateTotal = separateCalls + (3 * intrinsic);

        console.log("in-call  depositBatch(3):", batchCall);
        console.log("in-call  3 x deposit:   ", separateCalls);
        console.log("total    depositBatch(3):", batchTotal);
        console.log("total    3 x deposit:   ", separateTotal);

        // a caller sending one transaction instead of three comes out ahead, which is the point of
        // the batch: the saving is the intrinsic cost paid once, not a cheaper deposit
        assertLt(batchTotal, separateTotal, "batch should win once the per-transaction cost is counted");
    }
}
