// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ERC2771ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

import {ERC2771Module} from "CMTAT/modules/wrapper/options/ERC2771Module.sol";

import {IncomeVaultBase} from "./IncomeVaultBase.sol";

/**
 * @title {IncomeVaultBase} plus gasless support (ERC-2771)
 * @dev
 * Meta-transaction support is a **deployment decision**, in the same way the access-control model and
 * the transfer-restriction policy are. {IncomeVaultBase} states what the vault does and knows nothing
 * about forwarders; this contract adds the ERC-2771 context and resolves the
 * `ERC2771ContextUpgradeable` / `ContextUpgradeable` diamond it creates. Both shipped deployments
 * inherit it, so their behaviour is unchanged.
 *
 * A deployment that does not want a trusted forwarder inherits {IncomeVaultBase} directly. That is the
 * point of the split (finding M-8): previously the forwarder came whether it was wanted or not, and
 * opting out meant passing the zero address while still carrying the code and the calldata suffix
 * handling on every call.
 *
 * @custom:security The forwarder is set in the constructor and is **immutable** — it lives in the
 * implementation's bytecode, not in proxy storage, so it survives an upgrade only if the new
 * implementation is deployed with the same address. A trusted forwarder can name any `_msgSender()`,
 * so it is as privileged as every role behind it.
 */
abstract contract IncomeVaultBaseERC2771 is IncomeVaultBase, ERC2771Module {
    /**
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address forwarderIrrevocable) ERC2771Module(forwarderIrrevocable) {}

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ ERC-2771 / Context disambiguation ============ */
    /**
     * @dev Resolves the {ERC2771ContextUpgradeable} / {ContextUpgradeable} diamond in favour of the
     * ERC-2771 answer, so a forwarded call is attributed to the original sender.
     * @return sender the forwarded sender when the call came through the trusted forwarder
     */
    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /**
     * @dev Resolves the same diamond for the calldata, stripping the appended sender suffix.
     * @return The calldata with the ERC-2771 suffix removed
     */
    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    /**
     * @dev Resolves the same diamond for the length of that suffix.
     * @return The number of trailing calldata bytes carrying the forwarded sender
     */
    function _contextSuffixLength()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }
}
