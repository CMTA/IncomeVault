// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
* @title The dividend-distribution API, stated rather than inferred
* @dev
* Everything an integrator calls on a vault — or on a token that embeds the distribution logic — with
* no dependency on which of the two it is. Importing this instead of a concrete contract avoids pulling
* in CMTAT, the RuleEngine and the whole implementation graph.
*
* Scope, and what is deliberately outside it:
*
* - **Operator delegation is not redeclared here.** `setOperator`/`isOperator` belong to
*   {IERC7540Operator} and the signed variant to {IERC7741}; both are implemented alongside this
*   interface. Restating them would fork a standardised name.
* - **`transferDividendSelf` is absent.** It is `public` only because `try`/`catch` needs an external
*   call, and it rejects every caller but the contract itself. It is not part of anyone's API.
* - **Access control is absent.** Who may call {deposit} or {withdraw} is chosen by the deployment
*   contract, not by this interface. See the capability table in `doc/README.md`.
*
* This interface is inherited by {IncomeVaultInternal}, the common base of both payout paths, so the
* compiler — not a convention — keeps it in step with the implementation.
*/
interface IIncomeVault {
    /* ============ Type declarations ============ */
    /**
    * @notice Why a dividend time is not claimable, or `OK`
    * @dev Declared here rather than in the implementation because it is part of the stated API:
    * {validateTimeCode} returns it. Both the holder-driven claims ({IncomeVaultOpen}) and the
    * issuer-driven distribution ({IncomeVaultRestricted}) apply the same window through it.
    */
    enum TIME_ERROR_CODE {
        OK,
        CLAIM_NOT_ACTIVATED,
        TOO_LATE_TO_WITHDRAW,
        TOO_EARLY_TO_WITHDRAW
    }

    /* ============ Claiming — permissionless ============ */
    /**
    * @notice Claim the caller's dividends for one distribution date
    * @param time the dividend time identifying the distribution
    */
    function claimDividend(uint256 time) external;

    /**
    * @notice Claim `holder`'s dividends for one distribution date, as the holder or their operator
    * @param holder the token holder the dividends are paid to
    * @param time the dividend time identifying the distribution
    */
    function claimDividendFor(address holder, uint256 time) external;

    /**
    * @notice Claim the caller's dividends for several distribution dates
    * @param times the dividend times to claim
    */
    function claimDividendBatch(uint256[] calldata times) external;

    /**
    * @notice Claim `holder`'s dividends for several dates, as the holder or their operator
    * @param holder the token holder the dividends are paid to
    * @param times the dividend times to claim
    */
    function claimDividendBatchFor(address holder, uint256[] calldata times) external;

    /* ============ Funding — role gated ============ */
    /**
    * @notice Deposit the payment token for one distribution date
    * @param time the dividend time the deposit is segregated under
    * @param amount the amount of payment token to deposit
    */
    function deposit(uint256 time, uint256 amount) external;

    /**
    * @notice Deposit the payment token for several distribution dates in one call
    * @param times the dividend times to deposit for
    * @param amounts the amount to deposit for each time, index for index
    */
    function depositBatch(uint256[] calldata times, uint256[] calldata amounts) external;

    /**
    * @notice Recover unclaimed payment token from one distribution date
    * @param time the dividend time to withdraw from
    * @param amount the amount of payment token to withdraw
    * @param withdrawAddress the recipient of the withdrawn funds
    */
    function withdraw(uint256 time, uint256 amount, address withdrawAddress) external;

    /**
    * @notice Recover payment token held by the contract without naming a distribution date
    * @param amount the amount of payment token to withdraw
    * @param withdrawAddress the recipient of the withdrawn funds
    */
    function withdrawAll(uint256 amount, address withdrawAddress) external;

    /* ============ Pushing payouts — role gated ============ */
    /**
    * @notice Pay several holders their dividends for one date, reverting if any payout is refused
    * @param addresses the token holders to pay
    * @param time the dividend time identifying the distribution
    */
    function distributeDividend(address[] calldata addresses, uint256 time) external;

    /**
    * @notice Pay several holders for one date, skipping the refused payouts instead of reverting
    * @param addresses the token holders to pay
    * @param time the dividend time identifying the distribution
    * @return paidCount how many holders were actually paid
    * @return skipped the holders whose payout was refused
    */
    function distributeDividendBestEffort(address[] calldata addresses, uint256 time)
        external
        returns (uint256 paidCount, address[] memory skipped);

    /* ============ Claim administration — role gated ============ */
    /**
    * @notice Open or close claiming for one distribution date
    * @param time the dividend time
    * @param status true to let holders claim, false to close the period
    */
    function setStatusClaim(uint256 time, bool status) external;

    /**
    * @notice Set how long after a dividend time a claim is still accepted
    * @param timeLimitToWithdraw_ the length of the claim window, in seconds
    */
    function setTimeLimitToWithdraw(uint256 timeLimitToWithdraw_) external;

    /* ============ Claim window ============ */
    /**
    * @notice Reverts unless a claim for `time` would be accepted right now
    * @param time the dividend time to check
    */
    function validateTime(uint256 time) external view;

    /**
    * @notice Reverts unless a claim for every one of `times` would be accepted right now
    * @param times the dividend times to check
    */
    function validateTimeBatch(uint256[] calldata times) external view;

    /**
    * @notice Why a claim for `time` would be refused, without reverting
    * @param time the dividend time to check
    * @return code the reason, or the no-error member when the claim would be accepted
    */
    function validateTimeCode(uint256 time) external view returns (TIME_ERROR_CODE code);

    /* ============ State ============ */
    /**
    * @notice The ERC-20 the dividends are paid in
    * @return The payment token
    */
    function ERC20TokenPayment() external view returns (IERC20);

    /**
    * @notice Whether a holder has already claimed a given distribution
    * @param tokenHolder the holder to look up
    * @param time the dividend time
    * @return True once the holder has been paid for `time`
    */
    function claimedDividend(address tokenHolder, uint256 time) external view returns (bool);

    /**
    * @notice The total deposited for a distribution date. This is the pro-rata denominator and is
    * never reduced by a payout — see {unclaimedDividend} for what the period still holds.
    * @param time the dividend time
    * @return The amount deposited for `time`
    */
    function segregatedDividend(uint256 time) external view returns (uint256);

    /**
    * @notice Whether claiming is open for a distribution date
    * @param time the dividend time
    * @return True when holders may claim for `time`
    */
    function segregatedClaim(uint256 time) external view returns (bool);

    /**
    * @notice How much of a date's deposit has already been paid out
    * @param time the dividend time
    * @return The amount already paid for `time`
    */
    function paidDividend(uint256 time) external view returns (uint256);

    /**
    * @notice How much of a date's deposit the contract still holds
    * @param time the dividend time
    * @return `segregatedDividend(time) - paidDividend(time)`, saturating at zero
    */
    function unclaimedDividend(uint256 time) external view returns (uint256);

    /**
    * @notice How many distribution dates currently have claiming open
    * @return The number of open claim periods
    */
    function openClaimCount() external view returns (uint256);

    /**
    * @notice How long after a dividend time a claim is still accepted
    * @return The claim window length, in seconds
    */
    function timeLimitToWithdraw() external view returns (uint256);
}
