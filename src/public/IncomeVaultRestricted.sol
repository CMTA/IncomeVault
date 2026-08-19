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

    /* ============ Modifier ============ */
    /// @dev Restricts the deposit of dividends
    modifier onlyDepositManager() {
        _authorizeDeposit();
        _;
    }

    /// @dev Restricts the withdrawal of the deposited funds
    modifier onlyWithdrawManager() {
        _authorizeWithdraw();
        _;
    }

    /// @dev Restricts the issuer-driven distribution of the dividends
    modifier onlyDistributeManager() {
        _authorizeDistribute();
        _;
    }

    /// @dev Restricts the configuration of the claim window
    modifier onlyVaultOperator() {
        _authorizeOperator();
        _;
    }

    /* ============  Initializer Function ============ */
    /**
    * @dev calls the different initialize functions from the different modules
    * @param timeLimitToWithdraw_ delay, after the dividend time, during which a claim is accepted
    */
    function __IncomeVaultRestricted_init_unchained(
        uint256 timeLimitToWithdraw_
    ) internal onlyInitializing {
       _setTimeLimitToWithdraw(timeLimitToWithdraw_);
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
    function deposit(uint256 time, uint256 amount) public virtual onlyDepositManager {
        address sender = _msgSender();
        if(amount == 0) {
            revert IncomeVault_NoAmountSend();
        }
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        $._segregatedDividend[time] += amount;
        emit newDeposit(time, sender, amount);
        // Will revert in case of failure
        $._ERC20TokenPayment.safeTransferFrom(sender, address(this), amount);
    }

    /**
    * @notice withdraw a certain amount at a specified time.
    * @param time provide the date where you want to perform a deposit
    * @param amount the amount to withdraw
    * @param withdrawAddress address to receive `amount`of tokens
    */
    function withdraw(uint256 time, uint256 amount, address withdrawAddress) public virtual onlyWithdrawManager {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        if($._segregatedDividend[time] < amount) {
            revert IncomeVault_NotEnoughAmount();
        }
        $._segregatedDividend[time] -= amount;
        emit Withdraw(time, withdrawAddress, amount);
        // Will revert in case of failure
        $._ERC20TokenPayment.safeTransfer(withdrawAddress, amount);
    }

    /**
    * @notice withdraw all tokens from ERC20TokenPayment contracts deposited
    * @param amount the amount to withdraw
    * @param withdrawAddress address to receive `amount`of tokens
    */
    function withdrawAll(uint256 amount, address withdrawAddress) public virtual onlyWithdrawManager {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        emit WithdrawAll(withdrawAddress, amount);
        // Will revert in case of failure
        $._ERC20TokenPayment.safeTransfer(withdrawAddress, amount);
    }

    /**
    * @notice distribute the dividends
    * @param addresses compute and transfer dividend for these holders
    * @param time dividend time
    * @dev The dividends are distributed only if they have not yet been claimed by the token holder.
    * Subject to the same claim window **and** the same transfer restrictions as
    * {IncomeVaultOpen-claimDividend}: a holder the pause, freeze or RuleEngine refuses cannot be paid
    * by the issuer either, and one blocked holder reverts the whole distribution.
    */
    function distributeDividend(address[] calldata addresses, uint256 time) public virtual onlyDistributeManager {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        // Same window as a holder-driven claim: the claims must be open, `time` must have passed so the
        // snapshot is recorded, and the withdraw limit must not have expired. Distributing before `time`
        // would read the *live* balances, because {ISnapshotSource} falls back to them when no snapshot
        // exists yet, and would consume the holder's claim for that period at the wrong amount.
        _revertOnInvalidTime(_timeCode($, time, $._timeLimitToWithdraw));
        // Get info from the snapshot source
        (uint256[] memory tokenHolderBalance, uint256 totalSupply) = $._snapshotEngine.snapshotInfoBatch(time, addresses);
        // Compute dividend for all token holders
        uint256[] memory tokenHolderDividend = _computeDividendBatch(time, addresses, tokenHolderBalance, totalSupply);
        // transfer the dividends for all token holders
        for(uint256 i = 0; i < addresses.length; ++i){
             // The dividends are distributed only if they have not yet been claimed by the token holder
             if (!$._claimedDividend[addresses[i]][time]){
                // transfer dividends
                if(tokenHolderDividend[i] > 0){
                    // Same transfer restriction as a holder-driven claim: pause, freeze and RuleEngine.
                    // Reverts the whole distribution rather than skipping the holder, so a blocked
                    // address cannot be silently dropped from a payout the operator believes succeeded.
                    // The error carries the address, so it can be removed from the list and retried.
                    _validateTransfer(address(this), addresses[i], tokenHolderDividend[i]);
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
    function setStatusClaim(uint256 time, bool status) public virtual onlyVaultOperator {
        _setStatusClaim(time, status);
    }

    /**
    * @notice configure the time limit to withdraw
    * @param timeLimitToWithdraw_ delay, after the dividend time, during which a claim is accepted
    */
    function setTimeLimitToWithdraw(uint256 timeLimitToWithdraw_) public virtual onlyVaultOperator {
        _setTimeLimitToWithdraw(timeLimitToWithdraw_);
    }
    

    /* ============ Access Control ============ */
    /**
    * @dev Authorization hook invoked before a deposit.
    * Implemented by the deployment contract with the desired access-control policy.
    */
    function _authorizeDeposit() internal view virtual;

    /**
    * @dev Authorization hook invoked before {withdraw} and {withdrawAll}.
    * Implemented by the deployment contract with the desired access-control policy.
    */
    function _authorizeWithdraw() internal view virtual;

    /**
    * @dev Authorization hook invoked before {distributeDividend}.
    * Implemented by the deployment contract with the desired access-control policy.
    */
    function _authorizeDistribute() internal view virtual;

    /**
    * @dev Authorization hook invoked before {setStatusClaim} and {setTimeLimitToWithdraw}.
    * Implemented by the deployment contract with the desired access-control policy.
    */
    function _authorizeOperator() internal view virtual;
}
