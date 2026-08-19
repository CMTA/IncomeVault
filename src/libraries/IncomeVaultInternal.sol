// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== OpenZeppelin === */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
/* ==== Snapshot === */
import {ISnapshotSource} from "../interfaces/ISnapshotSource.sol";
/* ==== IncomeVault === */
import {IncomeVaultInvariantStorage} from "./IncomeVaultInvariantStorage.sol";
import {IERC7540Operator} from "../interfaces/IERC7540Operator.sol";

/**
* @title Internal functions and ERC-7201 storage of the IncomeVault
* @dev
* The vault is token-agnostic: the snapshot source is any contract implementing {ISnapshotSource},
* e.g. the CMTA `SnapshotEngine` bound to an ERC-20, or a token embedding the snapshot logic itself.
*
* The state is held in an ERC-7201 namespaced storage struct, as OpenZeppelin Upgradeable and the
* CMTAT do. The namespace is derived from a hash, so it cannot collide with the storage of the
* inherited modules; no `__gap` is needed and new fields can be appended to the struct freely.
*/
abstract contract IncomeVaultInternal is IncomeVaultInvariantStorage, IERC7540Operator {
    // Manage transfer failure
    using SafeERC20 for IERC20;

    /* ============ Type declarations ============ */
    /**
    * @notice Why a dividend time is not claimable, or `OK`
    * @dev Shared by the holder-driven claims ({IncomeVaultOpen}) and the issuer-driven distribution
    * ({IncomeVaultRestricted}) so both apply the same window.
    */
    enum TIME_ERROR_CODE {OK, CLAIM_NOT_ACTIVATED, TOO_LATE_TO_WITHDRAW, TOO_EARLY_TO_WITHDRAW}

    /* ============ ERC-7201 ============ */
    /**
    * @dev Slot holding the ERC-7201 namespaced storage of this module, derived as
    * keccak256(abi.encode(uint256(keccak256("IncomeVault.storage.IncomeVaultInternal")) - 1)) & ~bytes32(uint256(0xff))
    * The derivation is re-checked in `test/IncomeVaultStorage.t.sol`.
    */
    bytes32 private constant IncomeVaultInternalStorageLocation = 0xe4f8b033bcfc537db031b0e68e3c1ab0f1de86cf03893d031b6590510b0c0c00;

    /* ==== ERC-7201 State Variables === */
    /// @custom:storage-location erc7201:IncomeVault.storage.IncomeVaultInternal
    struct IncomeVaultInternalStorage {
        // Snapshot source used to read the token holder balances and the total supply
        ISnapshotSource _snapshotEngine;
        // ERC-20 token used to pay the dividends
        IERC20 _ERC20TokenPayment;
        // Records, per token holder and per dividend time, whether the dividends were claimed
        mapping(address tokenHolder => mapping(uint256 time => bool claimed)) _claimedDividend;
        // Total amount of payment token deposited for a given dividend time
        mapping(uint256 time => uint256 dividend) _segregatedDividend;
        // Claim status, per dividend time: true when the holders can claim
        mapping(uint256 time => bool status) _segregatedClaim;
        // Delay, after the dividend time, during which a claim is still accepted
        uint256 _timeLimitToWithdraw;
        // How many dividend times currently have their claims open. Appended after the fields above:
        // ERC-7201 struct members are append-only, never reordered.
        uint256 _openClaimCount;
        // Total already paid out for a dividend time. `_segregatedDividend` is deliberately NOT
        // reduced on a payout — it is the pro-rata denominator and must stay fixed for the period —
        // so this is what makes "how much of that deposit is still here" answerable.
        mapping(uint256 time => uint256 paid) _paidDividend;
        // Holders that authorised another address to claim on their behalf. Payouts always go to the
        // holder, never to the operator; the operator only pays the gas and chooses the moment.
        mapping(address controller => mapping(address operator => bool)) _isOperator;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ View functions ============ */
    /**
    * @notice Snapshot source used to read the token holder balances and the total supply
    * @return The contract queried for historical balances and total supply
    */
    function snapshotEngine() public view virtual returns (ISnapshotSource) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._snapshotEngine;
    }

    /**
    * @notice ERC-20 token used to pay the dividends
    * @return The payment token
    */
    function ERC20TokenPayment() public view virtual returns (IERC20) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._ERC20TokenPayment;
    }

    /**
    * @notice Tells whether a token holder already claimed the dividends of a given time
    * @param tokenHolder the address to check
    * @param time the dividend time
    * @return True if the dividends were already claimed or distributed
    */
    function claimedDividend(address tokenHolder, uint256 time) public view virtual returns (bool) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._claimedDividend[tokenHolder][time];
    }

    /**
    * @notice Total amount of payment token deposited for a given dividend time
    * @param time the dividend time
    * @return The amount deposited, minus what was already withdrawn
    */
    function segregatedDividend(uint256 time) public view virtual returns (uint256) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._segregatedDividend[time];
    }

    /**
    * @notice Claim status of a given dividend time
    * @param time the dividend time
    * @return True when the token holders can claim their dividends
    */
    function segregatedClaim(uint256 time) public view virtual returns (bool) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._segregatedClaim[time];
    }

    /**
    * @inheritdoc IERC7540Operator
    */
    function isOperator(address controller, address operator) public view virtual override(IERC7540Operator) returns (bool) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._isOperator[controller][operator];
    }

    /**
    * @notice Total already paid out for a dividend time
    * @param time the dividend time
    * @return The amount of payment token already transferred to holders for `time`
    */
    function paidDividend(uint256 time) public view virtual returns (uint256) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._paidDividend[time];
    }

    /**
    * @notice What is still held for a dividend time — the deposit minus what has been paid out
    * @dev
    * This is the amount an issuer can sweep with {IncomeVaultRestricted-withdraw}, and it is the bound
    * that function enforces. `segregatedDividend` alone is **not** that amount: it is the pro-rata
    * denominator and stays fixed at the deposit even after holders are paid.
    *
    * After the claim window closes it is exactly the rounding dust plus anything unclaimed. Before it
    * closes it still includes what the remaining holders are entitled to, so sweeping early takes
    * money they can no longer be paid — see the note on {IncomeVaultRestricted-withdraw}.
    * @param time the dividend time
    * @return The amount of payment token still attributable to `time`
    */
    function unclaimedDividend(uint256 time) public view virtual returns (uint256) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        uint256 segregated = $._segregatedDividend[time];
        uint256 paid = $._paidDividend[time];
        // Saturating, not a plain subtraction. Withdrawing mid-period lowers the denominator, so a
        // claim made afterwards is priced against the reduced figure and can push `paid` above
        // `segregated`. That state means the period is over-drawn and nothing is left to sweep — a
        // view must report zero, never revert.
        return segregated > paid ? segregated - paid : 0;
    }

    /**
    * @notice How many dividend times currently have their claims open
    * @dev Maintained exactly by {_setStatusClaim}, the only writer of the claim status. Used by
    * {IncomeVaultRestricted-setSnapshotEngine}, which refuses to change the snapshot source while any
    * period is open.
    * @return The number of open claim periods
    */
    function openClaimCount() public view virtual returns (uint256) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._openClaimCount;
    }

    /**
    * @notice Delay, after the dividend time, during which a claim is still accepted
    * @return The delay in seconds
    */
    function timeLimitToWithdraw() public view virtual returns (uint256) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._timeLimitToWithdraw;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State functions ============ */
    /**
    * @notice Records the claim then sends the dividends to the token holder
    * @param time dividend time
    * @param tokenHolder addresses to send the dividends
    * @param tokenHolderDividend the computed dividends
    */
    function _transferDividend(uint256 time, address tokenHolder, uint256 tokenHolderDividend) internal{
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        // Before ERC-20 transfer to avoid re-entrancy attack
        $._claimedDividend[tokenHolder][time] = true;
        emit DividendClaimed(time, tokenHolder, tokenHolderDividend);
        // transfer
        // We don't revert if SenderBalance == 0 to record the claim
        if(tokenHolderDividend != 0){
            // A payout must come out of its own period. Without this a claim made after the period
            // was swept mid-window would silently be funded from another period's deposit, leaving
            // that one unable to pay its holders. Unreachable in normal operation: the entitlements
            // of a period always sum to at most its deposit.
            if(tokenHolderDividend > unclaimedDividend(time)){
                revert IncomeVault_NotEnoughAmount();
            }
            $._paidDividend[time] += tokenHolderDividend;
            // Will revert in case of failure
            $._ERC20TokenPayment.safeTransfer(tokenHolder, tokenHolderDividend);
        }
    }

    /**
    * @notice Sets the snapshot source used to compute the dividends
    * @dev reverts if `snapshotEngine_` is the zero address
    * @param snapshotEngine_ any contract implementing {ISnapshotSource}
    */
    function _setSnapshotEngine(ISnapshotSource snapshotEngine_) internal virtual {
        if(address(snapshotEngine_) == address(0)){
            revert IncomeVault_SnapshotEngineWithAddressZeroNotAllowed();
        }
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        $._snapshotEngine = snapshotEngine_;
        emit SnapshotEngineSet(snapshotEngine_);
    }

    /**
    * @notice Sets the ERC-20 token used to pay the dividends
    * @dev reverts if `ERC20TokenPayment_` is the zero address
    * @param ERC20TokenPayment_ the payment token
    */
    function _setERC20TokenPayment(IERC20 ERC20TokenPayment_) internal virtual {
        if(address(ERC20TokenPayment_) == address(0)){
            revert IncomeVault_TokenPaymentWithAddressZeroNotAllowed();
        }
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        $._ERC20TokenPayment = ERC20TokenPayment_;
        emit ERC20TokenPaymentSet(ERC20TokenPayment_);
    }

    /**
    * @notice Sets the delay, after the dividend time, during which a claim is still accepted
    * @dev reverts if `timeLimitToWithdraw_` is zero — see {IncomeVault_TimeLimitToWithdrawZeroNotAllowed}
    * @param timeLimitToWithdraw_ the delay in seconds, must be greater than zero
    */
    function _setTimeLimitToWithdraw(uint256 timeLimitToWithdraw_) internal virtual {
        // Zero collapses the claim window to the single instant `block.timestamp == time`: one second
        // later {_timeCode} already returns TOO_LATE_TO_WITHDRAW and the period is unclaimable. Any
        // positive value is allowed — a short settlement window may be deliberate; zero never is.
        if(timeLimitToWithdraw_ == 0){
            revert IncomeVault_TimeLimitToWithdrawZeroNotAllowed();
        }
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        $._timeLimitToWithdraw = timeLimitToWithdraw_;
        emit TimeLimitToWithdrawSet(timeLimitToWithdraw_);
    }

    /**
    * @notice Opens or closes the claims for a dividend time
    * @param time the dividend time
    * @param status true when the token holders can claim
    */
    function _setStatusClaim(uint256 time, bool status) internal virtual {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        // Idempotent: a call that does not change the status writes nothing, emits nothing and — the
        // reason this branch exists — leaves `_openClaimCount` exact. Without it, opening an already
        // open period would double-count and the counter could never return to zero.
        if($._segregatedClaim[time] == status){
            return;
        }
        $._segregatedClaim[time] = status;
        if(status){
            ++$._openClaimCount;
        } else {
            --$._openClaimCount;
        }
        emit ClaimStatusSet(time, status);
    }

    /* ============ View functions ============ */
    /**
    * @notice Computes the dividends owed to several token holders for a given time
    * @param time dividend time
    * @param tokenHolders addresses to compute dividend
    * @param tokenHoldersBalance the sender balance
    * @param tokenTotalSupply the total supply
    * @return tokenHolderDividend the dividends owed to each address of `tokenHolders`
    */
    function _computeDividendBatch(uint256 time, address[] calldata tokenHolders, uint256[] memory tokenHoldersBalance, uint256 tokenTotalSupply) internal view returns(uint256[] memory tokenHolderDividend){
        tokenHolderDividend = new uint256[](tokenHolders.length);
        uint256 dividendTotalSupply = segregatedDividend(time);
        for(uint256 i = 0; i < tokenHolders.length; ++i){
            if(tokenHoldersBalance[i] > 0) {
                tokenHolderDividend[i] = (tokenHoldersBalance[i] * dividendTotalSupply) / tokenTotalSupply;
            }
        }
    }

    /**
    * @notice Computes the dividends owed to a single token holder for a given time
    * @param time dividend time
    * @param senderBalance token holder balance
    * @param tokenTotalSupply the total supply
    * @return tokenHolderDividend the dividends owed to the token holder, rounded down
    */
    function _computeDividend(uint256 time, uint256 senderBalance, uint256 tokenTotalSupply) internal view returns(uint256 tokenHolderDividend){
        if (senderBalance == 0){
            revert IncomeVault_NoDividendToClaim();
        }
        /**
        * Example
        * SenderBalance = 300 
        * totalSupply = 900
        * Dividend total supply = 200
        * dividend = (300 * 200) / 900 = 60000 / 900 = 600/9 = 66.6 = 66
        */
        uint256 dividendTotalSupply = segregatedDividend(time);

        tokenHolderDividend = (senderBalance * dividendTotalSupply) / tokenTotalSupply;
    }

    /**
    * @dev reverts with the error matching a non-OK {TIME_ERROR_CODE}. Exhaustive over the enum, and
    * fails closed on an unhandled value — see the comment on the final branch.
    * @param code the code returned by {_timeCode}
    */
    function _revertOnInvalidTime(TIME_ERROR_CODE code) internal view virtual {
        if(code == TIME_ERROR_CODE.OK){
            return;
        } else if(code == TIME_ERROR_CODE.CLAIM_NOT_ACTIVATED){
            revert IncomeVault_ClaimNotActivated();
        } else if(code == TIME_ERROR_CODE.TOO_LATE_TO_WITHDRAW){
            revert IncomeVault_TooLateToWithdraw(block.timestamp);
        } else {
            // TOO_EARLY_TO_WITHDRAW — the only remaining value of an exhaustive enum, so an
            // unconditional `else` rather than a fourth comparison. This also fails **closed**: a
            // value added to TIME_ERROR_CODE without a matching arm reverts here instead of falling
            // through and silently allowing the claim, which is what a trailing `else if` would do.
            revert IncomeVault_TooEarlyToWithdraw(block.timestamp);
        }
    }

    /**
    * @dev {validateTimeCode} with the caller supplying the storage pointer and the withdraw limit,
    * so a batch can read the limit once instead of once per element.
    * @param $ the ERC-7201 storage of the vault
    * @param time the dividend time to check
    * @param timeLimit the value of `timeLimitToWithdraw`
    * @return code the reason the time is invalid, or `TIME_ERROR_CODE.OK`
    */
    function _timeCode(IncomeVaultInternalStorage storage $, uint256 time, uint256 timeLimit)
        internal view virtual returns(TIME_ERROR_CODE code)
    {
        if(!$._segregatedClaim[time]){
            return TIME_ERROR_CODE.CLAIM_NOT_ACTIVATED;
        }
        if(block.timestamp > timeLimit + time){
            return TIME_ERROR_CODE.TOO_LATE_TO_WITHDRAW;
        }
        if(block.timestamp < time){
            return TIME_ERROR_CODE.TOO_EARLY_TO_WITHDRAW;
        }
        return TIME_ERROR_CODE.OK;
    }

    /* ============ ERC-7201 ============ */
    /**
    * @dev Returns the ERC-7201 namespaced storage of the IncomeVault
    * @return $ the storage struct
    */
    function _getIncomeVaultInternalStorage() internal pure returns (IncomeVaultInternalStorage storage $) {
        assembly {
            $.slot := IncomeVaultInternalStorageLocation
        }
    }
}
