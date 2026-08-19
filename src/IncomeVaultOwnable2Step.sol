// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== OpenZeppelin === */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
/* ==== CMTAT === */
import {PauseModule} from "CMTAT/modules/wrapper/core/PauseModule.sol";
import {EnforcementModule} from "CMTAT/modules/wrapper/core/EnforcementModule.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
/* ==== Snapshot === */
import {ISnapshotState} from "SnapshotEngine/interface/ISnapshotState.sol";
/* ==== IncomeVault === */
import {IncomeVaultBase} from "./IncomeVaultBase.sol";
import {IncomeVaultRestricted} from "./public/IncomeVaultRestricted.sol";
import {IncomeVaultValidationModule} from "./modules/IncomeVaultValidationModule.sol";
import {Ownable2StepERC165Module} from "./libraries/Ownable2StepERC165Module.sol";

/**
* @title Income Vault to distribute dividends — single-owner deployment
* @dev
* Answers **who** may do what with a single ERC-173 owner: every authorization hook collapses to
* `onlyOwner`. `Ownable2Step` is used rather than `Ownable` so a mistyped address cannot lose the
* contract — the handover only completes when the new owner calls `acceptOwnership`.
*
* @custom:security This variant **cannot express separated duties**. The owner deposits, withdraws,
* distributes, runs the claim window, pauses, freezes and repoints the RuleEngine. In particular the
* account that funds the vault is the same account that can empty it through `withdrawAll`. Choose
* {IncomeVault}, the role-based deployment, whenever depositing and withdrawing must be held by
* different accounts — which is the usual requirement for an issuer paying dividends.
*/
contract IncomeVaultOwnable2Step is IncomeVaultBase, Ownable2StepUpgradeable, Ownable2StepERC165Module {

    /**
    * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
    */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address forwarderIrrevocable
    ) IncomeVaultBase(forwarderIrrevocable) {
        // Disable the possibility to initialize the implementation
        _disableInitializers();
    }

    /**
    * @notice
    * initialize the proxy contract
    * The calls to this function will revert if the contract was deployed without a proxy
    * @param owner_ Address of the initial contract owner (ERC-173)
    * @param ERC20TokenPayment_ ERC20 token used to perform the payment
    * @param snapshotEngine_ contract implementing {ISnapshotState}, source of the holder balances
    * @param ruleEngine_ optional RuleEngine applied to the payouts, or the zero address
    * @param timeLimitToWithdraw_ delay, after the dividend time, during which a claim is accepted
    */
    function initialize(
        address owner_,
        IERC20 ERC20TokenPayment_,
        ISnapshotState snapshotEngine_,
        IRuleEngine ruleEngine_,
        uint256 timeLimitToWithdraw_
    ) public initializer {
        if(owner_ == address(0)){
            revert IncomeVault_AdminWithAddressZeroNotAllowed();
        }
        __Ownable_init_unchained(owner_);
        __Ownable2Step_init_unchained();
        __ERC165_init_unchained();
        __IncomeVaultBase_init_unchained(
            ERC20TokenPayment_,
            snapshotEngine_,
            ruleEngine_,
            timeLimitToWithdraw_
        );
    }

    /* ============ ERC-165 ============ */
    /**
    * @inheritdoc Ownable2StepERC165Module
    */
    function supportsInterface(bytes4 interfaceId)
        public view virtual override(Ownable2StepERC165Module) returns (bool)
    {
        return Ownable2StepERC165Module.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ ERC-2771 / Context disambiguation ============ */
    /**
    * @inheritdoc IncomeVaultBase
    */
    function _msgSender()
        internal view virtual override(IncomeVaultBase, ContextUpgradeable) returns (address sender)
    {
        return IncomeVaultBase._msgSender();
    }

    /**
    * @inheritdoc IncomeVaultBase
    */
    function _msgData()
        internal view virtual override(IncomeVaultBase, ContextUpgradeable) returns (bytes calldata)
    {
        return IncomeVaultBase._msgData();
    }

    /**
    * @inheritdoc IncomeVaultBase
    */
    function _contextSuffixLength()
        internal view virtual override(IncomeVaultBase, ContextUpgradeable) returns (uint256)
    {
        return IncomeVaultBase._contextSuffixLength();
    }

    /* ============ Access Control ============ */
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeDeposit() internal view virtual override onlyOwner {}

    /// @inheritdoc IncomeVaultRestricted
    function _authorizeWithdraw() internal view virtual override onlyOwner {}

    /// @inheritdoc IncomeVaultRestricted
    function _authorizeDistribute() internal view virtual override onlyOwner {}

    /// @inheritdoc IncomeVaultRestricted
    function _authorizeOperator() internal view virtual override onlyOwner {}

    /// @inheritdoc IncomeVaultValidationModule
    function _authorizeRuleEngineManagement() internal view virtual override onlyOwner {}

    /// @inheritdoc PauseModule
    function _authorizePause() internal view virtual override(PauseModule) onlyOwner {}

    /// @inheritdoc PauseModule
    function _authorizeDeactivate() internal view virtual override(PauseModule) onlyOwner {}

    /// @inheritdoc EnforcementModule
    function _authorizeFreeze() internal view virtual override(EnforcementModule) onlyOwner {}
}
