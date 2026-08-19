// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== OpenZeppelin === */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
/* ==== Snapshot === */
import {ISnapshotState} from "SnapshotEngine/interface/ISnapshotState.sol";
/* ==== IncomeVault === */
import {IncomeVaultInvariantStorage} from "./IncomeVaultInvariantStorage.sol";

/**
* @title Internal functions
* @dev
* The vault is token-agnostic: `snapshotEngine` is any contract implementing {ISnapshotState},
* e.g. the CMTA `SnapshotEngine` bound to an ERC-20, or a token embedding the snapshot logic itself.
*/
abstract contract IncomeVaultInternal is IncomeVaultInvariantStorage {
    // Manage transfer failure
    using SafeERC20 for IERC20;

    /* ============ State Variables ============ */
    /**
    * @notice Snapshot source used to read the token holder balances and the total supply
    */
    ISnapshotState public snapshotEngine;
    /**
    * @notice ERC-20 token used to pay the dividends
    */
    IERC20 public ERC20TokenPayment;
    /**
    * @notice Records, per token holder and per dividend time, whether the dividends were claimed
    */
    mapping(address => mapping (uint256 => bool)) public claimedDividend;
    /**
    * @notice Total amount of payment token deposited for a given dividend time
    */
    mapping(uint256 => uint256) public segregatedDividend;
    /**
    * @notice Claim status, per dividend time: true when the holders can claim
    */
    mapping(uint256 => bool) public segregatedClaim;
    /**
    * @notice Delay, after the dividend time, during which a claim is still accepted
    */
    uint256 public timeLimitToWithdraw;

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
    * @notice Records the claim then sends the dividends to the token holder
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
            ERC20TokenPayment.safeTransfer(tokenHolder, tokenHolderDividend);
        }
    }

    /**
    * @notice Sets the snapshot source used to compute the dividends
    * @dev reverts if `snapshotEngine_` is the zero address
    * @param snapshotEngine_ any contract implementing {ISnapshotState}
    */
    function _setSnapshotEngine(ISnapshotState snapshotEngine_) internal virtual {
        if(address(snapshotEngine_) == address(0)){
            revert IncomeVault_SnapshotEngineWithAddressZeroNotAllowed();
        }
        snapshotEngine = snapshotEngine_;
        emit SnapshotEngineSet(snapshotEngine_);
    }

    /**
    * @notice Computes the dividends owed to several token holders for a given time
    * @param time dividend time
    * @param tokenHolders addresses to compute dividend
    * @param tokenHoldersBalance the sender balance
    * @param tokenTotalSupply the total supply
    * @return tokenHolderDividend the dividends owed to each address of `tokenHolders`
    */
    function _computeDividendBatch(uint256 time, address[] calldata tokenHolders, uint256[] memory tokenHoldersBalance, uint256 tokenTotalSupply) internal view returns(uint256[] memory tokenHolderDividend){
        tokenHolderDividend = new uint256[](tokenHolders.length);
        uint256 dividendTotalSupply = segregatedDividend[time];
        for(uint256 i = 0; i < tokenHolders.length; ++i){
            if(tokenHoldersBalance[i] > 0) {
                tokenHolderDividend[i] = (tokenHoldersBalance[i] * dividendTotalSupply) / tokenTotalSupply;
            }
        }
    }

    /**
    * @notice Computes the dividends owed to a single token holder for a given time
    * @param time dividend time
    * @param senderBalance token holder balance
    * @param tokenTotalSupply the total supply
    * @return tokenHolderDividend the dividends owed to the token holder, rounded down
    */
    function _computeDividend(uint256 time, uint256 senderBalance, uint256 tokenTotalSupply) internal view returns(uint256 tokenHolderDividend){
        if (senderBalance == 0){
            revert IncomeVault_NoDividendToClaim();
        }
        /**
        * Example
        * SenderBalance = 300 
        * totalSupply = 900
        * Dividend total supply = 200
        * dividend = (300 * 200) / 900 = 60000 / 900 = 600/9 = 66.6 = 66
        */
        uint256 dividendTotalSupply = segregatedDividend[time];

        tokenHolderDividend = (senderBalance * dividendTotalSupply) / tokenTotalSupply;
    }

    /**
    * @notice Storage gap reserved for future versions of this module
    */
    uint256[50] private __gap;
}
