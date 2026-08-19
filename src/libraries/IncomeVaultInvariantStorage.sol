// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== Snapshot === */
import {ISnapshotState} from "SnapshotEngine/interface/ISnapshotState.sol";

/**
* @title Roles, errors and events shared by the IncomeVault modules
*/
abstract contract IncomeVaultInvariantStorage {
    /* ============ Role ============ */
    bytes32 public constant INCOME_VAULT_OPERATOR_ROLE = keccak256("INCOME_VAULT_OPERATOR_ROLE");
    bytes32 public constant INCOME_VAULT_DEPOSIT_ROLE = keccak256("INCOME_VAULT_DEPOSIT_ROLE");
    bytes32 public constant INCOME_VAULT_DISTRIBUTE_ROLE = keccak256("INCOME_VAULT_DISTRIBUTE_ROLE");
    bytes32 public constant INCOME_VAULT_WITHDRAW_ROLE = keccak256("INCOME_VAULT_WITHDRAW_ROLE");

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

    /* ============ Events ============ */
    event newDeposit(uint256 indexed time, address indexed sender, uint256 dividend);
    event DividendClaimed(uint256 indexed time, address indexed sender, uint256 dividend);
    /**
    * @notice Emitted when the snapshot source used to compute the dividends is set.
    * @param newSnapshotEngine The contract queried for historical balances and total supply.
    */
    event SnapshotEngineSet(ISnapshotState indexed newSnapshotEngine);
}
