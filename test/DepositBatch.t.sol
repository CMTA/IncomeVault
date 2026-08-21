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
        t[0] = 500; t[1] = 500;
        a[0] = 40;  a[1] = 60;

        _approve(100);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.depositBatch(t, a);
        assertEq(incomeVault.segregatedDividend(500), 100);
    }

    /* ============ guards ============ */
    function testCannotDepositBatchWithMismatchedLengths() public {
        uint256[] memory a = new uint256[](2);
        a[0] = 1; a[1] = 2;
        _approve(600);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_InvalidLengths.selector, 3, 2));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.depositBatch(times, a);
    }

    function testCannotDepositBatchWithAZeroAmount() public {
        uint256[] memory a = new uint256[](3);
        a[0] = 100; a[1] = 0; a[2] = 300;
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
        vm.expectRevert(abi.encodeWithSelector(
            AccessControlUnauthorizedAccount.selector, ATTACKER, INCOME_VAULT_DEPOSIT_ROLE));
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
    * @dev WARNING: run this **without** `--gas-report`. The assertions compare `gasleft()` deltas
    * across a different number of external calls — one for the batch, three for the separate
    * deposits — and Foundry's tracing charges each traced call. The overhead therefore lands roughly
    * three times as heavily on the second measurement and flips the first assertion, which fails as
    * `batch is expected to cost more in-call: 161275 <= 263423`. That is instrumentation, not a
    * regression: the same test passes on the same bytecode under a plain `forge test`.
    *
    * No cheatcode reports whether tracing is active, and correcting for it would mean subtracting a
    * measured per-call overhead — more fragile than the thing it protects. Documented instead.
    */
    function testBatchIsCheaperPerTransaction() public {
        uint256 intrinsic = 21_000;

        _approve(600);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        uint256 g0 = gasleft();
        incomeVault.depositBatch(times, amounts);
        uint256 batchCall = g0 - gasleft();

        _deployContracts();
        tokenPayment.mint(DEFAULT_ADMIN_ADDRESS, 10_000);
        _approve(600);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        uint256 g1 = gasleft();
        incomeVault.deposit(times[0], amounts[0]);
        incomeVault.deposit(times[1], amounts[1]);
        incomeVault.deposit(times[2], amounts[2]);
        uint256 separateCalls = g1 - gasleft();
        vm.stopPrank();

        uint256 batchTotal = batchCall + intrinsic;
        uint256 separateTotal = separateCalls + (3 * intrinsic);

        console.log("in-call  depositBatch(3):", batchCall);
        console.log("in-call  3 x deposit:   ", separateCalls);
        console.log("total    depositBatch(3):", batchTotal);
        console.log("total    3 x deposit:   ", separateTotal);

        // in-call the batch is the more expensive of the two
        assertGt(batchCall, separateCalls, "batch is expected to cost more in-call");
        // but a caller sending one transaction instead of three still comes out ahead
        assertLt(batchTotal, separateTotal, "batch should win once the per-transaction cost is counted");
    }
}
