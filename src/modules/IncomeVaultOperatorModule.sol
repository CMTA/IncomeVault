// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {IERC7540Operator} from "../interfaces/IERC7540Operator.sol";
import {IncomeVaultInvariantStorage} from "../storage/IncomeVaultInvariantStorage.sol";

/**
* @title Claim delegation — one capability, one namespace
* @dev
* A holder may authorise another address to claim on their behalf. Payouts always go to the **holder**;
* the operator only pays the gas and chooses the moment.
*
* The signatures and the `OperatorSet` event are ERC-7540's, verbatim, so tooling written for that
* standard works unchanged. The vault is **not** an asynchronous vault and does not advertise
* {IERC7540Operator} through `supportsInterface`.
*
* This module owns the authorisation mapping in its own ERC-7201 namespace rather than in the
* distribution namespace, so the two capabilities can be reasoned about — and one day inherited —
* separately. {ERC7741Module} adds the signed variant on top and keeps a third namespace of its own for
* the consumed nonces.
*/
abstract contract IncomeVaultOperatorModule is ContextUpgradeable, IncomeVaultInvariantStorage, IERC7540Operator {
    /* ============ ERC-7201 ============ */
    /**
    * @dev Slot holding the ERC-7201 namespaced storage of this module, derived as
    * keccak256(abi.encode(uint256(keccak256("IncomeVault.storage.Operator")) - 1)) & ~bytes32(uint256(0xff))
    * The derivation is re-checked in `test/IncomeVaultStorage.t.sol`.
    */
    bytes32 private constant OperatorStorageLocation =
        0x70af7571496f61583375b861df45fee91dcc3edadeaff09b686f7920599a5500;

    /// @custom:storage-location erc7201:IncomeVault.storage.Operator
    struct OperatorStorage {
        // Holders that authorised another address to claim on their behalf
        mapping(address controller => mapping(address operator => bool)) _isOperator;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State functions ============ */
    /**
    * @inheritdoc IERC7540Operator
    * @dev Permissionless on purpose: a holder authorises their own operator, so there is no role to
    * check. The authorisation only lets the operator trigger a claim; the payout still goes to the
    * holder. {ERC7741Module-authorizeOperator} is the signed equivalent for a holder who cannot send
    * the transaction themselves.
    */
    function setOperator(address operator, bool approved) public virtual override(IERC7540Operator) returns (bool) {
        _setOperator(_msgSender(), operator, approved);
        return true;
    }

    /* ============ View functions ============ */
    /**
    * @inheritdoc IERC7540Operator
    */
    function isOperator(address controller, address operator)
        public
        view
        virtual
        override(IERC7540Operator)
        returns (bool)
    {
        OperatorStorage storage $ = _getOperatorStorage();
        return $._isOperator[controller][operator];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State functions ============ */
    /**
    * @dev Records an authorisation and emits the ERC-7540 event. The only writer of the mapping.
    * @param controller the holder granting or revoking the authorisation
    * @param operator the address being authorised
    * @param approved true to authorise, false to revoke
    */
    function _setOperator(address controller, address operator, bool approved) internal virtual {
        OperatorStorage storage $ = _getOperatorStorage();
        $._isOperator[controller][operator] = approved;
        emit OperatorSet(controller, operator, approved);
    }

    /* ============ View functions ============ */
    /**
    * @dev Reverts unless the caller is `holder` or an operator `holder` authorised
    * @param holder the token holder being claimed for
    */
    function _requireHolderOrOperator(address holder) internal view virtual {
        address caller = _msgSender();
        if (caller != holder && !isOperator(holder, caller)) {
            revert IncomeVault_UnauthorizedOperator(holder, caller);
        }
    }

    /* ============ ERC-7201 ============ */
    /**
    * @dev Returns the ERC-7201 namespaced storage of this module
    * @return $ the storage struct
    */
    function _getOperatorStorage() internal pure returns (OperatorStorage storage $) {
        assembly {
            $.slot := OperatorStorageLocation
        }
    }
}
