// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/**
 * @title What the dividend logic needs from a transfer-restriction policy — and nothing more
 * @dev
 * The payout paths ask one question before moving tokens: *may this payout proceed?* This contract is
 * that question, and only that question. It **inherits nothing**, which is the point: a host embedding
 * the dividend logic — a CMTAT that already has pause, freeze and a RuleEngine — answers from the
 * modules it already owns instead of inheriting a second copy.
 *
 * {IncomeVaultValidationModule} is the answer used by the standalone vault, built on the CMTAT
 * modules. It is one implementation, not the only one.
 *
 * This is the same authorization-hook pattern the project uses for access control, applied to the
 * other dependency that was previously hard-wired. Before the split, {IncomeVaultOpen} and
 * {IncomeVaultRestricted} each inherited the CMTAT `PauseModule` and `EnforcementModule` transitively,
 * so **no CMTAT could ever embed them** — C3 linearization had no solution and the compiler rejected
 * the combination with `Error (5005)`, which no override or ordering can repair.
 */
abstract contract IncomeVaultValidationCore {
    /**
     * @dev Reverts if the vault may not pay `value` to `to`. Implemented by the deployment — or by the
     * host contract, when the dividend logic is embedded in one.
     * @param from the address sending the payment, always the vault itself
     * @param to the token holder receiving the dividends
     * @param value the amount of payment token
     */
    function _validateTransfer(address from, address to, uint256 value) internal view virtual;
}
