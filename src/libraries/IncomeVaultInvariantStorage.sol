// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== Snapshot === */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISnapshotSource} from "../interfaces/ISnapshotSource.sol";

/**
* @title Roles, errors and events shared by the IncomeVault modules
*/
abstract contract IncomeVaultInvariantStorage {
    /* ============ Events ============ */
    /**
    * @notice Emitted when an authorized address deposits dividends for a given time
    * @param time the dividend time the deposit is attached to
    * @param sender the address performing the deposit
    * @param dividend the amount of payment token deposited
    */
    event newDeposit(uint256 indexed time, address indexed sender, uint256 dividend);
    /**
    * @notice Emitted when the dividends of a token holder are claimed or distributed
    * @param time the dividend time
    * @param sender the token holder receiving the dividends
    * @param dividend the amount of payment token transferred
    */
    event DividendClaimed(uint256 indexed time, address indexed sender, uint256 dividend);
    /**
    * @notice Emitted when the ERC-20 used to pay the dividends is set
    * @param newERC20TokenPayment the payment token
    */
    event ERC20TokenPaymentSet(IERC20 indexed newERC20TokenPayment);
    /**
    * @notice Emitted when the claims are opened or closed for a dividend time
    * @param time the dividend time
    * @param status true when the token holders can claim
    */
    event ClaimStatusSet(uint256 indexed time, bool status);
    /**
    * @notice Emitted when the delay during which a claim is accepted is set
    * @param timeLimitToWithdraw the delay in seconds
    */
    event TimeLimitToWithdrawSet(uint256 timeLimitToWithdraw);
    /**
    * @notice Emitted when an authorized address withdraws the funds deposited for a dividend time
    * @param time the dividend time the funds were deposited for
    * @param withdrawAddress the address receiving the funds
    * @param amount the amount of payment token withdrawn
    */
    event Withdraw(uint256 indexed time, address indexed withdrawAddress, uint256 amount);
    /**
    * @notice Emitted when an authorized address withdraws funds without a dividend time
    * @dev the per-time accounting in `segregatedDividend` is left untouched, see {withdrawAll}
    * @param withdrawAddress the address receiving the funds
    * @param amount the amount of payment token withdrawn
    */
    event WithdrawAll(address indexed withdrawAddress, uint256 amount);
    /**
    * @notice Emitted when the snapshot source used to compute the dividends is set.
    * @param newSnapshotEngine The contract queried for historical balances and total supply.
    */
    event SnapshotEngineSet(ISnapshotSource indexed newSnapshotEngine);

    /* ============ Errors ============ */
    error IncomeVault_ClaimNotActivated();
    error IncomeVault_DividendAlreadyClaimed();
    error IncomeVault_NoDividendToClaim();
    error IncomeVault_AdminWithAddressZeroNotAllowed();
    error IncomeVault_TokenPaymentWithAddressZeroNotAllowed();
    error IncomeVault_SnapshotEngineWithAddressZeroNotAllowed();
    /**
    * @notice Thrown when the withdraw time limit is set to zero.
    * @dev A limit of zero collapses the claim window `[time, time + limit]` to the single instant
    * `block.timestamp == time`, making the period effectively unclaimable.
    */
    error IncomeVault_TimeLimitToWithdrawZeroNotAllowed();
    /**
    * @notice Thrown when the snapshot source is changed while at least one claim period is open.
    * @param openClaimCount how many dividend times currently have their claims open
    */
    error IncomeVault_ClaimPeriodOpen(uint256 openClaimCount);
    error IncomeVault_NoAmountSend();
    error IncomeVault_NotEnoughAmount();
    error IncomeVault_TokenBalanceIsZero();
    error IncomeVault_TooLateToWithdraw(uint256 currentTime);
    error IncomeVault_TooEarlyToWithdraw(uint256 currentTime);
    /**
    * @notice Thrown when the ValidationModule (pause, freeze or RuleEngine) forbids the payout.
    */
    error IncomeVault_InvalidTransfer(address from, address to, uint256 value);
    error IncomeVault_SameValue();
}
