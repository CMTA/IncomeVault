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
import {ISnapshotState} from "SnapshotEngine/interface/ISnapshotState.sol";
/* ==== IncomeVault === */
import {IncomeVaultRestricted} from "./public/IncomeVaultRestricted.sol";
import {IncomeVaultOpen} from "./public/IncomeVaultOpen.sol";

/**
* @title Income Vault to distribute dividends
* @dev
* The vault is not bound to a specific token implementation: the holder balances and the total
* supply are read through the {ISnapshotState} interface, which is implemented by the CMTA
* `SnapshotEngine` as well as by any token embedding an equivalent snapshot module.
*/
contract IncomeVault is Initializable, ContextUpgradeable, IncomeVaultRestricted, IncomeVaultOpen, ERC2771Module {
    
    /**
    * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
    */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address forwarderIrrevocable
    ) ERC2771Module(forwarderIrrevocable) {
        // Disable the possibility to initialize the implementation
        _disableInitializers();
    }

    /**
    * @notice
    * initialize the proxy contract
    * The calls to this function will revert if the contract was deployed without a proxy
    * @param admin Address of the contract (Access Control)
    * @param ERC20TokenPayment_ ERC20 token used to perform the payment
    * @param snapshotEngine_ contract implementing {ISnapshotState}, source of the holder balances
    * @param ruleEngine_ optional RuleEngine applied to the payouts, or the zero address
    * @param timeLimitToWithdraw_ delay, after the dividend time, during which a claim is accepted
    */
    function initialize(
        address admin,
        IERC20 ERC20TokenPayment_,
        ISnapshotState snapshotEngine_,
        IRuleEngine ruleEngine_,
        uint256 timeLimitToWithdraw_
    ) public initializer {
        __IncomeVault_init(
            admin,
            ERC20TokenPayment_,
            snapshotEngine_,
            ruleEngine_,
            timeLimitToWithdraw_
        );
    }

    /**
    * @dev calls the different initialize functions from the different modules
    * @param admin Address of the contract (Access Control)
    * @param ERC20TokenPayment_ ERC20 token used to perform the payment
    * @param snapshotEngine_ contract implementing {ISnapshotState}, source of the holder balances
    * @param ruleEngine_ optional RuleEngine applied to the payouts, or the zero address
    * @param timeLimitToWithdraw_ delay, after the dividend time, during which a claim is accepted
    */
    function __IncomeVault_init(
        address admin,
        IERC20 ERC20TokenPayment_,
        ISnapshotState snapshotEngine_,
        IRuleEngine ruleEngine_,
        uint256 timeLimitToWithdraw_
    ) internal onlyInitializing {
        if(admin == address(0)){
            revert IncomeVault_AdminWithAddressZeroNotAllowed();
        }
        if(address(ERC20TokenPayment_) == address(0)){     
            revert IncomeVault_TokenPaymentWithAddressZeroNotAllowed(); 
        }
        ERC20TokenPayment = ERC20TokenPayment_;
        _setSnapshotEngine(snapshotEngine_);

        // Initialization
        __AccessControl_init_unchained();
        __AccessControlModule_init_unchained(admin);
        __Pausable_init_unchained();
        __IncomeVaultValidation_init_unchained(ruleEngine_);
        __IncomeVaultRestricted_init_unchained(timeLimitToWithdraw_);
    }
    
    /** 
    * @dev This surcharge is not necessary if you do not use the ERC2771Module
    * @return sender The transaction sender, unwrapped from the forwarder calldata when relayed.
    */
    function _msgSender()
        internal
        view
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
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    /**
    * @dev This surcharge is not necessary if you do not use the ERC2771Module
    * @return The length of the ERC-2771 calldata suffix.
    */
    function _contextSuffixLength() internal view 
    override(ERC2771ContextUpgradeable, ContextUpgradeable)
    returns (uint256) {
         return ERC2771ContextUpgradeable._contextSuffixLength();
    }

    /**
    * @notice Storage gap reserved for future versions of this contract
    * @dev Use in case of inheritance
    */
    uint256[50] private __gap;
}
