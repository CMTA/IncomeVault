// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/**
 * @title IERC7540Operator
 * @notice The operator subset of [ERC-7540](https://eips.ethereum.org/EIPS/eip-7540), verbatim.
 * @dev
 * ERC-7540 defines asynchronous ERC-4626 vaults. The {IncomeVault} is **not** one — a 4626 share
 * entitles whoever holds it now, while a dividend is allocated by record date — but its claim
 * delegation is exactly the operator mechanism that standard specifies, so the signatures are reused
 * rather than invented. A custodian or wallet already written against ERC-7540 operators works here unchanged.
 *
 * ERC-7540 assigns this subset the ERC-165 identifier **`0xe3bc4e65`**, described there as
 * "the operator methods that all ERC-7540 Vaults implement". Because this interface inherits nothing,
 * `type(IERC7540Operator).interfaceId` is exactly the XOR of the two selectors below and equals that
 * value. That equality is what pins these signatures to the standard: change either one and the id no
 * longer matches what ERC-7540 assigns.
 *
 * @custom:security The vault does **not** answer `true` for `0xe3bc4e65` from `supportsInterface`.
 * Sharing the operator methods does not make it an asynchronous vault, and a caller discovering that
 * id would reasonably expect the rest of ERC-7540 — the request lifecycle, ERC-7575's `share()` — none
 * of which exists here. Deliberate under-claiming.
 */
interface IERC7540Operator {
    /**
     * @notice The `controller` has set the `approved` status to an `operator`.
     * @dev MUST be logged when the operator status is set.
     * @param controller the account granting or revoking
     * @param operator the account being granted or revoked
     * @param approved the status that was set
     */
    event OperatorSet(address indexed controller, address indexed operator, bool approved);

    /**
     * @notice Grants or revokes permissions for `operator` to manage Requests on behalf of the `msg.sender`.
     * @dev MUST set the operator status to the `approved` value, MUST log the {OperatorSet} event and
     * MUST return true.
     * @param operator the account to grant or revoke
     * @param approved true to grant, false to revoke
     * @return success MUST be true
     */
    function setOperator(address operator, bool approved) external returns (bool success);

    /**
     * @notice Returns `true` if the `operator` is approved as an operator for a `controller`.
     * @param controller the account that may have granted
     * @param operator the account that may have been granted
     * @return status true when `operator` is approved for `controller`
     */
    function isOperator(address controller, address operator) external view returns (bool status);
}
