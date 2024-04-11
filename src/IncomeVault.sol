// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;


import "CMTAT/modules/wrapper/extensions/MetaTxModule.sol";
import "./public/IncomeVaultRestricted.sol";
import "./public/IncomeVaultOpen.sol";

/**
* @title Income Vault to distribute dividends
*/
contract IncomeVault is Initializable, ContextUpgradeable, IncomeVaultRestricted, IncomeVaultOpen, MetaTxModule{
    
    /**
    * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
    */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address forwarderIrrevocable
    ) MetaTxModule(forwarderIrrevocable) {
        // Disable the possibility to initialize the implementation
        _disableInitializers();
    }

    /**
    * @notice
    * initialize the proxy contract
    * The calls to this function will revert if the contract was deployed without a proxy
    * @param admin Address of the contract (Access Control)
    * @param ERC20TokenPayment_ ERC20 token to perform the payment 
    */
    function initialize(
        address admin,
        IERC20 ERC20TokenPayment_,
        ICMTATSnapshot cmtat_token,
        IRuleEngine ruleEngine_,
        IAuthorizationEngine authorizationEngineIrrevocable
    ) public initializer {
        __IncomeVault_init(
         admin,
         ERC20TokenPayment_,
        cmtat_token,
        ruleEngine_,
        authorizationEngineIrrevocable
        );
    }

    /**
    * @dev calls the different initialize functions from the different modules
    */
    function __IncomeVault_init(
         address admin,
        IERC20 ERC20TokenPayment_,
        ICMTATSnapshot cmtat_token,
        IRuleEngine ruleEngine_,
        IAuthorizationEngine authorizationEngineIrrevocable
    ) internal onlyInitializing {
        if(admin == address(0)){
            revert IncomeVault_AdminWithAddressZeroNotAllowed();
        }
        if(address(ERC20TokenPayment_) == address(0)){     
            revert IncomeVault_TokenPaymentWithAddressZeroNotAllowed(); 
        } 
        if(address(ERC20TokenPayment_) == address(0)){     
            revert IncomeVault_CMTATWithAddressZeroNotAllowed(); 
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(INCOME_VAULT_OPERATOR_ROLE, admin);
        CMTAT_TOKEN = cmtat_token;
        ERC20TokenPayment = ERC20TokenPayment_;

        // Initialization
        __AccessControl_init_unchained();
        __AuthorizationModule_init_unchained(admin, authorizationEngineIrrevocable);
        // PauseModule_init_unchained is called before ValidationModule_init_unchained due to inheritance
        __Pausable_init_unchained();
        __Validation_init_unchained(ruleEngine_);
    }
    
    /** 
    * @dev This surcharge is not necessary if you do not use the MetaTxModule
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
    * @dev This surcharge is not necessary if you do not use the MetaTxModule
    */
    function _msgData()
        internal
        view
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function _contextSuffixLength() internal view 
    override(ERC2771ContextUpgradeable, ContextUpgradeable)
    returns (uint256) {
         return ERC2771ContextUpgradeable._contextSuffixLength();
    }

    // Use in case of inheritance
    uint256[50] private __gap;
}
