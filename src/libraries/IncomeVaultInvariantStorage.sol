// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== Snapshot === */
import {ISnapshotState} from "SnapshotEngine/interface/ISnapshotState.sol";

/**
* @title Roles, errors and events shared by the IncomeVault modules
*/
abstract contract IncomeVaultInvariantStorage {
    /* ============ Role ============ */
    /**
    * @notice Role allowed to open/close the claims and to configure the withdraw time limit
    */
    bytes32 public constant INCOME_VAULT_OPERATOR_ROLE = keccak256("INCOME_VAULT_OPERATOR_ROLE");
    /**
    * @notice Role allowed to deposit the payment token in the vault
    */
    bytes32 public constant INCOME_VAULT_DEPOSIT_ROLE = keccak256("INCOME_VAULT_DEPOSIT_ROLE");
    /**
    * @notice Role allowed to push the dividends to a list of token holders
    */
    bytes32 public constant INCOME_VAULT_DISTRIBUTE_ROLE = keccak256("INCOME_VAULT_DISTRIBUTE_ROLE");
    /**
    * @notice Role allowed to withdraw the payment token from the vault
    */
    bytes32 public constant INCOME_VAULT_WITHDRAW_ROLE = keccak256("INCOME_VAULT_WITHDRAW_ROLE");

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
    * @notice Emitted when the snapshot source used to compute the dividends is set.
    * @param newSnapshotEngine The contract queried for historical balances and total supply.
    */
    event SnapshotEngineSet(ISnapshotState indexed newSnapshotEngine);

    /* ============ Errors ============ */
    error IncomeVault_ClaimNotActivated();
    error IncomeVault_DividendAlreadyClaimed();
    error IncomeVault_NoDividendToClaim();
    error IncomeVault_AdminWithAddressZeroNotAllowed();
    error IncomeVault_TokenPaymentWithAddressZeroNotAllowed();
    error IncomeVault_SnapshotEngineWithAddressZeroNotAllowed();
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
