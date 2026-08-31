// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/**
 * @title Role identifiers of the role-based IncomeVault deployment
 * @dev
 * These constants are inherited **only** by the deployment that actually enforces them
 * ({IncomeVault}). They are deliberately kept out of {IncomeVaultInvariantStorage}: a variant using
 * another access-control policy — {IncomeVaultOwnable2Step} — would otherwise publish roles it never
 * checks, and granting one would confer no privilege with no on-chain signal that it had no effect.
 */
abstract contract IncomeVaultRolesStorage {
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
}
