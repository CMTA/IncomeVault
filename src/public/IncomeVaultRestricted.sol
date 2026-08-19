// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== OpenZeppelin === */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
/* ==== IncomeVault === */
import {IncomeVaultValidationModule} from "../modules/IncomeVaultValidationModule.sol";
import {IncomeVaultInternal} from "../libraries/IncomeVaultInternal.sol";

/**
* @title Restricted functions
*/
abstract contract IncomeVaultRestricted is IncomeVaultValidationModule, IncomeVaultInternal {
    // Security
    using SafeERC20 for IERC20;

    /* ============  Initializer Function ============ */
    /**
    * @dev calls the different initialize functions from the different modules
    */
    function __IncomeVaultRestricted_init_unchained(
        uint256 timeLimitToWithdraw_
    ) internal onlyInitializing {
       timeLimitToWithdraw = timeLimitToWithdraw_;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State restricted functions ============ */
    /**
    * @notice deposit an amount to pay the dividends.
    * @param time provide the date where you want to perform a deposit
    * @param amount the amount to deposit
    */
    function deposit(uint256 time, uint256 amount) public onlyRole(INCOME_VAULT_DEPOSIT_ROLE) {
        address sender = _msgSender();
        if(amount == 0) {
            revert IncomeVault_NoAmountSend();
        }
        segregatedDividend[time] += amount;
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
        if(segregatedDividend[time] < amount) {
            revert IncomeVault_NotEnoughAmount();
        }
        segregatedDividend[time] -= amount;
        // Will revert in case of failure
        ERC20TokenPayment.safeTransfer(withdrawAddress, amount);
    }

    /**
    * @notice withdraw all tokens from ERC20TokenPayment contracts deposited
    * @param amount the amount to withdraw
    * @param withdrawAddress address to receive `amount`of tokens
    */
    function withdrawAll(uint256 amount, address withdrawAddress) public onlyRole(INCOME_VAULT_WITHDRAW_ROLE) {
        // Will revert in case of failure
        ERC20TokenPayment.safeTransfer(withdrawAddress, amount);
    }

    /**
    * @notice distribute the dividends
    * @param addresses compute and transfer dividend for these holders
    * @param time dividend time
    * @dev The dividends are distributed only if they have not yet been claimed by the token holder
    */
    function distributeDividend(address[] calldata addresses, uint256 time) public onlyRole(INCOME_VAULT_DISTRIBUTE_ROLE) {
        // Check if the claim is activated
        if(!segregatedClaim[time]){
             revert IncomeVault_ClaimNotActivated();
        }
        // Get info from the snapshot source
        (uint256[] memory tokenHolderBalance, uint256 totalSupply) = snapshotEngine.snapshotInfoBatch(time, addresses);
        // Compute dividend for all token holders
        uint256[] memory tokenHolderDividend = _computeDividendBatch(time, addresses, tokenHolderBalance, totalSupply);
        // transfer the dividends for all token holders
        for(uint256 i = 0; i < addresses.length; ++i){
             // The dividends are distributed only if they have not yet been claimed by the token holder
             if (!claimedDividend[addresses[i]][time]){
                // transfer dividends
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
        segregatedClaim[time] = status;
    }

    /**
    * @notice configure the time limit to withdraw
    */
    function setTimeLimitToWithdraw(uint256 timeLimitToWithdraw_) public onlyRole(INCOME_VAULT_OPERATOR_ROLE){
        timeLimitToWithdraw = timeLimitToWithdraw_;
    }
    
    uint256[50] private __gap;
}
