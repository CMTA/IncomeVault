// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== OpenZeppelin === */
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
/* ==== IncomeVault === */
import {IncomeVaultValidationModule} from "../modules/IncomeVaultValidationModule.sol";
import {IncomeVaultInternal} from "../libraries/IncomeVaultInternal.sol";

/**
* @title Permissionless functions
*/
abstract contract IncomeVaultOpen is ReentrancyGuardTransient, IncomeVaultValidationModule, IncomeVaultInternal  {
    enum TIME_ERROR_CODE {OK, CLAIM_NOT_ACTIVATED, TOO_LATE_TO_WITHDRAW, TOO_EARLY_TO_WITHDRAW}

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State functions ============ */
    /**
    * @notice claim your payment
    * @param time provide the date where you want to receive your payment
    */
    function claimDividend(uint256 time) public nonReentrant() {
        validateTime(time);
        address sender = _msgSender();
        // At the beginning since no external call to do
        if (claimedDividend[sender][time]){
            revert IncomeVault_DividendAlreadyClaimed();
        }

        // External call to the snapshot source to retrieve the total supply and the sender balance
        (uint256 senderBalance, uint256 TokenTotalSupply) = snapshotEngine.snapshotInfo(time, sender);
        if (senderBalance == 0){
            revert IncomeVault_TokenBalanceIsZero();
        }

        uint256 senderDividend = _computeDividend(time, senderBalance, TokenTotalSupply);
        if (senderDividend == 0){
            revert IncomeVault_NoDividendToClaim();
        }

        // Transfer restriction
        _validateTransfer(address(this), sender, senderDividend);
        _transferDividend(time, sender, senderDividend);
    }

    /**
    * @notice batch version of {claimDividend}
    * @param times provide the dates where you want to receive your payment
    * @dev Don't check if the dividends have been already claimed before external call to the snapshot source.
    */
    function claimDividendBatch(uint256[] memory times) public nonReentrant() {
        // Check if the claim is activated for each times
        validateTimeBatch(times);
        address sender = _msgSender();
        address[] memory senders = new address[](1);
        senders[0] = sender;
        // External call to the snapshot source to retrieve the total supply and the sender balance
        (uint256[][] memory senderBalances, uint256[] memory TokenTotalSupplys) = snapshotEngine.snapshotInfoBatch(times, senders);
        for(uint256 i = 0; i < times.length; ++i){
            if (!claimedDividend[sender][times[i]] && (senderBalances[i][0] > 0 )){
                uint256 senderDividend = _computeDividend(times[i], senderBalances[i][0], TokenTotalSupplys[i]);
                // Transfer restriction
                _validateTransfer(address(this), sender, senderDividend);
                // internal call performing an ERC-20 external call
                _transferDividend(times[i], sender, senderDividend);
            }
        }
    } 
    /* ============ View functions ============ */
    /**
    * @notice validate if a time is valid, return 0 if valid
    * @param time the dividend time to check
    * @return code the reason the time is invalid, or `TIME_ERROR_CODE.OK`
    */
    function validateTimeCode(uint256 time) public view returns(TIME_ERROR_CODE code){
        if(!segregatedClaim[time]){
            return TIME_ERROR_CODE.CLAIM_NOT_ACTIVATED;
        }
        if(block.timestamp > timeLimitToWithdraw + time){
            return TIME_ERROR_CODE.TOO_LATE_TO_WITHDRAW;
        }
        if(block.timestamp < time){
            return TIME_ERROR_CODE.TOO_EARLY_TO_WITHDRAW;
        }
        return TIME_ERROR_CODE.OK;
    }
    
    /**
    * @notice validate if a time is valid, revert if invalid
    * @param time the dividend time to check
    */
    function validateTime(uint256 time) public view{
        TIME_ERROR_CODE code = validateTimeCode(time);
         if(code == TIME_ERROR_CODE.OK){
            return;
        }else if(code == TIME_ERROR_CODE.CLAIM_NOT_ACTIVATED){
            revert IncomeVault_ClaimNotActivated();
        }
        else if(code == TIME_ERROR_CODE.TOO_LATE_TO_WITHDRAW){
            revert IncomeVault_TooLateToWithdraw(block.timestamp);
        }else if (code == TIME_ERROR_CODE.TOO_EARLY_TO_WITHDRAW){
            revert IncomeVault_TooEarlyToWithdraw(block.timestamp);
        }
    }

    /**
    * @notice batch version of {validateTime}
    * @param times the dividend times to check
    */
    function validateTimeBatch(uint256[] memory times) public view{
        for(uint256 i = 0; i < times.length; ++i){
           validateTime(times[i]);
        }
    }

    /**
    * @notice Storage gap reserved for future versions of this module
    */
    uint256[50] private __gap;
}
