// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

import "OZ/token/ERC20/IERC20.sol";
import "OZ/token/ERC20/utils/SafeERC20.sol"; 
import "OZ/utils/ReentrancyGuard.sol";
import "CMTAT/interfaces/ICMTATSnapshot.sol";
import "CMTAT/modules/wrapper/controllers/ValidationModule.sol";
import "CMTAT/modules/wrapper/extensions/MetaTxModule.sol";
import "./invariantStorage/DebtVaultInvariantStorage.sol";


/**
* @title Debt Vault to distribute dividend
*/// AuthorizationModuleStandalone
contract DebtVault is MetaTxModule, ReentrancyGuard, DebtVaultInvariantStorage, ValidationModule {
    // CMTAT token
    ICMTATSnapshot  CMTAT_TOKEN;
    //IRuleEngine ruleEngine;

    uint128 internal constant POINTS_MULTIPLIER = type(uint64).max;
    IERC20 public ERC20TokenPayment;
    mapping(address => mapping (uint256 => bool)) public claimedDividend;
    mapping(uint256 => uint256) public segragatedDividend;
    mapping(uint256 => bool) public segragatedClaim;

    // Security
    using SafeERC20 for IERC20;
    
    /**
    * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
    */
    constructor(
        address forwarderIrrevocable
    ) MetaTxModule(forwarderIrrevocable) {

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
        __DebtVault_init(
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
    function __DebtVault_init(
         address admin,
        IERC20 ERC20TokenPayment_,
        ICMTATSnapshot cmtat_token,
        IRuleEngine ruleEngine_,
        IAuthorizationEngine authorizationEngineIrrevocable
    ) internal onlyInitializing {
        if(admin == address(0)){
            revert AdminWithAddressZeroNotAllowed();
        }

        if(address(ERC20TokenPayment_) == address(0)){     
            revert TokenPaymentWithAddressZeroNotAllowed(); 
        }  
        __Validation_init_unchained(ruleEngine_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEBT_VAULT_OPERATOR_ROLE, admin);
        CMTAT_TOKEN = cmtat_token;
        ERC20TokenPayment = ERC20TokenPayment_;

        // Initialization
        __AccessControl_init_unchained();
        __Pausable_init_unchained();
        __Validation_init_unchained(ruleEngine_);
        
        __AuthorizationModule_init_unchained(admin, authorizationEngineIrrevocable);
        // PauseModule_init_unchained is called before ValidationModule_init_unchained due to inheritance
        __PauseModule_init_unchained();
        __ValidationModule_init_unchained();
    }

    /**
    * @notice claim your payment
    * @param time provide the date where you want to receive your payment
    */
    function claimDividend(uint256 time) public nonReentrant() {
        // Check if the claim is activated
        if(!segragatedClaim[time]){
             revert claimNotActivated();
        }
        address sender = _msgSender();
        // At the beginning since no external call to do
        if (claimedDividend[sender][time]){
            revert dividendAlreadyClaimed();
        }
        // External call to the CMTAT to retrieve the total supply and the sender balance
        (uint256 senderBalance, uint256 TokenTotalSupply) = CMTAT_TOKEN.snapshotInfo(time, sender);
        if (senderBalance == 0){
            revert noDividendToClaim();
        }
        /**
        SenderBalance = 300 
        totalSupply = 900
        Dividend total supply= 200
        If POINTS_MULTIPLIER = 100, then 
        300 * 100 / 900 = 30000 / 900 = 33 (33.333333333)
        dividend = 200 * 33 / 100 = 66
        Other formule
        dividend = (300 * 200) / 900 = 60000 / 900 = 600/9 = 66.6 = 66
        */
        //uint256 partShare = (senderBalance * POINTS_MULTIPLIER) / TokenTotalSupply;
        //uint256 dividendTotalSupply = segragatedDividend[time];
        //uint256 dividend = (dividendTotalSupply * partShare) / POINTS_MULTIPLIER;
        
        uint256 senderDividend = _computeDividend(time, senderBalance, TokenTotalSupply);
        
        // Transfer restriction
        if (!ValidationModule._operateOnTransfer(address(this), sender, senderDividend)) {
            revert Errors.CMTAT_InvalidTransfer(address(this), sender, senderDividend);
        }
        _transferDividend(time, sender, senderDividend);
    }

    /**
    * @notice deposit an amount to pay the dividends.
    * @param time provide the date where you want to perform a deposit
    * @param amount the amount to deposit
    */
    function deposit(uint256 time, uint256 amount) public onlyRole(DEBT_VAULT_DEPOSIT_ROLE) {
        address sender = _msgSender();
        if(amount == 0) {
            revert noAmountSend();
        }
        segragatedDividend[time] += amount;
        emit newDeposit(time, sender, amount);
        // Will revert in case of failure
        ERC20TokenPayment.safeTransferFrom(sender, address(this), amount);
    }

    /**
    * @notice withdraw a certain amount at a specified time.
    * @param time provide the date where you want to perform a deposit
    * @param amount the amount to withdraw
    * @param withdrawAddress address to receive `amount`of tokens
    */
    function withdraw(uint256 time, uint256 amount, address withdrawAddress) public onlyRole(DEBT_VAULT_WITHDRAW_ROLE) {
        // TODO: check why it is necessary
        ERC20TokenPayment.approve(address(this), amount);
        if(segragatedDividend[time] < amount) {
            revert notEnoughAmount();
        }
        segragatedDividend[time] -= amount;
        // Will revert in case of failure
        ERC20TokenPayment.safeTransferFrom(address(this), withdrawAddress, amount);
    }

    /**
    * @notice withdraw all tokens from ERC20TokenPayment contracts deposited
    * @param amount the amount to withdraw
    * @param withdrawAddress address to receive `amount`of tokens
    */
    function withdrawAll(uint256 amount, address withdrawAddress) public onlyRole(DEBT_VAULT_WITHDRAW_ROLE) {
        // TODO: check why it is necessary
        ERC20TokenPayment.approve(address(this), amount);
        // Will revert in case of failure
        ERC20TokenPayment.safeTransferFrom(address(this), withdrawAddress, amount);
    }

    /**
    * @notice deposit an amount to pay the dividends.
    * @param addresses compute and transfer dividend for these holders
    * @param time dividend time
    */
    function distributeDividend(address[] calldata addresses, uint256 time) public onlyRole(DEBT_VAULT_DISTRIBUTE_ROLE) {
        // Check if the claim is activated
        if(!segragatedClaim[time]){
             revert claimNotActivated();
        }
        // Get info from the token
        (uint256[] memory tokenHolderBalance, uint256 totalSupply) = CMTAT_TOKEN.snapshotInfoBatch(time, addresses);
        // Compute dividend for all token holders
        uint256[] memory tokenHolderDividend = _computeDividendBatch(time, addresses, tokenHolderBalance, totalSupply);
        // transfer the dividends for all token holders
        for(uint256 i = 0; i < addresses.length; ++i){
             // Do nothing if the token holder has already claimed its dividends.
             if (!claimedDividend[addresses[i]][time]){
                // Compute dividend
                if(tokenHolderDividend[i] > 0){
                    _transferDividend(time, addresses[i], tokenHolderDividend[i]);
                }
            }
        }
    }


    //snapshotBalanceOfBatch

    /**
    * @notice set the status to open or close the claims for a given time
    * @param time target time
    * @param status boolean (true or false)
    * 
    */
    function setStatusClaim(uint256 time, bool status) public onlyRole(DEBT_VAULT_OPERATOR_ROLE){
        segragatedClaim[time] = status;
    }

    /*function setTokenPayment(IERC20 ERC20TokenPayment_) public onlyRole(DEBT_VAULT_OPERATOR_ROLE){
        if(address(ERC20TokenPayment_) != address(0)){
            ERC20TokenPayment = ERC20TokenPayment_;
        }
    }*/

    /*function setTokenCMTAT(CMTAT_BASE cmtat_token) public onlyRole(DEBT_VAULT_OPERATOR_ROLE){
        if(address(cmtat_token) != address(0) && address(CMTAT_TOKEN) == address(0)){
            CMTAT_TOKEN = cmtat_token;
        }
    }*/


    /**
    * @param time dividend time
    * @param tokenHolders addresses to compute dividend
    * @param tokenHoldersBalance the sender balance
    * @param tokenTotalSupply the total supply
    */
    function _computeDividendBatch(uint256 time, address[] calldata tokenHolders, uint256[] memory tokenHoldersBalance, uint256 tokenTotalSupply) internal view returns(uint256[] memory tokenHolderDividend){
        tokenHolderDividend = new uint256[](tokenHolders.length);
        uint256 dividendTotalSupply = segragatedDividend[time];
        for(uint256 i = 0; i < tokenHolders.length; ++i){
            if(tokenHoldersBalance[i] > 0) {
                tokenHolderDividend[i] = (tokenHoldersBalance[i] * dividendTotalSupply) / tokenTotalSupply;
            }
        }
    }



    /**
    * @param time dividend time
    * @param senderBalance token holder balance
    * @param tokenTotalSupply the total supply
    */
    function _computeDividend(uint256 time, uint256 senderBalance, uint256 tokenTotalSupply) internal view returns(uint256 tokenHolderDividend){
        if (senderBalance == 0){
            revert noDividendToClaim();
        }
        /**
        SenderBalance = 300 
        totalSupply = 900
        Dividend total supply= 200
        If POINTS_MULTIPLIER = 100, then 
        300 * 100 / 900 = 30000 / 900 = 33 (33.333333333)
        dividend = 200 * 33 / 100 = 66
        Other formule
        dividend = (300 * 200) / 900 = 60000 / 900 = 600/9 = 66.6 = 66
        */
        //uint256 partShare = (senderBalance * POINTS_MULTIPLIER) / TokenTotalSupply;
        uint256 dividendTotalSupply = segragatedDividend[time];
        //uint256 dividend = (dividendTotalSupply * partShare) / POINTS_MULTIPLIER;
        
        tokenHolderDividend = (senderBalance * dividendTotalSupply) / tokenTotalSupply;
    }

    /**
    * @param time dividend time
    * @param tokenHolder addresses to send the dividends
    * @param tokenHolderDividend the computed dividends
    */
    function _transferDividend(uint256 time, address tokenHolder, uint256 tokenHolderDividend) internal{
        // Before ERC-20 transfer to avoid re-entrancy attack
        claimedDividend[tokenHolder][time] = true;
        emit DividendClaimed(time, tokenHolder, tokenHolderDividend);
        // transfer
        // We don't revert if SenderBalance == 0 to record the claim
        if(tokenHolderDividend != 0){
            // Will revert in case of failure
            // We should put that in a try catch for the batch version ???
            ERC20TokenPayment.safeTransfer(tokenHolder, tokenHolderDividend);
        }
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
}
