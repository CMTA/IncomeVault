// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== CMTAT modules === */
import {AccessControlModule} from "CMTAT/modules/wrapper/security/AccessControlModule.sol";
import {PauseModule} from "CMTAT/modules/wrapper/core/PauseModule.sol";
import {EnforcementModule} from "CMTAT/modules/wrapper/core/EnforcementModule.sol";
import {ValidationModuleRuleEngineInternal} from "CMTAT/modules/internal/ValidationModuleRuleEngineInternal.sol";
/* ==== CMTAT engine === */
import {IRuleEngine, IRuleEngineERC1404} from "CMTAT/interfaces/engine/IRuleEngine.sol";
/* ==== IncomeVault === */
import {IncomeVaultInvariantStorage} from "../libraries/IncomeVaultInvariantStorage.sol";

/**
* @title Validation module of the IncomeVault
* @dev
* A dividend payout is treated as a transfer from the vault to the token holder and can be
* restricted the same way a CMTAT transfer is:
*
* - the vault can be put in the pause state ({PauseModule}),
* - an address can be frozen ({EnforcementModule}),
* - an optional {IRuleEngine} can apply arbitrary rules (allowlist, blocklist, sanction list, ...).
*
* Unlike the CMTAT, the vault is not a token bound to the RuleEngine: it only uses the *view*
* entry point {IRuleEngine-canTransfer}. `transferred()` is restricted to bound tokens by the
* RuleEngine and would revert here, and a payout is not a movement of the security token, so it
* must not update the stateful rules of the engine.
*/
abstract contract IncomeVaultValidationModule is
    AccessControlModule,
    PauseModule,
    EnforcementModule,
    ValidationModuleRuleEngineInternal,
    IncomeVaultInvariantStorage
{
    /* ============  Initializer Function ============ */
    /**
    * @notice Initializes the validation module
    * @param ruleEngine_ the RuleEngine applied to the payouts, or the zero address for none
    */
    function __IncomeVaultValidation_init_unchained(
        IRuleEngine ruleEngine_
    ) internal onlyInitializing {
        ValidationModuleRuleEngineInternal.__ValidationRuleEngine_init_unchained(ruleEngine_);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State functions ============ */
    /**
    * @notice Updates the RuleEngine applied to the dividend payouts.
    * @param ruleEngine_ the new RuleEngine, or the zero address to disable the rule checks
    * @custom:access-control
    * - the caller must have the `DEFAULT_ADMIN_ROLE`.
    */
    function setRuleEngine(
        IRuleEngine ruleEngine_
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        if(address(ruleEngine_) == address(ruleEngine())){
            revert IncomeVault_SameValue();
        }
        _setRuleEngine(ruleEngine_);
    }

    /* ============ View functions ============ */
    /**
    * @notice Returns true if the vault is allowed to pay `value` to `to`.
    * @param from the address sending the payment, always the vault itself
    * @param to the token holder receiving the dividends
    * @param value the amount of payment token
    * @return True if the pause, freeze and RuleEngine checks all allow the payout
    */
    function canTransfer(
        address from,
        address to,
        uint256 value
    ) public view virtual returns (bool) {
        if(PauseModule.paused()){
            return false;
        }
        if(EnforcementModule.isFrozen(from) || EnforcementModule.isFrozen(to)){
            return false;
        }
        IRuleEngine ruleEngine_ = ruleEngine();
        if(address(ruleEngine_) != address(0)){
            return ruleEngine_.canTransfer(from, to, value);
        }
        return true;
    }

    /**
    * @notice ERC-1404 restriction code returned by the RuleEngine for a payout from the vault.
    * @dev Returns `0` (no restriction) when no RuleEngine is set. The pause and freeze states are
    * not reflected here, only the rules: use {canTransfer} for the complete answer.
    * @param from the address sending the payment, always the vault itself
    * @param to the token holder receiving the dividends
    * @param value the amount of payment token
    * @return The ERC-1404 restriction code, `0` when the rules allow the payout
    */
    function detectTransferRestriction(
        address from,
        address to,
        uint256 value
    ) public view virtual returns (uint8) {
        IRuleEngine ruleEngine_ = ruleEngine();
        if(address(ruleEngine_) == address(0)){
            return 0;
        }
        return IRuleEngineERC1404(address(ruleEngine_)).detectTransferRestriction(from, to, value);
    }

    /**
    * @notice Human readable message matching a code returned by {detectTransferRestriction}.
    * @param restrictionCode the ERC-1404 restriction code to translate
    * @return The message associated with `restrictionCode`
    */
    function messageForTransferRestriction(
        uint8 restrictionCode
    ) public view virtual returns (string memory) {
        IRuleEngine ruleEngine_ = ruleEngine();
        if(address(ruleEngine_) == address(0)){
            return "No restriction";
        }
        return IRuleEngineERC1404(address(ruleEngine_)).messageForTransferRestriction(restrictionCode);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ Access Control ============ */
    /**
    * @inheritdoc PauseModule
    */
    function _authorizePause() internal virtual override(PauseModule) onlyRole(PAUSER_ROLE) {
        // Nothing to do
    }

    /**
    * @inheritdoc PauseModule
    */
    function _authorizeDeactivate() internal virtual override(PauseModule) onlyRole(DEFAULT_ADMIN_ROLE) {
        // Nothing to do
    }

    /**
    * @inheritdoc EnforcementModule
    */
    function _authorizeFreeze() internal virtual override(EnforcementModule) onlyRole(ENFORCER_ROLE) {
        // Nothing to do
    }

    /* ============ View functions ============ */
    /**
    * @dev reverts if the payout of `value` from the vault to `to` is forbidden
    * @param from the address sending the payment, always the vault itself
    * @param to the token holder receiving the dividends
    * @param value the amount of payment token
    */
    function _validateTransfer(address from, address to, uint256 value) internal view virtual {
        if(!canTransfer(from, to, value)){
            revert IncomeVault_InvalidTransfer(from, to, value);
        }
    }
}
