// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== OpenZeppelin === */
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
/* ==== IncomeVault === */
import {IncomeVaultInternal} from "../libraries/IncomeVaultInternal.sol";
import {IERC7741} from "../interfaces/IERC7741.sol";

/**
* @title ERC-7741 signed operator authorisation
* @dev
* Implements [ERC-7741](https://eips.ethereum.org/EIPS/eip-7741) on top of the operator mapping owned
* by {IncomeVaultInternal}: a holder signs an EIP-712 message and anyone can submit it, so the holder
* never needs gas or even an on-chain transaction to appoint a custodian.
*
* Signatures are checked with OpenZeppelin's `SignatureChecker`, so an **ERC-1271 smart-contract
* wallet** authorises exactly as an EOA does — which matters here, because institutional holders of a
* security token are usually contracts rather than externally owned accounts.
*
* Nonces are `bytes32` and unordered, as the standard specifies, so a holder can prepare several
* independent authorisations without imposing an ordering on them.
*/
abstract contract ERC7741Module is EIP712Upgradeable, ContextUpgradeable, IncomeVaultInternal, IERC7741 {
    /* ============ State Variables ============ */
    /**
    * @notice EIP-712 type hash of the authorisation message, exactly as ERC-7741 defines it
    */
    bytes32 public constant AUTHORIZE_OPERATOR_TYPEHASH =
        keccak256("AuthorizeOperator(address controller,address operator,bool approved,bytes32 nonce,uint256 deadline)");

    /* ============ ERC-7201 ============ */
    /**
    * @dev Slot holding the ERC-7201 namespaced storage of this module, derived as
    * keccak256(abi.encode(uint256(keccak256("IncomeVault.storage.ERC7741Module")) - 1)) & ~bytes32(uint256(0xff))
    * The derivation is re-checked in `test/OperatorAuthorization.t.sol`.
    */
    bytes32 private constant ERC7741ModuleStorageLocation = 0xb93ff011b98f03386917a7b9b9106f5d9f85ba058e0b4e9b3aad1f6474a96800;

    /* ==== ERC-7201 State Variables === */
    /// @custom:storage-location erc7201:IncomeVault.storage.ERC7741Module
    struct ERC7741ModuleStorage {
        // Nonces already spent, per holder. Set both by a successful authorisation and by
        // {invalidateNonce}, so a holder can burn a signature they no longer want honoured.
        mapping(address controller => mapping(bytes32 nonce => bool used)) _authorizations;
    }

    /* ============ Errors ============ */
    /// @notice Thrown when the signature's deadline has passed.
    error IncomeVault_AuthorizationExpired(uint256 deadline);
    /// @notice Thrown when the nonce was already spent or invalidated.
    error IncomeVault_AuthorizationUsed(address controller, bytes32 nonce);
    /// @notice Thrown when the signature does not recover to `controller`.
    error IncomeVault_InvalidAuthorization(address controller);
    /// @notice Thrown when the controller is the zero address.
    error IncomeVault_ControllerWithAddressZeroNotAllowed();

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State functions ============ */
    /// @inheritdoc IERC7741
    function authorizeOperator(
        address controller,
        address operator,
        bool approved,
        bytes32 nonce,
        uint256 deadline,
        bytes memory signature
    ) public virtual override(IERC7741) returns (bool success) {
        if(block.timestamp > deadline){
            revert IncomeVault_AuthorizationExpired(deadline);
        }
        if(controller == address(0)){
            revert IncomeVault_ControllerWithAddressZeroNotAllowed();
        }
        ERC7741ModuleStorage storage $ = _getERC7741ModuleStorage();
        if($._authorizations[controller][nonce]){
            revert IncomeVault_AuthorizationUsed(controller, nonce);
        }
        // Spend the nonce before validating, so no path can replay it.
        $._authorizations[controller][nonce] = true;

        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(AUTHORIZE_OPERATOR_TYPEHASH, controller, operator, approved, nonce, deadline))
        );
        // SignatureChecker accepts both ECDSA and ERC-1271, so contract wallets work unchanged.
        if(!SignatureChecker.isValidSignatureNow(controller, digest, signature)){
            revert IncomeVault_InvalidAuthorization(controller);
        }

        _setOperator(controller, operator, approved);
        return true;
    }

    /// @inheritdoc IERC7741
    function invalidateNonce(bytes32 nonce) public virtual override(IERC7741) {
        ERC7741ModuleStorage storage $ = _getERC7741ModuleStorage();
        $._authorizations[_msgSender()][nonce] = true;
    }

    /* ============ View functions ============ */
    /// @inheritdoc IERC7741
    function authorizations(address controller, bytes32 nonce)
        public view virtual override(IERC7741) returns (bool used)
    {
        ERC7741ModuleStorage storage $ = _getERC7741ModuleStorage();
        return $._authorizations[controller][nonce];
    }

    /// @inheritdoc IERC7741
    function DOMAIN_SEPARATOR() public view virtual override(IERC7741) returns (bytes32) {
        return _domainSeparatorV4();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ ERC-7201 ============ */
    /**
    * @dev Returns the ERC-7201 namespaced storage of this module
    * @return $ the storage struct
    */
    function _getERC7741ModuleStorage() internal pure returns (ERC7741ModuleStorage storage $) {
        assembly {
            $.slot := ERC7741ModuleStorageLocation
        }
    }
}
