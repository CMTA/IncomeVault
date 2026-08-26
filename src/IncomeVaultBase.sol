// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== OpenZeppelin === */
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/* ==== CMTAT === */
/* ==== Snapshot === */
import {ISnapshotSource} from "./interfaces/ISnapshotSource.sol";
/* ==== IncomeVault === */
import {IncomeVaultValidationCore} from "./modules/IncomeVaultValidationCore.sol";
import {IncomeVaultSnapshotModule} from "./modules/IncomeVaultSnapshotModule.sol";
import {IncomeVaultRestricted} from "./public/IncomeVaultRestricted.sol";
import {IncomeVaultOpen} from "./public/IncomeVaultOpen.sol";
import {VersionModule} from "./modules/VersionModule.sol";

/**
 * @title Income Vault to distribute dividends — logic shared by every deployment variant
 * @dev
 * The vault is not bound to a specific token implementation: the holder balances and the total
 * supply are read through the {ISnapshotSource} interface, which is implemented by the CMTA
 * `SnapshotEngine` as well as by any token embedding an equivalent snapshot module.
 *
 * This contract holds **what** the vault does. It deliberately declares neither an access-control
 * policy nor a transfer-restriction policy: the `_authorize*` hooks and
 * {IncomeVaultValidationCore-_validateTransfer} are left abstract and answered by the deployment
 * contract, so the same logic ships role-based ({IncomeVault}) or single-owner
 * ({IncomeVaultOwnable2Step}) — and can be embedded in a host that answers them from its own modules.
 *
 * It also declares **no meta-transaction policy**. Gasless support is a deployment decision, exactly
 * like the access-control model: {IncomeVaultBaseERC2771} adds the ERC-2771 context on top of this
 * contract, and the two shipped deployments inherit that. A deployment that does not want a trusted
 * forwarder inherits this contract directly and pays for none of it. Finding M-8.
 */
abstract contract IncomeVaultBase is
    IncomeVaultValidationCore,
    Initializable,
    ContextUpgradeable,
    VersionModule,
    IncomeVaultSnapshotModule,
    IncomeVaultRestricted,
    IncomeVaultOpen
{
    /* ============  Initializer Function ============ */
    /**
     * @dev calls the initialize functions of the policy-agnostic modules
     * @param ERC20TokenPayment_ ERC20 token used to perform the payment
     * @param snapshotSource_ contract implementing {ISnapshotSource}, source of the holder balances
     * @param timeLimitToWithdraw_ delay, after the dividend time, during which a claim is accepted
     */
    function __IncomeVaultBase_init_unchained(
        IERC20 ERC20TokenPayment_,
        ISnapshotSource snapshotSource_,
        uint256 timeLimitToWithdraw_
    ) internal onlyInitializing {
        _setERC20TokenPayment(ERC20TokenPayment_);
        _setDividendSnapshotSource(snapshotSource_);

        // EIP-712 domain for the ERC-7741 signed operator authorisations. The version stays "1"
        // across releases on purpose: bumping it would invalidate every signature already issued.
        __EIP712_init_unchained("IncomeVault", "1");
        __IncomeVaultRestricted_init_unchained(timeLimitToWithdraw_);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
}
