// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

abstract contract DebtVaultInvariantStorage {
    // Role
    bytes32 public constant DEBT_VAULT_OPERATOR_ROLE = keccak256("DEBT_VAULT_OPERATOR_ROLE");
    bytes32 public constant DEBT_VAULT_DEPOSIT_ROLE = keccak256("DEBT_VAULT_DEPOSIT_ROLE");
    bytes32 public constant DEBT_VAULT_DISTRIBUTE_ROLE = keccak256("DEBT_VAULT_DEPOSIT_ROLE");
    bytes32 public constant DEBT_VAULT_WITHDRAW_ROLE = keccak256("DEBT_VAULT_WITHDRAW_ROLE");

    // errors
    error claimNotActivated();
    error dividendAlreadyClaimed();
    error noDividendToClaim();
    error AdminWithAddressZeroNotAllowed();
    error TokenPaymentWithAddressZeroNotAllowed();
    error noAmountSend();
    error notEnoughAmount();

    // event
    event newDeposit(uint256 indexed time, address indexed sender, uint256 dividend);
    event DividendClaimed(uint256 indexed time, address indexed sender, uint256 dividend);
}  