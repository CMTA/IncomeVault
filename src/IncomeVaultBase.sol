// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== OpenZeppelin === */
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ERC2771ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/* ==== CMTAT === */
import {ERC2771Module} from "CMTAT/modules/wrapper/options/ERC2771Module.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
/* ==== Snapshot === */
import {ISnapshotSource} from "./interfaces/ISnapshotSource.sol";
/* ==== IncomeVault === */
import {IncomeVaultRestricted} from "./public/IncomeVaultRestricted.sol";
import {IncomeVaultOpen} from "./public/IncomeVaultOpen.sol";
import {VersionModule} from "./modules/VersionModule.sol";

/**
* @title Income Vault to distribute dividends — logic shared by every deployment variant
* @dev
* The vault is not bound to a specific token implementation: the holder balances and the total
* supply are read through the {ISnapshotSource} interface, which is implemented by the CMTA
* `SnapshotEngine` as well as by any token embedding an equivalent snapshot module.
*
* This contract holds **what** is protected. It deliberately declares no access-control policy: the
* eight `_authorize*` hooks are left abstract and answered by the deployment contract, so the same
* logic can ship role-based ({IncomeVault}) or single-owner ({IncomeVaultOwnable2Step}).
*/
abstract contract IncomeVaultBase is Initializable, ContextUpgradeable, VersionModule, IncomeVaultRestricted, IncomeVaultOpen, ERC2771Module {

    /**
    * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
    */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address forwarderIrrevocable
    ) ERC2771Module(forwarderIrrevocable) {}

    /* ============  Initializer Function ============ */
    /**
    * @dev calls the initialize functions of the policy-agnostic modules
    * @param ERC20TokenPayment_ ERC20 token used to perform the payment
    * @param snapshotEngine_ contract implementing {ISnapshotSource}, source of the holder balances
    * @param ruleEngine_ optional RuleEngine applied to the payouts, or the zero address
    * @param timeLimitToWithdraw_ delay, after the dividend time, during which a claim is accepted
    */
    function __IncomeVaultBase_init_unchained(
        IERC20 ERC20TokenPayment_,
        ISnapshotSource snapshotEngine_,
        IRuleEngine ruleEngine_,
        uint256 timeLimitToWithdraw_
    ) internal onlyInitializing {
        _setERC20TokenPayment(ERC20TokenPayment_);
        _setSnapshotEngine(snapshotEngine_);

        __Pausable_init_unchained();
        __IncomeVaultValidation_init_unchained(ruleEngine_);
        __IncomeVaultRestricted_init_unchained(timeLimitToWithdraw_);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /** 
    * @dev This surcharge is not necessary if you do not use the ERC2771Module
    * @return sender The transaction sender, unwrapped from the forwarder calldata when relayed.
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
    * @dev This surcharge is not necessary if you do not use the ERC2771Module
    * @return The transaction calldata, with the appended sender stripped when relayed.
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
    * @dev This surcharge is not necessary if you do not use the ERC2771Module
    * @return The length of the ERC-2771 calldata suffix.
    */
    function _contextSuffixLength() internal view virtual
    override(ERC2771ContextUpgradeable, ContextUpgradeable)
    returns (uint256) {
         return ERC2771ContextUpgradeable._contextSuffixLength();
    }
}
