// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== CMTAT modules === */
import {PauseModule} from "CMTAT/modules/wrapper/core/PauseModule.sol";
import {EnforcementModule} from "CMTAT/modules/wrapper/core/EnforcementModule.sol";
import {ValidationModuleRuleEngineInternal} from "CMTAT/modules/internal/ValidationModuleRuleEngineInternal.sol";
/* ==== CMTAT engine === */
import {IRuleEngine, IRuleEngineERC1404} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
/* ==== IncomeVault === */
import {IncomeVaultInvariantStorage} from "../storage/IncomeVaultInvariantStorage.sol";
import {IncomeVaultValidationCore} from "./IncomeVaultValidationCore.sol";

/**
* @title The standalone vault's answer to {IncomeVaultValidationCore}
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
    IncomeVaultValidationCore,
    PauseModule,
    EnforcementModule,
    ValidationModuleRuleEngineInternal,
    IncomeVaultInvariantStorage
{
    /* ============ State variables ============ */
    /**
    * @dev Human-readable answers for {messageForTransferRestriction}. The strings are CMTAT's
    * (`ValidationModuleERC1404`) verbatim, so an operator console written against a CMTAT reads a
    * payout refusal exactly as it reads a transfer refusal. The codes are CMTAT's
    * `REJECTED_CODE_BASE`, for the same reason.
    */
    string internal constant TEXT_TRANSFER_OK = "NoRestriction";
    /// @dev Returned when no configured source claims the code
    string internal constant TEXT_UNKNOWN_CODE = "UnknownCode";
    /// @dev The vault is paused
    string internal constant TEXT_TRANSFER_REJECTED_PAUSED = "EnforcedPause";
    /// @dev The vault has been permanently deactivated
    string internal constant TEXT_TRANSFER_REJECTED_DEACTIVATED = "ContractDeactivated";
    /// @dev The paying address is frozen
    string internal constant TEXT_TRANSFER_REJECTED_FROM_FROZEN = "AddrFromIsFrozen";
    /// @dev The receiving token holder is frozen
    string internal constant TEXT_TRANSFER_REJECTED_TO_FROZEN = "AddrToIsFrozen";

    /* ============ Modifier ============ */
    /// @dev Restricts the management of the RuleEngine
    modifier onlyRuleEngineManager() {
        _authorizeRuleEngineManagement();
        _;
    }

    /* ============  Initializer Function ============ */
    /**
    * @notice Initializes the validation module
    * @dev Writes the RuleEngine slot that CMTAT's {ValidationModuleRuleEngineInternal} owns, at its
    * hardcoded ERC-7201 location. In the standalone vault that slot belongs to this contract alone. In
    * a host that also inherits a CMTAT validation stack it is **shared**, so a non-zero `ruleEngine_`
    * here would replace the *token's* compliance engine from the dividend initializer. Such a host must
    * pass the zero address, which CMTAT's initializer treats as a no-op, and keep the engine the token
    * already configured. Embedding the payout logic via {IncomeVaultValidationCore} instead avoids the
    * question entirely, and is the supported route. Finding M-4.
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
    */
    function setRuleEngine(
        IRuleEngine ruleEngine_
    ) public virtual onlyRuleEngineManager {
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
    * @notice ERC-1404 restriction code for a payout from the vault, or `0` when it would be accepted.
    * @dev Answers for the **whole** payout decision, in the same order {canTransfer} evaluates it:
    * deactivation, pause, either party frozen, then the RuleEngine. The codes are CMTAT's
    * `REJECTED_CODE_BASE`, so a caller written against a CMTAT reads them unchanged.
    *
    * This returns `0` exactly when {canTransfer} returns true, and the two must not be allowed to
    * drift apart: consulting only the RuleEngine here would report a paused vault or a frozen holder as
    * unrestricted, and the claim would then revert.
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
        // Deactivation implies pause, so the more specific code is tested first.
        if(PauseModule.deactivated()){
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_REJECTED_DEACTIVATED);
        }
        if(PauseModule.paused()){
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_REJECTED_PAUSED);
        }
        if(EnforcementModule.isFrozen(from)){
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_REJECTED_FROM_FROZEN);
        }
        if(EnforcementModule.isFrozen(to)){
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_REJECTED_TO_FROZEN);
        }
        IRuleEngine ruleEngine_ = ruleEngine();
        if(address(ruleEngine_) == address(0)){
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
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
        if(restrictionCode == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK)){
            return TEXT_TRANSFER_OK;
        }
        if(restrictionCode == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_REJECTED_DEACTIVATED)){
            return TEXT_TRANSFER_REJECTED_DEACTIVATED;
        }
        if(restrictionCode == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_REJECTED_PAUSED)){
            return TEXT_TRANSFER_REJECTED_PAUSED;
        }
        if(restrictionCode == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_REJECTED_FROM_FROZEN)){
            return TEXT_TRANSFER_REJECTED_FROM_FROZEN;
        }
        if(restrictionCode == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_REJECTED_TO_FROZEN)){
            return TEXT_TRANSFER_REJECTED_TO_FROZEN;
        }
        IRuleEngine ruleEngine_ = ruleEngine();
        if(address(ruleEngine_) == address(0)){
            // The vault answers for its own codes above; anything else could only have come from a
            // RuleEngine, and there is none. Saying "no restriction" here would repeat the defect
            // this function's siblings were fixed for.
            return TEXT_UNKNOWN_CODE;
        }
        return IRuleEngineERC1404(address(ruleEngine_)).messageForTransferRestriction(restrictionCode);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ Access Control ============ */
    /**
    * @dev Authorization hook invoked before {setRuleEngine}.
    * Implemented by the deployment contract with the desired access-control policy.
    *
    * @dev CMTAT's {ValidationModuleRuleEngine} declares a hook with this same name and parameters.
    * That is **not** a collision to be renamed away: both this module and CMTAT's wrapper sit on the
    * same {ValidationModuleRuleEngineInternal}, whose ERC-7201 slot is a hardcoded constant, so a
    * contract inheriting both has exactly **one** RuleEngine. One capability, therefore one hook — and
    * a single override answering both declarations is the correct resolution, not an accident. Giving
    * the two hooks different names would create two doors to one slot, each able to carry a different
    * policy, and the weaker one would win. See finding M-4.
    */
    function _authorizeRuleEngineManagement() internal view virtual;

    /* ============ View functions ============ */
    /**
    * @inheritdoc IncomeVaultValidationCore
    * @dev The standalone vault's answer: its own pause state, the frozen status of both parties, and
    * the RuleEngine if one is configured.
    */
    function _validateTransfer(address from, address to, uint256 value)
        internal view virtual override(IncomeVaultValidationCore)
    {
        if(!canTransfer(from, to, value)){
            revert IncomeVault_InvalidTransfer(from, to, value);
        }
    }
}
