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
* @title Internal functions and ERC-7201 storage of the IncomeVault
* @dev
* The vault is token-agnostic: the snapshot source is any contract implementing {ISnapshotState},
* e.g. the CMTA `SnapshotEngine` bound to an ERC-20, or a token embedding the snapshot logic itself.
*
* The state is held in an ERC-7201 namespaced storage struct, as OpenZeppelin Upgradeable and the
* CMTAT do. The namespace is derived from a hash, so it cannot collide with the storage of the
* inherited modules; no `__gap` is needed and new fields can be appended to the struct freely.
*/
abstract contract IncomeVaultInternal is IncomeVaultInvariantStorage {
    // Manage transfer failure
    using SafeERC20 for IERC20;

    /* ============ ERC-7201 ============ */
    /**
    * @dev Slot holding the ERC-7201 namespaced storage of this module, derived as
    * keccak256(abi.encode(uint256(keccak256("IncomeVault.storage.IncomeVaultInternal")) - 1)) & ~bytes32(uint256(0xff))
    * The derivation is re-checked in `test/IncomeVaultStorage.t.sol`.
    */
    bytes32 private constant IncomeVaultInternalStorageLocation = 0xe4f8b033bcfc537db031b0e68e3c1ab0f1de86cf03893d031b6590510b0c0c00;

    /* ==== ERC-7201 State Variables === */
    /// @custom:storage-location erc7201:IncomeVault.storage.IncomeVaultInternal
    struct IncomeVaultInternalStorage {
        // Snapshot source used to read the token holder balances and the total supply
        ISnapshotState _snapshotEngine;
        // ERC-20 token used to pay the dividends
        IERC20 _ERC20TokenPayment;
        // Records, per token holder and per dividend time, whether the dividends were claimed
        mapping(address tokenHolder => mapping(uint256 time => bool claimed)) _claimedDividend;
        // Total amount of payment token deposited for a given dividend time
        mapping(uint256 time => uint256 dividend) _segregatedDividend;
        // Claim status, per dividend time: true when the holders can claim
        mapping(uint256 time => bool status) _segregatedClaim;
        // Delay, after the dividend time, during which a claim is still accepted
        uint256 _timeLimitToWithdraw;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ View functions ============ */
    /**
    * @notice Snapshot source used to read the token holder balances and the total supply
    * @return The contract queried for historical balances and total supply
    */
    function snapshotEngine() public view virtual returns (ISnapshotState) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._snapshotEngine;
    }

    /**
    * @notice ERC-20 token used to pay the dividends
    * @return The payment token
    */
    function ERC20TokenPayment() public view virtual returns (IERC20) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._ERC20TokenPayment;
    }

    /**
    * @notice Tells whether a token holder already claimed the dividends of a given time
    * @param tokenHolder the address to check
    * @param time the dividend time
    * @return True if the dividends were already claimed or distributed
    */
    function claimedDividend(address tokenHolder, uint256 time) public view virtual returns (bool) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._claimedDividend[tokenHolder][time];
    }

    /**
    * @notice Total amount of payment token deposited for a given dividend time
    * @param time the dividend time
    * @return The amount deposited, minus what was already withdrawn
    */
    function segregatedDividend(uint256 time) public view virtual returns (uint256) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._segregatedDividend[time];
    }

    /**
    * @notice Claim status of a given dividend time
    * @param time the dividend time
    * @return True when the token holders can claim their dividends
    */
    function segregatedClaim(uint256 time) public view virtual returns (bool) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._segregatedClaim[time];
    }

    /**
    * @notice Delay, after the dividend time, during which a claim is still accepted
    * @return The delay in seconds
    */
    function timeLimitToWithdraw() public view virtual returns (uint256) {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        return $._timeLimitToWithdraw;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State functions ============ */
    /**
    * @notice Records the claim then sends the dividends to the token holder
    * @param time dividend time
    * @param tokenHolder addresses to send the dividends
    * @param tokenHolderDividend the computed dividends
    */
    function _transferDividend(uint256 time, address tokenHolder, uint256 tokenHolderDividend) internal{
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        // Before ERC-20 transfer to avoid re-entrancy attack
        $._claimedDividend[tokenHolder][time] = true;
        emit DividendClaimed(time, tokenHolder, tokenHolderDividend);
        // transfer
        // We don't revert if SenderBalance == 0 to record the claim
        if(tokenHolderDividend != 0){
            // Will revert in case of failure
            $._ERC20TokenPayment.safeTransfer(tokenHolder, tokenHolderDividend);
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
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        $._snapshotEngine = snapshotEngine_;
        emit SnapshotEngineSet(snapshotEngine_);
    }

    /**
    * @notice Sets the ERC-20 token used to pay the dividends
    * @dev reverts if `ERC20TokenPayment_` is the zero address
    * @param ERC20TokenPayment_ the payment token
    */
    function _setERC20TokenPayment(IERC20 ERC20TokenPayment_) internal virtual {
        if(address(ERC20TokenPayment_) == address(0)){
            revert IncomeVault_TokenPaymentWithAddressZeroNotAllowed();
        }
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        $._ERC20TokenPayment = ERC20TokenPayment_;
        emit ERC20TokenPaymentSet(ERC20TokenPayment_);
    }

    /**
    * @notice Sets the delay, after the dividend time, during which a claim is still accepted
    * @param timeLimitToWithdraw_ the delay in seconds
    */
    function _setTimeLimitToWithdraw(uint256 timeLimitToWithdraw_) internal virtual {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        $._timeLimitToWithdraw = timeLimitToWithdraw_;
        emit TimeLimitToWithdrawSet(timeLimitToWithdraw_);
    }

    /**
    * @notice Opens or closes the claims for a dividend time
    * @param time the dividend time
    * @param status true when the token holders can claim
    */
    function _setStatusClaim(uint256 time, bool status) internal virtual {
        IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
        $._segregatedClaim[time] = status;
        emit ClaimStatusSet(time, status);
    }

    /* ============ View functions ============ */
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
        uint256 dividendTotalSupply = segregatedDividend(time);
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
        uint256 dividendTotalSupply = segregatedDividend(time);

        tokenHolderDividend = (senderBalance * dividendTotalSupply) / tokenTotalSupply;
    }

    /* ============ ERC-7201 ============ */
    /**
    * @dev Returns the ERC-7201 namespaced storage of the IncomeVault
    * @return $ the storage struct
    */
    function _getIncomeVaultInternalStorage() internal pure returns (IncomeVaultInternalStorage storage $) {
        assembly {
            $.slot := IncomeVaultInternalStorageLocation
        }
    }
}
