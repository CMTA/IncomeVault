// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {IncomeVaultOpen} from "../../src/public/IncomeVaultOpen.sol";
import {IncomeVaultRestricted} from "../../src/public/IncomeVaultRestricted.sol";
import {ISnapshotSource} from "../../src/interfaces/ISnapshotSource.sol";
import {IncomeVaultValidationCore} from "../../src/modules/IncomeVaultValidationCore.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
* @title A host that embeds the dividend logic without any CMTAT validation stack — finding M-1
* @dev
* This contract is the regression guard for the M-1 split, and it only has to **compile**: before it,
* `IncomeVaultOpen` and `IncomeVaultRestricted` each inherited CMTAT's `PauseModule` and
* `EnforcementModule` transitively, so a host that already had its own could not embed them —
* `Error (5005)`, linearization impossible, which no override can repair.
*
* It answers the two questions the payout paths ask and nothing more:
*
* - {IncomeVaultValidationCore-_validateTransfer} — here, a trivial "always allowed" policy standing in
*   for whatever the host already owns;
* - the eight `_authorize*` hooks — here, open, because the point is the *shape* of the dependency, not
*   the policy.
*
* Re-couple the payout paths to a concrete validation stack and this file stops compiling.
*/
contract EmbeddedDividendHostMock is IncomeVaultOpen, IncomeVaultRestricted {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
    * @notice Wire up the embedded dividend logic
    * @param paymentToken the ERC-20 the dividends are paid in
    * @param snapshotSource where the holder balances come from
    * @param timeLimitToWithdraw_ the claim window length
    */
    function initialize(IERC20 paymentToken, ISnapshotSource snapshotSource, uint256 timeLimitToWithdraw_)
        public initializer
    {
        _setERC20TokenPayment(paymentToken);
        _setSnapshotEngine(snapshotSource);
        __IncomeVaultRestricted_init_unchained(timeLimitToWithdraw_);
    }

    /* ============ the host's own answers ============ */
    /// @inheritdoc IncomeVaultValidationCore
    function _validateTransfer(address, address, uint256) internal view virtual override {
        // a real host would delegate to its own pause / freeze / compliance modules here
    }

    /// @inheritdoc IncomeVaultRestricted
    function _authorizeDeposit() internal view virtual override {}
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeWithdraw() internal view virtual override {}
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeDistribute() internal view virtual override {}
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeOperator() internal view virtual override {}
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeSnapshotEngineManagement() internal view virtual override {}
}
