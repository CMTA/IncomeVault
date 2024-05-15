// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

abstract contract IncomeVaultInvariantStorage {
    // Role
    bytes32 public constant INCOME_VAULT_OPERATOR_ROLE = keccak256("INCOME_VAULT_OPERATOR_ROLE");
    bytes32 public constant INCOME_VAULT_DEPOSIT_ROLE = keccak256("INCOME_VAULT_DEPOSIT_ROLE");
    bytes32 public constant INCOME_VAULT_DISTRIBUTE_ROLE = keccak256("INCOME_VAULT_DEPOSIT_ROLE");
    bytes32 public constant INCOME_VAULT_WITHDRAW_ROLE = keccak256("INCOME_VAULT_WITHDRAW_ROLE");

    // errors
    error IncomeVault_ClaimNotActivated();
    error IncomeVault_DividendAlreadyClaimed();
    error IncomeVault_NoDividendToClaim();
    error IncomeVault_AdminWithAddressZeroNotAllowed();
    error IncomeVault_TokenPaymentWithAddressZeroNotAllowed();
    error IncomeVault_CMTATWithAddressZeroNotAllowed();
    error IncomeVault_FailApproval();
    error IncomeVault_NoAmountSend();
    error IncomeVault_NotEnoughAmount();
    error IncomeVault_TokenBalanceIsZero();
    error IncomeVault_TooLateToWithdraw(uint256 currentTime);
    error IncomeVault_TooEarlyToWithdraw(uint256 currentTime);

    // event
    event newDeposit(uint256 indexed time, address indexed sender, uint256 dividend);
    event DividendClaimed(uint256 indexed time, address indexed sender, uint256 dividend);
}  