// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;


import "lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "../lib/IncomeVaultInternal.sol";
import "CMTAT/modules/wrapper/controllers/ValidationModule.sol";
/**
* @title Debt Vault to distribute dividend
*/
abstract contract IncomeVaultOpen is ReentrancyGuardUpgradeable,  ValidationModule , IncomeVaultInternal  {
    /**
    * @notice claim your payment
    * @param time provide the date where you want to receive your payment
    */
    function claimDividend(uint256 time) public nonReentrant() {
        // Check if the claim is activated
        if(!segragatedClaim[time]){
             revert claimNotActivated();
        }
        address sender = _msgSender();
        // At the beginning since no external call to do
        if (claimedDividend[sender][time]){
            revert dividendAlreadyClaimed();
        }
        // External call to the CMTAT to retrieve the total supply and the sender balance
        (uint256 senderBalance, uint256 TokenTotalSupply) = CMTAT_TOKEN.snapshotInfo(time, sender);
        if (senderBalance == 0){
            revert noDividendToClaim();
        }

        uint256 senderDividend = _computeDividend(time, senderBalance, TokenTotalSupply);
        
        // Transfer restriction
        if (!ValidationModule._operateOnTransfer(address(this), sender, senderDividend)) {
            revert Errors.CMTAT_InvalidTransfer(address(this), sender, senderDividend);
        }
        _transferDividend(time, sender, senderDividend);
    }

    /**
    * @notice claim your payment
    * @param times provide the dates where you want to receive your payment
    * @dev Don't check if the dividends have been already claimed before external call to CMTAT.
    */
    function claimDividendBatch(uint256[] memory times) public nonReentrant() {
        // Check if the claim is activated for each times
        for(uint256 i = 0; i < times.length; ++i){
            if(!segragatedClaim[times[i]]){
                revert claimNotActivated();
            }
        }
        address sender = _msgSender();
        address[] memory senders = new address[](1);
        senders[0] = sender;
        //function snapshotInfoBatch(uint256[] calldata times, address[] calldata addresses) public view returns (uint256[][] memory ownerBalances, uint256[] memory totalSupply) {
        // External call to the CMTAT to retrieve the total supply and the sender balance
        (uint256[][] memory senderBalances, uint256[] memory TokenTotalSupplys) = CMTAT_TOKEN.snapshotInfoBatch(times, senders);
        for(uint256 i = 0; i < times.length; ++i){
            if (!claimedDividend[sender][times[i]] && (senderBalances[i][0] > 0)){
                uint256 senderDividend = _computeDividend(times[i], senderBalances[i][0], TokenTotalSupplys[i]);
                // Transfer restriction
                // External Call
                if (!ValidationModule._operateOnTransfer(address(this), sender, senderDividend)) {
                    revert Errors.CMTAT_InvalidTransfer(address(this), sender, senderDividend);
                }
                // internal call performing an ERC-20 external call
                _transferDividend(times[i], sender, senderDividend);
            }
        }
    }
    uint256[50] private __gap;
}
