// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

import "OZ/token/ERC20/utils/SafeERC20.sol"; 
import "./IncomeVaultInvariantStorage.sol";
import "CMTAT/interfaces/ICMTATSnapshot.sol";
/**
* @title Internal functions
*/
abstract contract IncomeVaultInternal is IncomeVaultInvariantStorage  {
    // CMTAT token
    ICMTATSnapshot public CMTAT_TOKEN;
    IERC20 public ERC20TokenPayment;
    mapping(address => mapping (uint256 => bool)) public claimedDividend;
    mapping(uint256 => uint256) public segregatedDividend;
    mapping(uint256 => bool) public segregatedClaim;
    uint256 public timeLimitToWithdraw;

    // Manage transfer failure
    using SafeERC20 for IERC20;

    /**
    * @param time dividend time
    * @param tokenHolders addresses to compute dividend
    * @param tokenHoldersBalance the sender balance
    * @param tokenTotalSupply the total supply
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
    * @param time dividend time
    * @param senderBalance token holder balance
    * @param tokenTotalSupply the total supply
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
}
