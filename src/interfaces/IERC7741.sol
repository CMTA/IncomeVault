// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/**
 * @title IERC7741
 * @notice [ERC-7741](https://eips.ethereum.org/EIPS/eip-7741) — signed operator authorisation.
 * @dev
 * Lets a holder grant or revoke an operator with an EIP-712 signature instead of a transaction, so a
 * custodian or relayer can submit the authorisation and pay the gas. It complements
 * {IERC7540Operator}, whose `setOperator` requires the holder to transact.
 *
 * The standard assigns this interface the ERC-165 identifier **`0xa9e50872`**. It inherits nothing,
 * so `type(IERC7741).interfaceId` is the XOR of the four selectors below and equals that value. Adding
 * or changing a selector here changes the id, and the vault would then advertise one the standard does
 * not define.
 *
 * @custom:security ERC-7741 warns that "operators have significant control over users and the signed
 * message can lead to undesired outcomes". Keep `deadline` as short as practical: a signature that
 * leaks later is still usable until it expires or its nonce is spent through {invalidateNonce}.
 */
interface IERC7741 {
    /**
     * @notice Grants or revokes permissions for `operator`, authorised by an EIP-712 signature.
     * @dev MUST revert if `deadline` has passed, if the nonce was already used, or if the signature
     * is invalid. MUST invalidate the nonce, MUST log `OperatorSet` and MUST return true.
     * @param controller the holder whose signature authorises the change
     * @param operator the account being granted or revoked
     * @param approved true to grant, false to revoke
     * @param nonce an unordered, single-use value chosen by the signer
     * @param deadline the timestamp after which the signature is no longer valid
     * @param signature the EIP-712 signature, ECDSA or ERC-1271
     * @return success MUST be true
     */
    function authorizeOperator(
        address controller,
        address operator,
        bool approved,
        bytes32 nonce,
        uint256 deadline,
        bytes memory signature
    ) external returns (bool success);

    /**
     * @notice Revokes the given `nonce` for `msg.sender`, so a signature using it can never be used.
     * @param nonce the nonce to burn
     */
    function invalidateNonce(bytes32 nonce) external;

    /**
     * @notice Returns whether the given `nonce` has been used for the `controller`.
     * @param controller the holder the nonce belongs to
     * @param nonce the nonce to check
     * @return used true when the nonce has been spent or invalidated
     */
    function authorizations(address controller, bytes32 nonce) external view returns (bool used);

    /**
     * @notice The EIP-712 domain separator of this contract.
     * @return The domain separator, unique to this contract and chain
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
