// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

import "OZ/token/ERC20/utils/SafeERC20.sol"; 
import "CMTAT/modules/wrapper/controllers/ValidationModule.sol";
import "../lib/IncomeVaultInternal.sol";

/**
* @title Debt Vault to distribute dividend
*/// AuthorizationModuleStandalone
abstract contract IncomeVaultRestricted is ValidationModule, IncomeVaultInternal {


    // Security
    using SafeERC20 for IERC20;
    
    /**
    * @notice deposit an amount to pay the dividends.
    * @param time provide the date where you want to perform a deposit
    * @param amount the amount to deposit
    */
    function deposit(uint256 time, uint256 amount) public onlyRole(INCOME_VAULT_DEPOSIT_ROLE) {
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
    function withdraw(uint256 time, uint256 amount, address withdrawAddress) public onlyRole(INCOME_VAULT_WITHDRAW_ROLE) {
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
    function withdrawAll(uint256 amount, address withdrawAddress) public onlyRole(INCOME_VAULT_WITHDRAW_ROLE) {
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
    function distributeDividend(address[] calldata addresses, uint256 time) public onlyRole(INCOME_VAULT_DISTRIBUTE_ROLE) {
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

    /**
    * @notice set the status to open or close the claims for a given time
    * @param time target time
    * @param status boolean (true or false)
    * 
    */
    function setStatusClaim(uint256 time, bool status) public onlyRole(INCOME_VAULT_OPERATOR_ROLE){
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
    uint256[50] private __gap;
}
