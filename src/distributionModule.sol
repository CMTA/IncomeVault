// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol"; 
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/CMTAT/contracts/CMTAT_PROXY.sol";
import "./modules/MetaTxModuleStandalone.sol";


/**
* @title Debt Vault to distribute dividend
*/
contract DebtVault is AccessControl, MetaTxModuleStandalone, ReentrancyGuard {
    bytes32 public constant DEBT_VAULT_OPERATOR_ROLE = keccak256("DEBT_VAULT_OPERATOR_ROLE");
    bytes32 public constant DEBT_VAULT_DEPOSIT_ROLE = keccak256("DEBT_VAULT_DEPOSIT_ROLE");
    bytes32 public constant DEBT_VAULT_WITHDRAW_ROLE = keccak256("DEBT_VAULT_WITHDRAW_ROLE");

    // errors
    error claimNotAcivated();
    error dividendAlreadyClaimed();
    error noDividendToClaim();
    error AdminWithAddressZeroNotAllowed();
    error noAmountSend();
    error notEnoughAmount();

    // event
    event DividendClaimed(uint256 indexed time, address indexed sender, uint256 dividend);

    // CMTAT token
    CMTAT_BASE  CMTAT_TOKEN;

    uint128 internal constant POINTS_MULTIPLIER = type(uint64).max;
    IERC20 public ERC20TokenPayment;
    mapping(address => mapping (uint256 => bool)) claimedDividend;
    mapping(uint256 => uint256) segragatedDividend;
    mapping(uint256 => bool) segragatedClaim;

    // Security
    using SafeERC20 for IERC20;
    
    /**
    * @param admin Address of the contract (Access Control)
    * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
    * @param ERC20TokenPayment_ ERC20 token to perform the payment 
    */
    constructor(
        address admin,
        address forwarderIrrevocable,
        IERC20 ERC20TokenPayment_,
        CMTAT_BASE cmtat_token
    ) MetaTxModuleStandalone(forwarderIrrevocable) {
        if(admin == address(0)){
            revert AdminWithAddressZeroNotAllowed();
        }
        if(address(ERC20TokenPayment_) != address(0)){
            ERC20TokenPayment = ERC20TokenPayment_;
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEBT_VAULT_OPERATOR_ROLE, admin);
        CMTAT_TOKEN = cmtat_token;
    }

    /**
    * @notice claim your payment
    * @param time provide the date where you want to receive your payment
    */
    function claimPayment(uint256 time) public nonReentrant() {
        // Check if the claim is activated
        if(!segragatedClaim[time]){
             revert claimNotAcivated();
        }
        address sender = _msgSender();
        // At the beginning since no external call to do
        if (claimedDividend[sender][time]){
            revert dividendAlreadyClaimed();
        }
        // External call to the CMTAT to retrieve the total supply and the sender balance
        (uint256 senderBalance, uint256 TokenTotalSupply) = CMTAT_TOKEN.getSnapshotInfoBatch(time, sender);
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

        uint256 senderDividend = (senderBalance * dividendTotalSupply) / TokenTotalSupply;
        
        // Before ERC-20 transfer to avoid re-entrancy attack
        claimedDividend[sender][time] = true;
        emit DividendClaimed(time, sender, senderDividend);
        // transfer
        if(senderBalance != 0){
            // Will revert in case of failure
            ERC20TokenPayment.safeTransfer(address(this), senderDividend);
        }
    }

    /**
    * @notice deposit an amount to pay the dividends.
    * @param time provide the date where you want to perform a deposit
    * @param amount the amount to deposit
    */
    function deposit(uint256 time, uint256 amount) public onlyRole(DEBT_VAULT_DEPOSIT_ROLE) {
        if(amount == 0) {
            revert noAmountSend();
        }
        segragatedDividend[time] += amount;
         // Will revert in case of failure
        ERC20TokenPayment.safeTransferFrom(_msgSender(), address(this), amount);

    }

    /**
    * @notice withdraw a certain amount at a specified time.
    * @param time provide the date where you want to perform a deposit
    * @param amount the amount to withdraw
    * @param withdrawAddress address to receive `amount`of tokens
    */
    function withdraw(uint256 time, uint256 amount, address withdrawAddress) public onlyRole(DEBT_VAULT_WITHDRAW_ROLE) {
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
        // Will revert in case of failure
        ERC20TokenPayment.safeTransferFrom(address(this), withdrawAddress, amount);
    }

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
    * @dev This surcharge is not necessary if you do not use the MetaTxModule
    */
    function _msgSender()
        internal
        view
        override(ERC2771Context, Context)
        returns (address sender)
    {
        return ERC2771Context._msgSender();
    }

    /** 
    * @dev This surcharge is not necessary if you do not use the MetaTxModule
    */
    function _msgData()
        internal
        view
        override(ERC2771Context, Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength() internal view 
    override(ERC2771Context, Context)
    returns (uint256) {
         return ERC2771Context._contextSuffixLength();
    }
}
