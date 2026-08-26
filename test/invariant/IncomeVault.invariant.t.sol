// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "../HelperContract.sol";
import {IncomeVaultHandler} from "./IncomeVaultHandler.sol";

/**
 * @title Invariants of the dividend accounting — finding B-3
 * @dev
 * The example suites check named scenarios. These check properties that must hold across **every**
 * ordering of deposits, claims, batch claims, both distribution variants, withdrawals, freezes,
 * pauses and time warps.
 */
contract IncomeVaultInvariantTest is HelperContract {
    IncomeVaultHandler handler;

    uint256 constant HOLDER_BALANCE = 1_000;

    function setUp() public {
        _deployContracts();

        uint256[3] memory times = [block.timestamp + 100, block.timestamp + 200, block.timestamp + 300];
        address[3] memory holders = [ADDRESS1, ADDRESS2, ADDRESS3];

        // give every holder a snapshot balance so the pro-rata maths is non-degenerate
        for (uint256 i = 0; i < 3; ++i) {
            vm.prank(CMTAT_ADMIN);
            snapshotEngine.scheduleSnapshot(times[i]);
        }
        for (uint256 i = 0; i < 3; ++i) {
            vm.prank(CMTAT_ADMIN);
            CMTAT_CONTRACT.mint(holders[i], HOLDER_BALANCE);
        }

        handler = new IncomeVaultHandler(incomeVault, tokenPayment, DEFAULT_ADMIN_ADDRESS, times, holders);

        // the handler drives every privileged action, so it needs the roles
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.grantRole(DEFAULT_ADMIN_ROLE_BYTES, address(handler));
        vm.stopPrank();

        targetContract(address(handler));
    }

    bytes32 constant DEFAULT_ADMIN_ROLE_BYTES = bytes32(0);

    /**
     * @notice The vault never pays out more than was deposited
     * @dev The headline solvency property. `g_paid` is the sum of every balance increase actually
     * observed on a holder, across all three payout paths.
     */
    function invariant_neverPaysMoreThanWasDeposited() public view {
        assertLe(handler.g_paid(), handler.g_deposited(), "paid out more than was ever deposited");
    }

    /**
     * @notice A holder is paid at most once per dividend time
     * @dev Crosses all three payout paths: `claimDividend`, `claimDividendBatch` and both
     * `distributeDividend` variants must not be combinable into a double payment.
     */
    function invariant_noHolderIsPaidTwiceForOneTime() public view {
        for (uint256 h = 0; h < 3; ++h) {
            address holder = handler.holders(h);
            for (uint256 t = 0; t < 3; ++t) {
                assertLe(
                    handler.g_payCount(holder, handler.times(t)),
                    1,
                    "a holder was paid twice for the same dividend time"
                );
            }
        }
    }

    /**
     * @notice `claimedDividend` is monotonic — once set it is never cleared
     * @dev Checked by construction: nothing in the contract writes `false`, and the pay counter above
     * would exceed one if a cleared flag ever allowed a second payment.
     */
    function invariant_claimedFlagIsMonotonic() public view {
        for (uint256 h = 0; h < 3; ++h) {
            address holder = handler.holders(h);
            for (uint256 t = 0; t < 3; ++t) {
                uint256 time = handler.times(t);
                if (handler.g_payCount(holder, time) > 0) {
                    assertTrue(
                        incomeVault.claimedDividend(holder, time), "a holder was paid but is not marked as claimed"
                    );
                }
            }
        }
    }

    /**
     * @notice Every payout is explained by a period becoming claimed
     */
    function invariant_noUnexplainedPayment() public view {
        assertEq(
            handler.g_unexplainedPayments(), 0, "a batch path paid a holder without any period transitioning to claimed"
        );
    }

    /**
     * @notice The vault's token balance always accounts for every deposit
     * @dev balance == deposited - paid - withdrawn, where `paid` is measured as balance increases on
     * the three holders. Value leaving to any *other* recipient breaks the identity, so this is a
     * leakage check rather than a tautology.
     */
    function invariant_balanceAccountsForEveryDeposit() public view {
        assertEq(
            tokenPayment.balanceOf(address(incomeVault)),
            handler.g_deposited() - handler.g_paid() - handler.g_withdrawn(),
            "vault balance does not reconcile with deposits, payouts and withdrawals"
        );
    }

    /**
     * @notice Every period's residue is actually backed by tokens the vault holds
     * @dev
     * The solvency property the earlier invariants missed. `sum(unclaimedDividend)` is what the vault
     * still owes across periods; it must never exceed the balance, or one period's accounting is
     * promising another period's money. Withdrawing from a fully-claimed period used to break exactly
     * this.
     */
    function invariant_everyPeriodResidueIsBacked() public view {
        uint256 owed;
        for (uint256 t = 0; t < 3; ++t) {
            owed += incomeVault.unclaimedDividend(handler.times(t));
        }
        assertLe(
            owed,
            tokenPayment.balanceOf(address(incomeVault)),
            "the sum of per-period residues exceeds the tokens actually held"
        );
    }

    /**
     * @notice The per-time accounting never exceeds what is still held
     * @dev `segregatedDividend` is the pro-rata denominator and is deliberately *not* decremented on
     * a payout, so it is a record of what was deposited for a period, reduced only by `withdraw`.
     */
    function invariant_segregatedNeverExceedsDeposits() public view {
        uint256 sum;
        for (uint256 t = 0; t < 3; ++t) {
            sum += incomeVault.segregatedDividend(handler.times(t));
        }
        assertLe(sum, handler.g_deposited(), "segregated accounting exceeds total deposits");
    }
}
