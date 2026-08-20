// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {CommonBase} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {IncomeVault} from "../../src/deployment/IncomeVault.sol";
import {ERC20PaymentMock} from "../mocks/ERC20PaymentMock.sol";

/**
* @title Bounded random driver for the IncomeVault invariants
* @dev
* Actions are squeezed into a small legal domain — three dividend times, three holders — so a run
* explores *orderings* rather than wandering into reverts. Calls that legitimately revert (claiming
* outside the window, while paused, while frozen) are caught: the invariant is about what the vault
* does when it succeeds, not about which calls are allowed.
*
* Ghosts are deliberately **scalar totals** rather than per-time sums. A batch claim pays several
* periods in one balance delta and cannot be attributed to a single `time` from the outside; totals
* need no attribution and still express the properties that matter.
*/
contract IncomeVaultHandler is CommonBase, StdUtils {
    IncomeVault public immutable vault;
    ERC20PaymentMock public immutable payment;
    address public immutable admin;

    uint256[3] public times;
    address[3] public holders;

    /* ============ ghosts ============ */
    uint256 public g_deposited;
    uint256 public g_paid;
    uint256 public g_withdrawn;
    /// @dev how many times a holder was actually paid for a time — must never exceed one
    mapping(address holder => mapping(uint256 time => uint256)) public g_payCount;
    uint256 public g_calls;

    constructor(
        IncomeVault vault_,
        ERC20PaymentMock payment_,
        address admin_,
        uint256[3] memory times_,
        address[3] memory holders_
    ) {
        vault = vault_;
        payment = payment_;
        admin = admin_;
        times = times_;
        holders = holders_;
    }

    function _time(uint256 seed) internal view returns (uint256) {
        return times[bound(seed, 0, 2)];
    }

    function _holder(uint256 seed) internal view returns (address) {
        return holders[bound(seed, 0, 2)];
    }

    /// @dev snapshot which (holder, time) pairs are already marked claimed
    function _claimedFlags(address holder) internal view returns (bool[3] memory f) {
        for (uint256 i = 0; i < 3; ++i) {
            f[i] = vault.claimedDividend(holder, times[i]);
        }
    }

    /// @dev payments observed on a batch path that no newly-claimed period explains
    uint256 public g_unexplainedPayments;

    /**
    * @dev Single-time paths: count a payment whenever the balance actually rises.
    * Counting flag *transitions* instead would be blind to the very thing this is here to catch —
    * a second payment for a period already marked claimed leaves the flag untouched.
    */
    function _settleOne(address holder, uint256 time, uint256 balanceBefore) internal {
        uint256 delta = payment.balanceOf(holder) - balanceBefore;
        if (delta > 0) {
            g_paid += delta;
            g_payCount[holder][time] += 1;
        }
    }

    /**
    * @dev Batch paths pay several periods in one delta, so payments are attributed by flag
    * transition. A delta that no transition explains is a re-payment and is counted separately.
    */
    function _settleBatch(address holder, uint256 balanceBefore, bool[3] memory claimedBefore) internal {
        uint256 delta = payment.balanceOf(holder) - balanceBefore;
        if (delta == 0) return;
        g_paid += delta;
        uint256 transitions;
        for (uint256 i = 0; i < 3; ++i) {
            if (!claimedBefore[i] && vault.claimedDividend(holder, times[i])) {
                g_payCount[holder][times[i]] += 1;
                ++transitions;
            }
        }
        if (transitions == 0) {
            ++g_unexplainedPayments;
        }
    }

    /* ============ actions ============ */
    function deposit(uint256 timeSeed, uint256 amount) external {
        ++g_calls;
        amount = bound(amount, 1, 1_000);
        payment.mint(admin, amount);
        vm.startPrank(admin);
        payment.approve(address(vault), amount);
        vault.deposit(_time(timeSeed), amount);
        vm.stopPrank();
        g_deposited += amount;
    }

    function setStatusClaim(uint256 timeSeed, bool status) external {
        ++g_calls;
        vm.prank(admin);
        vault.setStatusClaim(_time(timeSeed), status);
    }

    function claim(uint256 timeSeed, uint256 holderSeed) external {
        ++g_calls;
        address holder = _holder(holderSeed);
        uint256 time = _time(timeSeed);
        uint256 before = payment.balanceOf(holder);
        vm.prank(holder);
        try vault.claimDividend(time) {
            _settleOne(holder, time, before);
        } catch {}
    }

    function claimBatch(uint256 holderSeed) external {
        ++g_calls;
        address holder = _holder(holderSeed);
        uint256[] memory all = new uint256[](3);
        for (uint256 i = 0; i < 3; ++i) {
            all[i] = times[i];
        }
        uint256 before = payment.balanceOf(holder);
        bool[3] memory flags = _claimedFlags(holder);
        vm.prank(holder);
        try vault.claimDividendBatch(all) {
            _settleBatch(holder, before, flags);
        } catch {}
    }

    function distribute(uint256 timeSeed, uint256 holderSeed) external {
        ++g_calls;
        address holder = _holder(holderSeed);
        uint256 time = _time(timeSeed);
        address[] memory list = new address[](1);
        list[0] = holder;
        uint256 before = payment.balanceOf(holder);
        vm.prank(admin);
        try vault.distributeDividend(list, time) {
            _settleOne(holder, time, before);
        } catch {}
    }

    function distributeBestEffort(uint256 timeSeed) external {
        ++g_calls;
        uint256 time = _time(timeSeed);
        address[] memory list = new address[](3);
        uint256[3] memory befores;
        bool[3][3] memory flags;
        for (uint256 i = 0; i < 3; ++i) {
            list[i] = holders[i];
            befores[i] = payment.balanceOf(holders[i]);
            flags[i] = _claimedFlags(holders[i]);
        }
        vm.prank(admin);
        try vault.distributeDividendBestEffort(list, time) {
            for (uint256 i = 0; i < 3; ++i) {
                _settleBatch(holders[i], befores[i], flags[i]);
            }
        } catch {}
    }

    /**
    * @dev The issuer sweeping a period. Bounded to what the period holds so the call itself is legal;
    * whether sweeping *while claims are open* is wise is exactly what the solvency invariant probes.
    */
    function withdraw(uint256 timeSeed, uint256 amount) external {
        ++g_calls;
        uint256 time = _time(timeSeed);
        uint256 available = vault.segregatedDividend(time);
        if (available == 0) return;
        amount = bound(amount, 1, available);
        vm.prank(admin);
        try vault.withdraw(time, amount, admin) {
            g_withdrawn += amount;
        } catch {}
    }

    function freeze(uint256 holderSeed, bool status) external {
        ++g_calls;
        vm.prank(admin);
        vault.setAddressFrozen(_holder(holderSeed), status, "");
    }

    function pauseToggle(bool on) external {
        ++g_calls;
        vm.prank(admin);
        if (on) try vault.pause() {} catch {} else try vault.unpause() {} catch {}
    }

    function warp(uint256 secondsAhead) external {
        ++g_calls;
        vm.warp(block.timestamp + bound(secondsAhead, 1, 30 days));
    }
}
