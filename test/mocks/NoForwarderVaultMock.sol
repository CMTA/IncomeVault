// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {IncomeVaultBase} from "../../src/IncomeVaultBase.sol";
import {IncomeVaultValidationCore} from "../../src/modules/IncomeVaultValidationCore.sol";
import {IncomeVaultRestricted} from "../../src/public/IncomeVaultRestricted.sol";
import {IncomeVaultSnapshotModule} from "../../src/modules/IncomeVaultSnapshotModule.sol";
import {ISnapshotSource} from "../../src/interfaces/ISnapshotSource.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
* @title A deployment with no trusted forwarder — finding M-8
* @dev
* Inherits {IncomeVaultBase} directly instead of {IncomeVaultBaseERC2771}, so it carries no ERC-2771
* context: no immutable forwarder in the bytecode, no calldata-suffix handling, and `_msgSender()` is
* plain `msg.sender` with nothing able to override it.
*
* Before M-8 this contract could not exist. `ERC2771Module` was inherited by the base itself, so every
* deployment carried a forwarder whether it wanted one or not; opting out meant passing the zero
* address and still paying for the machinery. Gasless support is now a deployment decision, exactly
* like the access-control model and the transfer-restriction policy.
*
* Access control is left open because the point is the *shape* of the dependency, not the policy.
*/
contract NoForwarderVaultMock is IncomeVaultBase {
    // NOTE: no `_disableInitializers()` here, unlike the shipped deployments. This double is deployed
    // directly by the test rather than behind a proxy, because what it demonstrates is the absence of
    // the ERC-2771 context, not the upgrade pattern.

    /**
    * @notice Wire up a vault with no meta-transaction support
    * @param paymentToken the ERC-20 the dividends are paid in
    * @param snapshotSource where the holder balances come from
    * @param timeLimitToWithdraw_ the claim window length
    */
    function initialize(IERC20 paymentToken, ISnapshotSource snapshotSource, uint256 timeLimitToWithdraw_)
        public
        initializer
    {
        __IncomeVaultBase_init_unchained(paymentToken, snapshotSource, timeLimitToWithdraw_);
    }

    /**
    * @inheritdoc IncomeVaultValidationCore
    * @dev Stands in for whatever policy a real deployment would choose. Always allows.
    */
    function _validateTransfer(address, address, uint256) internal view virtual override {}

    /// @inheritdoc IncomeVaultRestricted
    function _authorizeDeposit() internal view virtual override {}
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeWithdraw() internal view virtual override {}
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeDistribute() internal view virtual override {}
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeOperator() internal view virtual override {}
    /// @inheritdoc IncomeVaultSnapshotModule
    function _authorizeSnapshotSourceManagement() internal view virtual override {}
}
