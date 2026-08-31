// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== OpenZeppelin === */
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

/**
 * @title ERC-165 advertisement of the ERC-173 / Ownable2Step access control
 * @dev
 * Kept in its own module so it is declared once instead of being repeated in every Ownable variant.
 * The two identifiers are hardcoded because `type(I).interfaceId` XORs only the selectors declared
 * directly on the interface, and OpenZeppelin ships no `IERC173` interface to compute them from.
 */
abstract contract Ownable2StepERC165Module is ERC165Upgradeable {
    /**
     * @notice ERC-165 interface ID of ERC-173 (contract ownership standard)
     * @dev bytes4(keccak256("owner()")) ^ bytes4(keccak256("transferOwnership(address)"))
     */
    bytes4 public constant IERC173_INTERFACE_ID = 0x7f5828d0;
    /**
     * @notice ERC-165 interface ID of the Ownable2Step-specific functions
     * @dev bytes4(keccak256("acceptOwnership()")) ^ bytes4(keccak256("pendingOwner()"))
     */
    bytes4 public constant IOWNABLE2STEP_INTERFACE_ID = 0x9ab669ef;

    /**
     * @notice ERC-165 interface detection
     * @param interfaceId The interface identifier to check
     * @return True if the interface is supported, false otherwise
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable) returns (bool) {
        return interfaceId == IERC173_INTERFACE_ID || interfaceId == IOWNABLE2STEP_INTERFACE_ID
            || ERC165Upgradeable.supportsInterface(interfaceId);
    }
}
