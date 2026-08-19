// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== OpenZeppelin === */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
/* ==== IncomeVault === */
import {ISnapshotSource} from "../interfaces/ISnapshotSource.sol";
import {IncomeVaultValidationModule} from "../modules/IncomeVaultValidationModule.sol";
import {IncomeVaultInternal} from "../libraries/IncomeVaultInternal.sol";

/**
* @title Restricted functions
*/
abstract contract IncomeVaultRestricted is ReentrancyGuardTransient, IncomeVaultValidationModule, IncomeVaultInternal {
    // Security
    using SafeERC20 for IERC20;

    /* ============ Modifier ============ */
    /// @dev Restricts the deposit of dividends
    modifier onlyDepositManager() {
        _authorizeDeposit();
        _;
    }

    /// @dev Restricts the withdrawal of the deposited funds
    modifier onlyWithdrawManager() {
        _authorizeWithdraw();
        _;
    }

    /// @dev Restricts the issuer-driven distribution of the dividends
    modifier onlyDistributeManager() {
        _authorizeDistribute();
        _;
    }

    /// @dev Restricts the configuration of the claim window
    modifier onlyVaultOperator() {
        _authorizeOperator();
        _;
    }

    /// @dev Restricts the replacement of the snapshot source
    modifier onlySnapshotEngineManager() {
        _authorizeSnapshotEngineManagement();
        _;
    }

    /* ============  Initializer Function ============ */
    /**
    * @dev calls the different initialize functions from the different modules
    * @param timeLimitToWithdraw_ delay, after the dividend time, during which a claim is accepted
    */
    function __IncomeVaultRestricted_init_unchained(
        uint256 timeLimitToWithdraw_
    ) internal onlyInitializing {
       _setTimeLimitToWithdraw(timeLimitToWithdraw_);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State restricted functions ============ */
    /**
    * @notice deposit an amount to pay the dividends.
    * @param time provide the date where you want to perform a deposit
    * @param amount the amount to deposit
    */
    function deposit(uint256 time, uint256 amount) public virtual onlyDepositManager {
        address sender = _msgSender();
        if(amount == 0) {
            revert IncomeVault_NoAmountSend();
        }
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        $._segregatedDividend[time] += amount;
        emit newDeposit(time, sender, amount);
        // Will revert in case of failure
        $._ERC20TokenPayment.safeTransferFrom(sender, address(this), amount);
    }

    /**
    * @notice Deposit for several dividend times in one transaction
    * @dev
    * Equivalent to calling {deposit} once per entry — same accounting, same `newDeposit` event per
    * entry — but the payment token is pulled **once** for the total instead of once per time. That is
    * the reason the function exists; the common case is an issuer opening a year of coupon periods.
    *
    * Repeating a `time` is allowed and accumulates, exactly as separate calls would.
    *
    * @param times the dividend times to deposit for
    * @param amounts the amount to deposit for each time, must be the same length and each non-zero
    */
    function depositBatch(uint256[] calldata times, uint256[] calldata amounts)
        public virtual onlyDepositManager
    {
        if(times.length != amounts.length){
            revert IncomeVault_InvalidLengths(times.length, amounts.length);
        }
        if(times.length == 0){
            revert IncomeVault_NoAmountSend();
        }
        address sender = _msgSender();
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        uint256 total;
        for(uint256 i = 0; i < times.length; ++i){
            if(amounts[i] == 0) {
                revert IncomeVault_NoAmountSend();
            }
            $._segregatedDividend[times[i]] += amounts[i];
            total += amounts[i];
            emit newDeposit(times[i], sender, amounts[i]);
        }
        // One transfer for the whole batch. Will revert in case of failure.
        $._ERC20TokenPayment.safeTransferFrom(sender, address(this), total);
    }

    /**
    * @notice withdraw a certain amount at a specified time.
    * @param time provide the date where you want to perform a deposit
    * @param amount the amount to withdraw
    * @param withdrawAddress address to receive `amount`of tokens
    */
    function withdraw(uint256 time, uint256 amount, address withdrawAddress) public virtual onlyWithdrawManager {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        if($._segregatedDividend[time] < amount) {
            revert IncomeVault_NotEnoughAmount();
        }
        $._segregatedDividend[time] -= amount;
        emit Withdraw(time, withdrawAddress, amount);
        // Will revert in case of failure
        $._ERC20TokenPayment.safeTransfer(withdrawAddress, amount);
    }

    /**
    * @notice withdraw all tokens from ERC20TokenPayment contracts deposited
    * @param amount the amount to withdraw
    * @param withdrawAddress address to receive `amount`of tokens
    */
    function withdrawAll(uint256 amount, address withdrawAddress) public virtual onlyWithdrawManager {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        emit WithdrawAll(withdrawAddress, amount);
        // Will revert in case of failure
        $._ERC20TokenPayment.safeTransfer(withdrawAddress, amount);
    }

    /**
    * @notice distribute the dividends
    * @param addresses compute and transfer dividend for these holders
    * @param time dividend time
    * @dev The dividends are distributed only if they have not yet been claimed by the token holder.
    * Subject to the same claim window **and** the same transfer restrictions as
    * {IncomeVaultOpen-claimDividend}: a holder the pause, freeze or RuleEngine refuses cannot be paid
    * by the issuer either, and one blocked holder reverts the whole distribution.
    */
    function distributeDividend(address[] calldata addresses, uint256 time) public virtual onlyDistributeManager {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        // Same window as a holder-driven claim: the claims must be open, `time` must have passed so the
        // snapshot is recorded, and the withdraw limit must not have expired. Distributing before `time`
        // would read the *live* balances, because {ISnapshotSource} falls back to them when no snapshot
        // exists yet, and would consume the holder's claim for that period at the wrong amount.
        _revertOnInvalidTime(_timeCode($, time, $._timeLimitToWithdraw));
        // Get info from the snapshot source
        (uint256[] memory tokenHolderBalance, uint256 totalSupply) = $._snapshotEngine.snapshotInfoBatch(time, addresses);
        // Compute dividend for all token holders
        uint256[] memory tokenHolderDividend = _computeDividendBatch(time, addresses, tokenHolderBalance, totalSupply);
        // transfer the dividends for all token holders
        for(uint256 i = 0; i < addresses.length; ++i){
             // The dividends are distributed only if they have not yet been claimed by the token holder
             if (!$._claimedDividend[addresses[i]][time]){
                // transfer dividends
                if(tokenHolderDividend[i] > 0){
                    // Same transfer restriction as a holder-driven claim: pause, freeze and RuleEngine.
                    // Reverts the whole distribution rather than skipping the holder, so a blocked
                    // address cannot be silently dropped from a payout the operator believes succeeded.
                    // The error carries the address, so it can be removed from the list and retried.
                    _validateTransfer(address(this), addresses[i], tokenHolderDividend[i]);
                    _transferDividend(time, addresses[i], tokenHolderDividend[i]);
                }
            }
        }
    }

    /**
    * @notice Distribute the dividends, skipping any holder whose payout is refused
    * @dev
    * Same computation as {distributeDividend}, but a holder the ValidationModule or the payment token
    * refuses is **skipped** instead of reverting the whole call. Use it when one non-compliant address
    * must not block a large payout run; use {distributeDividend} when the distribution should be
    * all-or-nothing.
    *
    * Each payout is attempted through an external self-call so it can be wrapped in `try`/`catch`,
    * which gives **per-holder atomicity**: a holder is either fully paid — marked claimed *and*
    * transferred — or left completely untouched and still able to claim later. A partial state where
    * a holder is marked as claimed without receiving the tokens is not reachable.
    *
    * Every skip emits {DividendDistributionSkipped} carrying the raw revert data, so the cause can be
    * decoded off-chain, and the skipped holders are returned for the caller to act on directly.
    *
    * @custom:security `catch` cannot distinguish a refused payout from an out-of-gas failure. The two
    * contracts that can consume gas here — the payment token and the RuleEngine — are both set by the
    * admin and trusted; a malicious RuleEngine could nonetheless make holders appear skipped. That is
    * within the existing trust assumption for the RuleEngine, not a new one.
    *
    * @param addresses compute and transfer dividend for these holders
    * @param time dividend time
    * @return paidCount how many holders were paid
    * @return skipped the holders that were not paid, trimmed to `paidCount` subtracted from the input
    */
    function distributeDividendBestEffort(address[] calldata addresses, uint256 time)
        public virtual nonReentrant onlyDistributeManager
        returns (uint256 paidCount, address[] memory skipped)
    {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        _revertOnInvalidTime(_timeCode($, time, $._timeLimitToWithdraw));

        (uint256[] memory tokenHolderBalance, uint256 totalSupply) = $._snapshotEngine.snapshotInfoBatch(time, addresses);
        uint256[] memory tokenHolderDividend = _computeDividendBatch(time, addresses, tokenHolderBalance, totalSupply);

        address[] memory skippedBuffer = new address[](addresses.length);
        uint256 skippedCount;

        for(uint256 i = 0; i < addresses.length; ++i){
            if($._claimedDividend[addresses[i]][time] || tokenHolderDividend[i] == 0){
                continue;
            }
            // External self-call: `try` needs one, and it is what bounds the revert to this holder.
            try this.transferDividendSelf(time, addresses[i], tokenHolderDividend[i]) {
                ++paidCount;
            } catch (bytes memory reason) {
                skippedBuffer[skippedCount] = addresses[i];
                ++skippedCount;
                emit DividendDistributionSkipped(time, addresses[i], reason);
            }
        }

        skipped = new address[](skippedCount);
        for(uint256 i = 0; i < skippedCount; ++i){
            skipped[i] = skippedBuffer[i];
        }
    }

    /**
    * @notice Validate and pay one dividend — callable **only by the vault itself**
    * @dev
    * This exists solely so {distributeDividendBestEffort} can wrap a payout in `try`/`catch`, which
    * requires an external call. It carries no access control of its own beyond the self-call check,
    * so that check is what stands between it and an unauthorized payout: reverts
    * {IncomeVault_OnlySelfCall} for every caller other than `address(this)`.
    *
    * `msg.sender` is used deliberately rather than `_msgSender()`. The check must identify the real
    * caller; an ERC-2771 forwarder must never be able to present itself as the vault.
    *
    * @param time dividend time
    * @param tokenHolder the holder to pay
    * @param tokenHolderDividend the amount to pay
    */
    function transferDividendSelf(uint256 time, address tokenHolder, uint256 tokenHolderDividend) public virtual {
        if(msg.sender != address(this)){
            revert IncomeVault_OnlySelfCall();
        }
        _validateTransfer(address(this), tokenHolder, tokenHolderDividend);
        _transferDividend(time, tokenHolder, tokenHolderDividend);
    }

    /**
    * @notice set the status to open or close the claims for a given time
    * @param time target time
    * @param status boolean (true or false)
    * 
    */
    function setStatusClaim(uint256 time, bool status) public virtual onlyVaultOperator {
        _setStatusClaim(time, status);
    }

    /**
    * @notice Replace the contract the vault reads the holder balances from
    * @dev
    * Only accepted while **no claim period is open** — `openClaimCount()` must be zero. Changing the
    * source under an open period would silently re-price every unclaimed dividend of that period,
    * because the amounts are computed from the source at claim time, not fixed at deposit.
    *
    * @custom:security This restriction narrows the hazard, it does not remove it. Entitlements are
    * still resolved against whichever source is configured *when the claim happens*, so re-opening a
    * past `time` after a swap would resolve it against the new source. Holders who already claimed are
    * protected — `claimedDividend` persists across the change — but holders who had not are not.
    * Treat a swap as a migration requiring every period to be settled and closed, not as a routine
    * configuration change.
    *
    * @param snapshotEngine_ the new snapshot source, must implement {ISnapshotSource} and be non-zero
    */
    function setSnapshotEngine(ISnapshotSource snapshotEngine_) public virtual onlySnapshotEngineManager {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        uint256 open = $._openClaimCount;
        if(open != 0){
            revert IncomeVault_ClaimPeriodOpen(open);
        }
        if(address(snapshotEngine_) == address($._snapshotEngine)){
            revert IncomeVault_SameValue();
        }
        _setSnapshotEngine(snapshotEngine_);
    }

    /**
    * @notice configure the time limit to withdraw
    * @dev reverts if `timeLimitToWithdraw_` is zero: that would leave a one-second claim window
    * @param timeLimitToWithdraw_ delay, after the dividend time, during which a claim is accepted,
    * must be greater than zero
    */
    function setTimeLimitToWithdraw(uint256 timeLimitToWithdraw_) public virtual onlyVaultOperator {
        _setTimeLimitToWithdraw(timeLimitToWithdraw_);
    }
    

    /* ============ Access Control ============ */
    /**
    * @dev Authorization hook invoked before a deposit.
    * Implemented by the deployment contract with the desired access-control policy.
    */
    function _authorizeDeposit() internal view virtual;

    /**
    * @dev Authorization hook invoked before {withdraw} and {withdrawAll}.
    * Implemented by the deployment contract with the desired access-control policy.
    */
    function _authorizeWithdraw() internal view virtual;

    /**
    * @dev Authorization hook invoked before {distributeDividend}.
    * Implemented by the deployment contract with the desired access-control policy.
    */
    function _authorizeDistribute() internal view virtual;

    /**
    * @dev Authorization hook invoked before {setStatusClaim} and {setTimeLimitToWithdraw}.
    * Implemented by the deployment contract with the desired access-control policy.
    */
    function _authorizeOperator() internal view virtual;

    /**
    * @dev Authorization hook invoked before {setSnapshotEngine}.
    * Implemented by the deployment contract with the desired access-control policy.
    */
    function _authorizeSnapshotEngineManagement() internal view virtual;
}
