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

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State functions ============ */
    /**
    * @notice claim your payment
    * @param time provide the date where you want to receive your payment
    */
    function claimDividend(uint256 time) public virtual nonReentrant() {
        validateTime(time);
        address sender = _msgSender();
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        // At the beginning since no external call to do
        if ($._claimedDividend[sender][time]){
            revert IncomeVault_DividendAlreadyClaimed();
        }

        // External call to the snapshot source to retrieve the total supply and the sender balance
        (uint256 senderBalance, uint256 TokenTotalSupply) = $._snapshotEngine.snapshotInfo(time, sender);
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
    function claimDividendBatch(uint256[] calldata times) public virtual nonReentrant() {
        // Check if the claim is activated for each times
        validateTimeBatch(times);
        address sender = _msgSender();
        address[] memory senders = new address[](1);
        senders[0] = sender;
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        // External call to the snapshot source to retrieve the total supply and the sender balance
        (uint256[][] memory senderBalances, uint256[] memory TokenTotalSupplys) = $._snapshotEngine.snapshotInfoBatch(times, senders);
        for(uint256 i = 0; i < times.length; ++i){
            if (!$._claimedDividend[sender][times[i]] && (senderBalances[i][0] > 0 )){
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
    function validateTimeCode(uint256 time) public view virtual returns(TIME_ERROR_CODE code){
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return _timeCode($, time, $._timeLimitToWithdraw);
    }
    
    /**
    * @notice validate if a time is valid, revert if invalid
    * @param time the dividend time to check
    */
    function validateTime(uint256 time) public view virtual {
        _revertOnInvalidTime(validateTimeCode(time));
    }

    /**
    * @notice batch version of {validateTime}
    * @param times the dividend times to check
    */
    function validateTimeBatch(uint256[] calldata times) public view virtual {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        // `_timeLimitToWithdraw` is the same slot for every element: read it once
        uint256 timeLimit = $._timeLimitToWithdraw;
        for(uint256 i = 0; i < times.length; ++i){
           _revertOnInvalidTime(_timeCode($, times[i], timeLimit));
        }
    }
}
