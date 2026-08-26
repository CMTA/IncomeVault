// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== OpenZeppelin === */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC7741} from "../interfaces/IERC7741.sol";
import {IIncomeVault} from "../interfaces/IIncomeVault.sol";
/* ==== CMTAT === */
import {AccessControlModule} from "CMTAT/modules/wrapper/security/AccessControlModule.sol";
import {PauseModule} from "CMTAT/modules/wrapper/core/PauseModule.sol";
import {EnforcementModule} from "CMTAT/modules/wrapper/core/EnforcementModule.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
/* ==== Snapshot === */
import {ISnapshotSource} from "../interfaces/ISnapshotSource.sol";
/* ==== IncomeVault === */
import {IncomeVaultBaseERC2771} from "../IncomeVaultBaseERC2771.sol";
import {IncomeVaultValidationModule} from "../modules/IncomeVaultValidationModule.sol";
import {IncomeVaultRestricted} from "../public/IncomeVaultRestricted.sol";
import {IncomeVaultSnapshotModule} from "../modules/IncomeVaultSnapshotModule.sol";
import {IncomeVaultValidationModule} from "../modules/IncomeVaultValidationModule.sol";
import {IncomeVaultRolesStorage} from "../storage/IncomeVaultRolesStorage.sol";

/**
 * @title Income Vault to distribute dividends — role-based deployment
 * @dev
 * Answers **who** may do what: every authorization hook of {IncomeVaultBase} is overridden with the
 * role that gates it. Suited to institutional operations, where funding the vault, withdrawing from
 * it and running the claim window are held by different accounts.
 *
 * Note the CMTAT `AccessControlModule` treats `DEFAULT_ADMIN_ROLE` as implicitly holding every role:
 * the admin passes every `hasRole` check but does **not** appear in role enumerations, so an
 * off-chain tool listing role holders will not see them. Role separation therefore constrains the
 * operators, never the admin.
 */
contract IncomeVault is
    IncomeVaultValidationModule,
    IncomeVaultBaseERC2771,
    AccessControlModule,
    IncomeVaultRolesStorage
{
    /**
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address forwarderIrrevocable) IncomeVaultBaseERC2771(forwarderIrrevocable) {
        // Disable the possibility to initialize the implementation
        _disableInitializers();
    }

    /**
     * @notice
     * initialize the proxy contract
     * The calls to this function will revert if the contract was deployed without a proxy
     * @param admin Address of the contract (Access Control)
     * @param ERC20TokenPayment_ ERC20 token used to perform the payment
     * @param snapshotSource_ contract implementing {ISnapshotSource}, source of the holder balances
     * @param ruleEngine_ optional RuleEngine applied to the payouts, or the zero address
     * @param timeLimitToWithdraw_ delay, after the dividend time, during which a claim is accepted
     */
    function initialize(
        address admin,
        IERC20 ERC20TokenPayment_,
        ISnapshotSource snapshotSource_,
        IRuleEngine ruleEngine_,
        uint256 timeLimitToWithdraw_
    ) public initializer {
        if (admin == address(0)) {
            revert IncomeVault_AdminWithAddressZeroNotAllowed();
        }
        __AccessControl_init_unchained();
        __AccessControlModule_init_unchained(admin);
        // the validation answer this deployment chose
        __Pausable_init_unchained();
        __IncomeVaultValidation_init_unchained(ruleEngine_);
        __IncomeVaultBase_init_unchained(ERC20TokenPayment_, snapshotSource_, timeLimitToWithdraw_);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ ERC-165 ============ */
    /**
     * @notice ERC-165 interface detection
     * @dev Adds ERC-7741, whose specification requires a contract implementing it to answer `true`
     * for `0xa9e50872`. The ERC-7540 operator id is deliberately **not** advertised — this is not an
     * asynchronous vault; see {IERC7540Operator}.
     * @param interfaceId The interface identifier to check
     * @return True if the interface is supported, false otherwise
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IIncomeVault).interfaceId || interfaceId == type(IERC7741).interfaceId
            || AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    /* ============ ERC-2771 / Context disambiguation ============ */
    /**
     * @inheritdoc IncomeVaultBaseERC2771
     */
    function _msgSender()
        internal
        view
        virtual
        override(IncomeVaultBaseERC2771, ContextUpgradeable)
        returns (address sender)
    {
        return IncomeVaultBaseERC2771._msgSender();
    }

    /**
     * @inheritdoc IncomeVaultBaseERC2771
     */
    function _msgData()
        internal
        view
        virtual
        override(IncomeVaultBaseERC2771, ContextUpgradeable)
        returns (bytes calldata)
    {
        return IncomeVaultBaseERC2771._msgData();
    }

    /**
     * @inheritdoc IncomeVaultBaseERC2771
     */
    function _contextSuffixLength()
        internal
        view
        virtual
        override(IncomeVaultBaseERC2771, ContextUpgradeable)
        returns (uint256)
    {
        return IncomeVaultBaseERC2771._contextSuffixLength();
    }

    /* ============ Access Control ============ */
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeDeposit() internal view virtual override onlyRole(INCOME_VAULT_DEPOSIT_ROLE) {}

    /// @inheritdoc IncomeVaultRestricted
    function _authorizeWithdraw() internal view virtual override onlyRole(INCOME_VAULT_WITHDRAW_ROLE) {}

    /// @inheritdoc IncomeVaultRestricted
    function _authorizeDistribute() internal view virtual override onlyRole(INCOME_VAULT_DISTRIBUTE_ROLE) {}

    /// @inheritdoc IncomeVaultRestricted
    function _authorizeOperator() internal view virtual override onlyRole(INCOME_VAULT_OPERATOR_ROLE) {}

    /// @inheritdoc IncomeVaultSnapshotModule
    function _authorizeSnapshotSourceManagement() internal view virtual override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @inheritdoc IncomeVaultValidationModule
    function _authorizeRuleEngineManagement() internal view virtual override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @inheritdoc PauseModule
    function _authorizePause() internal view virtual override(PauseModule) onlyRole(PAUSER_ROLE) {}

    /// @inheritdoc PauseModule
    function _authorizeDeactivate() internal view virtual override(PauseModule) onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @inheritdoc EnforcementModule
    function _authorizeFreeze() internal view virtual override(EnforcementModule) onlyRole(ENFORCER_ROLE) {}
}
