// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {Vm} from "forge-std/Vm.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

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
                (
                    DEFAULT_ADMIN_ADDRESS,
                    IERC20(address(tokenPayment)),
                    ISnapshotSource(address(snapshotEngine)),
                    IRuleEngine(ZERO_ADDRESS),
                    TIME_LIMIT_TO_WITHDRAW
                )
            ),
            opts
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool payment;
        bool snapshot;
        bool timeLimit;
        for (uint256 i = 0; i < logs.length; ++i) {
            bytes32 t = logs[i].topics[0];
            if (t == ERC20TokenPaymentSet.selector) payment = true;
            if (t == DividendSnapshotSourceSet.selector) snapshot = true;
            if (t == TimeLimitToWithdrawSet.selector) timeLimit = true;
        }
        assertTrue(payment, "ERC20TokenPaymentSet not emitted at initialize");
        assertTrue(snapshot, "DividendSnapshotSourceSet not emitted at initialize");
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
        incomeVault.validateTimeBatch(times); // does not revert
        incomeVault.validateTime(defaultSnapshotTime); // same verdict
        assertEq(uint256(incomeVault.validateTimeCode(defaultSnapshotTime)), 0);
    }

    /* ============ H-1 — the push path applies the same claim window as the pull path ============ */
    /**
     * @notice `distributeDividend` must refuse a distribution before `time`
     * @dev
     * Before `time` the snapshot has not been recorded, and {ISnapshotSource} falls back to the **live**
     * balance — so a distribution would pay from current balances and permanently consume the holder's
     * claim for that period at the wrong amount. This is finding H-1.
     */
    function testCannotDistributeBeforeTheDividendTime() public {
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        assertLt(block.timestamp, defaultSnapshotTime);
        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;

        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TooEarlyToWithdraw.selector, block.timestamp));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);

        // nothing was paid and the claim is still available to the holder
        assertEq(tokenPayment.balanceOf(ADDRESS1), 0);
        assertEq(incomeVault.claimedDividend(ADDRESS1, defaultSnapshotTime), false);
    }

    /**
     * @notice `distributeDividend` must refuse a distribution after the withdraw limit
     */
    function testCannotDistributeAfterTheWithdrawLimit() public {
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + TIME_LIMIT_TO_WITHDRAW + 1);

        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TooLateToWithdraw.selector, block.timestamp));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);
    }

    /**
     * @notice The claim-not-activated case still reverts with its own error
     */
    function testCannotDistributeWhenTheClaimIsNotActivated() public {
        _performDeposit();
        vm.warp(defaultSnapshotTime + 50);

        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_ClaimNotActivated.selector));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);
    }

    /**
     * @notice Inside the window the distribution still works, on the recorded snapshot balances
     */
    function testDistributeInsideTheWindowStillWorks() public {
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);

        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);

        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount);
        assertEq(incomeVault.claimedDividend(ADDRESS1, defaultSnapshotTime), true);
    }

    /**
     * @notice The push path and the pull path now agree on when a payout is allowed
     */
    function testPushAndPullAgreeOnTheWindow() public {
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;

        // too early: both refuse, with the same error
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TooEarlyToWithdraw.selector, block.timestamp));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TooEarlyToWithdraw.selector, block.timestamp));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);

        // too late: both refuse, with the same error
        vm.warp(defaultSnapshotTime + TIME_LIMIT_TO_WITHDRAW + 1);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TooLateToWithdraw.selector, block.timestamp));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TooLateToWithdraw.selector, block.timestamp));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);
    }

    /* ============ H-2 — the push path enforces the same restrictions as the pull path ============ */
    /**
     * @notice A frozen holder cannot be paid by the issuer either
     */
    function testCannotDistributeToAFrozenHolder() public {
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setAddressFrozen(ADDRESS1, true, "");

        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS1, defaultDepositAmount
            )
        );
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);

        assertEq(tokenPayment.balanceOf(ADDRESS1), 0);
        assertEq(incomeVault.claimedDividend(ADDRESS1, defaultSnapshotTime), false);
    }

    /**
     * @notice Pausing the vault stops the issuer-driven distribution too
     */
    function testCannotDistributeWhilePaused() public {
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.pause();

        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS1, defaultDepositAmount
            )
        );
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);
    }

    /**
     * @notice One blocked holder reverts the whole batch, and the error names that holder
     * @dev Same semantics as {claimDividendBatch}: the vault fails closed rather than paying a
     * partial set silently. `IncomeVault_InvalidTransfer` carries the address so the operator can
     * remove it from the list and retry.
     */
    function testOneBlockedHolderRevertsTheWholeDistribution() public {
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

        // only the second holder is frozen
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setAddressFrozen(ADDRESS2, true, "");

        address[] memory addresses = new address[](2);
        addresses[0] = ADDRESS1;
        addresses[1] = ADDRESS2;
        vm.expectRevert(
            abi.encodeWithSelector(
                IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS2, defaultDepositAmount / 2
            )
        );
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);

        // the whole batch is rolled back, including the holder who was allowed
        assertEq(tokenPayment.balanceOf(ADDRESS1), 0);
        assertEq(incomeVault.claimedDividend(ADDRESS1, defaultSnapshotTime), false);
    }

    /**
     * @notice With every holder allowed the distribution is unchanged
     */
    function testDistributeStillWorksWhenEveryHolderIsAllowed() public {
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);

        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);

        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount);
    }

    /* ============ A-1 — a zero withdraw limit cannot be configured ============ */
    /**
     * @notice `setTimeLimitToWithdraw(0)` is refused
     * @dev
     * With `timeLimitToWithdraw == 0` the claim window `[time, time + limit]` collapses to the single
     * instant `block.timestamp == time`: one second later `_timeCode` already returns
     * `TOO_LATE_TO_WITHDRAW`. The period becomes effectively unclaimable, and nothing signalled it —
     * the transaction succeeded and the event fired. Finding A-1 of `CLAUDE_IMPROVEMENT.md`.
     */
    function testCannotSetAZeroTimeLimitToWithdraw() public {
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TimeLimitToWithdrawZeroNotAllowed.selector));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setTimeLimitToWithdraw(0);

        // the previous value is untouched
        assertEq(incomeVault.timeLimitToWithdraw(), TIME_LIMIT_TO_WITHDRAW);
    }

    /**
     * @notice The guard lives in the internal setter, so `initialize` is covered too
     * @dev This is the point of validating in `_setTimeLimitToWithdraw` rather than at the call site:
     * a vault cannot be *deployed* into the bricked state either.
     */
    function testCannotInitializeWithAZeroTimeLimitToWithdraw() public {
        IncomeVault implementation = new IncomeVault(ZERO_ADDRESS);
        bytes memory data = abi.encodeCall(
            IncomeVault.initialize,
            (
                DEFAULT_ADMIN_ADDRESS,
                IERC20(address(tokenPayment)),
                ISnapshotSource(address(snapshotEngine)),
                IRuleEngine(ZERO_ADDRESS),
                0
            )
        );
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TimeLimitToWithdrawZeroNotAllowed.selector));
        new TransparentUpgradeableProxy(address(implementation), DEFAULT_ADMIN_ADDRESS, data);
    }

    /**
     * @notice Any positive value is still accepted — only zero is refused
     * @dev A short window may be a deliberate settlement policy; zero is the only value that is
     * broken by definition, so it is the only one rejected.
     */
    function testAOneSecondTimeLimitIsStillAccepted() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setTimeLimitToWithdraw(1);
        assertEq(incomeVault.timeLimitToWithdraw(), 1);
    }
}
