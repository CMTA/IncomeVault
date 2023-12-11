// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

import "../../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "./modules/MetaTxModuleStandalone.sol";
/**
@title Debt Vault to distribute dividend
*/

contract debtVault is AccessControl, MetaTxModuleStandalone {
    // errors
    error claimNotAcivated();
    error dividentAlreadyClaimed();
    error noDividendToClaim();

    // CMTAT token
    address  CMTAT_TOKEN;

    uint128 internal constant POINTS_MULTIPLIER = type(uint64).max;
    address public ERC20TokenPayment;
    bool claimActivated;
    mapping(address => mapping (uint256 => bool)) claimedDivident;
    mapping(uint256 => uint256) segragatedDividend;
    // Number of addresses in the whitelist at the moment
    uint256 private numAddressesWhitelisted;
    
    /**
    * @param admin Address of the contract (Access Control)
    * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
    */
    constructor(
        address admin,
        address forwarderIrrevocable,
        address ERC20TokenPayment_,
        address cmtat_token
    ) MetaTxModuleStandalone(forwarderIrrevocable) {
        if(admin == address(0)){
            revert RuleWhitelist_AdminWithAddressZeroNotAllowed();
        }
        if(ERC20TokenPayment != address(0)){
            ERC20TokenPayment = ERC20TokenPayment_;
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEBT_VAULT_OPERATOR_ROLE, admin);
        CMTAT_TOKEN = cmtat_token;
    }

    function claimPayment(uint256 time) public {
        // Check if the claim is activated
        if(!claimActivated){
             revert claimNotAcivated();
        }
        address sender = _msgSender();
        // At the beginning since no external call to do
        if (claimedDivident[sender][time]){
            revert dividentAlreadyClaimed();
        }
        // External call
        (uint256 senderBalance, uint256 totalSupply) = CMTAT_TOKEN.snapshotBalanceOf(time, sender);
        if (senderBalance == 0){
            revert noDividendToClaim();
        }
        /*
        SenderBalance = 300 
        totalSupply = 900
        Dividend = 200
        If POINTS_MULTIPLIER = 100, then 
        300 * 100 / 900 = 30000 / 900 = 33 (33.333333333)
        dividend = 200 * 33 / 100 = 66
        */
        uint256 partShare = (senderBalance * POINTS_MULTIPLIER) / totalSupply;
        uint256 dividend = (dividendTotalSupply * partShare) / POINTS_MULTIPLIER;
        
        // Before ERC-20 transfer to avoid re-entrancy attack
        claimedDivident[sender][time] = true;
        
        // transfer
        if(senderBalance != 0){
            ERC20TokenPayment.transfer(address(this), dividend);
        }
        emit DividendClaimed(sender, amount);
    }

    function deposit(time, amount) onlyRole(DEBT_VAULT_OPERATOR_ROLE) {
        //TODO: Check return value
        ERC20TokenPayment.transferFrom(_msgSender(), address(this), amount);
        segragatedDividend[time] += amount;
    }

    function withdraw(time, amount, address withdrawAddress) onlyRole(DEBT_VAULT_OPERATOR_ROLE) {
        //TODO: Check return value
        ERC20TokenPayment.transferFrom(address(this), withdrawAddress, amount);
        segragatedDividend[time] -= amount;
    }

    /** 
    * @dev This surcharge is not necessary if you do not use the MetaTxModule
    */
    function _msgSender()
        internal
        view
        override(MetaTxModuleStandalone, Context)
        returns (address sender)
    {
        return MetaTxModuleStandalone._msgSender();
    }

    /** 
    * @dev This surcharge is not necessary if you do not use the MetaTxModule
    */
    function _msgData()
        internal
        view
        override(MetaTxModuleStandalone, Context)
        returns (bytes calldata)
    {
        return MetaTxModuleStandalone._msgData();
    }
}
