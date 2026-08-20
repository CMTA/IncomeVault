// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== OpenZeppelin === */
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
/* ==== IncomeVault === */
import {IncomeVaultValidationCore} from "../modules/IncomeVaultValidationCore.sol";
import {IncomeVaultSnapshotCore} from "../modules/IncomeVaultSnapshotCore.sol";
import {IncomeVaultInternal} from "../libraries/IncomeVaultInternal.sol";
import {IERC7540Operator} from "../interfaces/IERC7540Operator.sol";
import {ERC7741Module} from "../modules/ERC7741Module.sol";

/**
* @title Permissionless functions
*/
abstract contract IncomeVaultOpen is
    IncomeVaultValidationCore,
    IncomeVaultSnapshotCore,
    ERC7741Module,
    ReentrancyGuardTransient
{
    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State functions ============ */
    /**
    * @notice claim your payment
    * @param time provide the date where you want to receive your payment
    */
    function claimDividend(uint256 time) public virtual nonReentrant {
        _claimDividend(_msgSender(), time);
    }

    /**
    * @notice Claim on behalf of a token holder
    * @dev
    * Callable by the holder, or by an address the holder authorised through {setOperator}. The
    * dividends always go to **the holder** — an operator pays the gas and chooses the moment, it can
    * never redirect the payment. Every other rule is unchanged: the claim window, the
    * already-claimed check and the transfer restrictions all apply exactly as for {claimDividend}.
    * @param holder the token holder to claim for
    * @param time provide the date of the payment
    */
    function claimDividendFor(address holder, uint256 time) public virtual nonReentrant {
        _requireHolderOrOperator(holder);
        _claimDividend(holder, time);
    }

    /**
    * @notice Batch version of {claimDividendFor}
    * @param holder the token holder to claim for
    * @param times provide the dates of the payments
    */
    function claimDividendBatchFor(address holder, uint256[] calldata times) public virtual nonReentrant {
        _requireHolderOrOperator(holder);
        _claimDividendBatch(holder, times);
    }

    /**
    * @notice batch version of {claimDividend}
    * @param times provide the dates where you want to receive your payment
    * @dev Don't check if the dividends have been already claimed before external call to the snapshot source.
    */
    function claimDividendBatch(uint256[] calldata times) public virtual nonReentrant {
        _claimDividendBatch(_msgSender(), times);
    }

    /**
    * @notice Authorise or revoke an address to claim on your behalf
    * @dev Same signature, semantics and event as ERC-7540's `setOperator`, so tooling written for
    * that standard works here. The operator can never receive the dividends, only trigger the claim.
    * @inheritdoc IERC7540Operator
    */
    function setOperator(address operator, bool approved) public virtual override(IERC7540Operator) returns (bool) {
        _setOperator(_msgSender(), operator, approved);
        return true;
    }

    /* ============ View functions ============ */
    /**
    * @notice validate if a time is valid, return 0 if valid
    * @param time the dividend time to check
    * @return code the reason the time is invalid, or `TIME_ERROR_CODE.OK`
    */
    function validateTimeCode(uint256 time) public view virtual returns (TIME_ERROR_CODE code) {
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
        for (uint256 i = 0; i < times.length; ++i) {
            _revertOnInvalidTime(_timeCode($, times[i], timeLimit));
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State functions ============ */
    /**
    * @dev {claimDividend} for an explicit holder
    * @param sender the token holder being paid
    * @param time the dividend time
    */
    function _claimDividend(address sender, uint256 time) internal virtual {
        validateTime(time);
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        // At the beginning since no external call to do
        if ($._claimedDividend[sender][time]) {
            revert IncomeVault_DividendAlreadyClaimed();
        }

        // External call to the snapshot source to retrieve the total supply and the sender balance
        (uint256 senderBalance, uint256 TokenTotalSupply) = _snapshotInfo(time, sender);
        if (senderBalance == 0) {
            revert IncomeVault_TokenBalanceIsZero();
        }

        uint256 senderDividend = _computeDividend(time, senderBalance, TokenTotalSupply);
        if (senderDividend == 0) {
            revert IncomeVault_NoDividendToClaim();
        }

        // Transfer restriction
        _validateTransfer(address(this), sender, senderDividend);
        _transferDividend(time, sender, senderDividend);
    }

    /**
    * @dev {claimDividendBatch} for an explicit holder
    * @param sender the token holder being paid
    * @param times the dividend times
    */
    function _claimDividendBatch(address sender, uint256[] calldata times) internal virtual {
        // Check if the claim is activated for each times
        validateTimeBatch(times);
        address[] memory senders = new address[](1);
        senders[0] = sender;
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        // External call to the snapshot source to retrieve the total supply and the sender balance
        (uint256[][] memory senderBalances, uint256[] memory TokenTotalSupplys) = _snapshotInfoBatch(times, senders);
        for (uint256 i = 0; i < times.length; ++i) {
            if (!$._claimedDividend[sender][times[i]] && (senderBalances[i][0] > 0)) {
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
    * @dev reverts unless the caller is `holder` or an operator `holder` authorised
    * @param holder the token holder being claimed for
    */
    function _requireHolderOrOperator(address holder) internal view virtual {
        address caller = _msgSender();
        if (caller != holder && !isOperator(holder, caller)) {
            revert IncomeVault_UnauthorizedOperator(holder, caller);
        }
    }
}
