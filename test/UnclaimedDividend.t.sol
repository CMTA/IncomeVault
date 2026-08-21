// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {SlotDerivation} from "@openzeppelin/contracts/utils/SlotDerivation.sol";

/**
* @title Per-period residue accounting — finding E-3
*/
contract UnclaimedDividendTest is HelperContract {
    using SlotDerivation for string;

    string constant NAMESPACE = "IncomeVault.storage.IncomeVaultInternal";
    uint256 t1;
    uint256 t2;

    function setUp() public {
        _deployContracts();
        t1 = block.timestamp + 100;
        t2 = block.timestamp + 200;

        vm.prank(CMTAT_ADMIN); snapshotEngine.scheduleSnapshot(t1);
        vm.prank(CMTAT_ADMIN); snapshotEngine.scheduleSnapshot(t2);

        tokenPayment.mint(DEFAULT_ADMIN_ADDRESS, 10_000);
    }

    function _deposit(uint256 time, uint256 amount) internal {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(incomeVault), amount);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deposit(time, amount);
    }

    /* ============ the view ============ */
    function testUnclaimedStartsAtTheDeposit() public {
        _deposit(t1, 1_000);
        assertEq(incomeVault.unclaimedDividend(t1), 1_000);
        assertEq(incomeVault.paidDividend(t1), 0);
    }

    function testUnclaimedFallsAsHoldersArePaid() public {
        vm.prank(CMTAT_ADMIN); CMTAT_CONTRACT.mint(ADDRESS1, 1_000);
        vm.prank(CMTAT_ADMIN); CMTAT_CONTRACT.mint(ADDRESS2, 1_000);
        _deposit(t1, 1_000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(t1, true);
        vm.warp(t1 + 10);

        vm.prank(ADDRESS1);
        incomeVault.claimDividend(t1);

        assertEq(incomeVault.paidDividend(t1), 500);
        assertEq(incomeVault.unclaimedDividend(t1), 500);
        // the denominator is deliberately untouched
        assertEq(incomeVault.segregatedDividend(t1), 1_000);
    }

    /**
    * @notice The residue an issuer sweeps is exactly the rounding dust
    * @dev Three holders sharing 1_000 each receive floor(1_000/3) = 333, leaving 1 behind.
    */
    function testUnclaimedIsTheRoundingDustOnceEveryoneClaimed() public {
        vm.prank(CMTAT_ADMIN); CMTAT_CONTRACT.mint(ADDRESS1, 1_000);
        vm.prank(CMTAT_ADMIN); CMTAT_CONTRACT.mint(ADDRESS2, 1_000);
        vm.prank(CMTAT_ADMIN); CMTAT_CONTRACT.mint(ADDRESS3, 1_000);
        _deposit(t1, 1_000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(t1, true);
        vm.warp(t1 + 10);

        vm.prank(ADDRESS1); incomeVault.claimDividend(t1);
        vm.prank(ADDRESS2); incomeVault.claimDividend(t1);
        vm.prank(ADDRESS3); incomeVault.claimDividend(t1);

        assertEq(incomeVault.paidDividend(t1), 999);
        assertEq(incomeVault.unclaimedDividend(t1), 1, "the dust is one wei of the payment token");

        // and the issuer can sweep exactly that, in one step
        // (read first: a call inside the argument list would consume the prank)
        uint256 dust = incomeVault.unclaimedDividend(t1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.withdraw(t1, dust, ADDRESS3);
        assertEq(incomeVault.unclaimedDividend(t1), 0);
    }

    /* ============ the bug this closes ============ */
    /**
    * @notice A fully-claimed period cannot be swept again into another period's funds
    * @dev
    * Before this change `segregatedDividend[t1]` still read 1_000 after the sole holder had taken all
    * 1_000, so `withdraw(t1, 1_000)` succeeded and drained the money deposited for `t2`.
    */
    function testCannotSweepAFullyClaimedPeriodIntoAnotherPeriod() public {
        vm.prank(CMTAT_ADMIN); CMTAT_CONTRACT.mint(ADDRESS1, 1_000);
        _deposit(t1, 1_000);
        _deposit(t2, 1_000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(t1, true);
        vm.warp(t1 + 10);

        vm.prank(ADDRESS1);
        incomeVault.claimDividend(t1);           // takes all of t1

        assertEq(incomeVault.segregatedDividend(t1), 1_000, "denominator unchanged, as designed");
        assertEq(incomeVault.unclaimedDividend(t1), 0, "but nothing is left for t1");

        vm.expectRevert(abi.encodeWithSelector(IncomeVault_NotEnoughAmount.selector));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.withdraw(t1, 1_000, ADDRESS3);

        // t2's money is intact and still claimable
        assertEq(tokenPayment.balanceOf(address(incomeVault)), 1_000);
        assertEq(incomeVault.unclaimedDividend(t2), 1_000);
    }

    function testCanStillWithdrawWhatThePeriodActuallyHolds() public {
        _deposit(t1, 1_000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.withdraw(t1, 400, ADDRESS3);

        assertEq(tokenPayment.balanceOf(ADDRESS3), 400);
        assertEq(incomeVault.unclaimedDividend(t1), 600);
        assertEq(incomeVault.segregatedDividend(t1), 600);
    }

    function testCannotWithdrawMoreThanThePeriodHolds() public {
        _deposit(t1, 1_000);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_NotEnoughAmount.selector));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.withdraw(t1, 1_001, ADDRESS3);
    }

    /**
    * @notice Distribution counts towards the paid total too, not just holder-initiated claims
    */
    function testDistributionCountsTowardsPaid() public {
        vm.prank(CMTAT_ADMIN); CMTAT_CONTRACT.mint(ADDRESS1, 1_000);
        _deposit(t1, 1_000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(t1, true);
        vm.warp(t1 + 10);

        address[] memory list = new address[](1);
        list[0] = ADDRESS1;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(list, t1);

        assertEq(incomeVault.paidDividend(t1), 1_000);
        assertEq(incomeVault.unclaimedDividend(t1), 0);
    }

    /* ============ over-drawn periods ============ */
    /**
    * @notice A claim is never funded from another period's deposit
    * @dev
    * Deterministic reproduction of the sequence the invariant fuzzer found once: sweeping a period
    * mid-window lowers the pro-rata denominator, so a holder claiming afterwards is priced against
    * the reduced figure while the period no longer holds that much. Before the bound, the shortfall
    * was silently taken from another period's money.
    */
    function testAClaimCannotBeFundedByAnotherPeriod() public {
        vm.prank(CMTAT_ADMIN); CMTAT_CONTRACT.mint(ADDRESS1, 1_000);
        vm.prank(CMTAT_ADMIN); CMTAT_CONTRACT.mint(ADDRESS2, 1_000);
        vm.prank(CMTAT_ADMIN); CMTAT_CONTRACT.mint(ADDRESS3, 1_000);

        _deposit(t1, 900);
        _deposit(t2, 900);          // a second period, whose money must stay untouched
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(t1, true);
        vm.warp(t1 + 10);

        // one holder takes their third
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(t1);
        assertEq(incomeVault.paidDividend(t1), 300);
        assertEq(incomeVault.unclaimedDividend(t1), 600);

        // the issuer sweeps everything the period still holds, mid-window
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.withdraw(t1, 600, ADDRESS3);
        assertEq(incomeVault.segregatedDividend(t1), 300, "denominator lowered by the sweep");
        assertEq(incomeVault.unclaimedDividend(t1), 0, "nothing left for this period");

        // the next holder is now priced against 300 and would be owed 100 the period cannot fund
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_NotEnoughAmount.selector));
        vm.prank(ADDRESS2);
        incomeVault.claimDividend(t1);

        // t2's deposit is intact
        assertEq(incomeVault.unclaimedDividend(t2), 900);
        assertEq(tokenPayment.balanceOf(address(incomeVault)), 900);
    }

    /**
    * @notice `unclaimedDividend` reports zero rather than reverting on an over-drawn period
    */
    function testUnclaimedSaturatesInsteadOfUnderflowing() public {
        vm.prank(CMTAT_ADMIN); CMTAT_CONTRACT.mint(ADDRESS1, 1_000);
        vm.prank(CMTAT_ADMIN); CMTAT_CONTRACT.mint(ADDRESS2, 1_000);
        _deposit(t1, 1_000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(t1, true);
        vm.warp(t1 + 10);

        vm.prank(ADDRESS1);
        incomeVault.claimDividend(t1);                  // paid 500
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.withdraw(t1, 500, ADDRESS3);        // segregated down to 500

        assertEq(incomeVault.paidDividend(t1), 500);
        assertEq(incomeVault.segregatedDividend(t1), 500);
        assertEq(incomeVault.unclaimedDividend(t1), 0, "a view must never revert");
    }

    /**
    * @notice Truly over-drawn (`paid` strictly above `segregated`) still reports zero, not a panic
    * @dev
    * The test above reaches `paid == segregated`, where a saturating rule and a plain subtraction
    * agree — so it does not actually pin the saturation. `paid > segregated` is **unreachable through
    * the public API**: `withdraw` is bounded by `unclaimedDividend`, and `_transferDividend` refuses a
    * payout larger than it, so neither can push `paid` past `segregated`. The branch is defensive,
    * which is exactly why it needs `vm.store` to be covered at all.
    *
    * Without this, replacing the rule with `segregated - paid` passes the entire suite.
    */
    function testUnclaimedSaturatesWhenTrulyOverDrawn() public {
        _deposit(t1, 1_000);

        // _paidDividend is field 6 of the ERC-7201 struct; force it above _segregatedDividend
        bytes32 slot = keccak256(abi.encode(t1, uint256(NAMESPACE.erc7201Slot()) + 6));
        vm.store(address(incomeVault), slot, bytes32(uint256(1_500)));

        assertEq(incomeVault.paidDividend(t1), 1_500, "storage write did not land");
        assertGt(incomeVault.paidDividend(t1), incomeVault.segregatedDividend(t1));
        assertEq(incomeVault.unclaimedDividend(t1), 0, "must saturate, not underflow");
    }
}
