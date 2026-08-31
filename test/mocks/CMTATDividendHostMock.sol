// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {CMTATUpgradeableInternalSnapshot} from "SnapshotEngine/deployment/CMTATUpgradeableInternalSnapshot.sol";
import {IncomeVaultOpen} from "../../src/public/IncomeVaultOpen.sol";
import {IncomeVaultRestricted} from "../../src/public/IncomeVaultRestricted.sol";
import {IncomeVaultValidationCore} from "../../src/modules/IncomeVaultValidationCore.sol";
import {IncomeVaultSnapshotCore} from "../../src/modules/IncomeVaultSnapshotCore.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title A CMTAT with internal snapshots that pays its own dividends — findings M-1 and M-2
 * @dev
 * This is the scenario the modularity review was written against: a token that already has a
 * validation stack and already records snapshots, embedding the distribution logic directly rather
 * than deploying a separate vault beside it.
 *
 * Two things had to change before this file could exist, and it is the regression guard for both:
 *
 * - **M-1.** `IncomeVaultOpen` and `IncomeVaultRestricted` used to drag CMTAT's `PauseModule` and
 *   `EnforcementModule` in transitively, so a host that already had them could not linearize —
 *   `Error (5005)`, which no override can repair. They now depend on {IncomeVaultValidationCore},
 *   which inherits nothing, and this contract answers it with the CMTAT's own `canTransfer`.
 * - **M-2.** The snapshot source used to be a stored address behind a `snapshotEngine()` getter,
 *   which collided with the identically-named CMTAT getter that returns a *different type* — a
 *   collision no override list can resolve. It is now {IncomeVaultSnapshotCore}, three hooks that
 *   this contract answers **from its own snapshot records**, with no external contract and nothing
 *   stored.
 *
 * It only has to compile. Re-couple either dependency and this file stops compiling.
 */
contract CMTATDividendHostMock is CMTATUpgradeableInternalSnapshot, IncomeVaultOpen, IncomeVaultRestricted {
    /// @notice Raised when the CMTAT's own validation stack rejects a payout
    error CMTATDividendHost_InvalidTransfer(address from, address to, uint256 value);

    /* ============ the host IS its own snapshot source — finding M-2 ============ */
    /**
     * @inheritdoc IncomeVaultSnapshotCore
     * @dev Answered from the CMTAT's own snapshot records, not from an external engine.
     */
    function _snapshotInfo(uint256 time, address tokenHolder)
        internal
        view
        virtual
        override
        returns (uint256, uint256)
    {
        return snapshotInfo(time, tokenHolder);
    }

    /// @inheritdoc IncomeVaultSnapshotCore
    function _snapshotInfoBatch(uint256 time, address[] calldata addresses)
        internal
        view
        virtual
        override
        returns (uint256[] memory, uint256)
    {
        return snapshotInfoBatch(time, addresses);
    }

    /**
     * @inheritdoc IncomeVaultSnapshotCore
     * @dev The CMTAT overload takes `addresses` in calldata while this hook receives it in memory, so
     * the rows are assembled here rather than forwarded. The answers still come from the same records.
     */
    function _snapshotInfoBatch(uint256[] calldata times, address[] memory addresses)
        internal
        view
        virtual
        override
        returns (uint256[][] memory balances, uint256[] memory supplies)
    {
        balances = new uint256[][](times.length);
        supplies = new uint256[](times.length);
        for (uint256 t = 0; t < times.length; ++t) {
            uint256[] memory row = new uint256[](addresses.length);
            uint256 supply;
            for (uint256 i = 0; i < addresses.length; ++i) {
                (row[i], supply) = snapshotInfo(times[t], addresses[i]);
            }
            balances[t] = row;
            supplies[t] = supply;
        }
    }

    /* ============ the host answers the validation question itself — finding M-1 ============ */
    /**
     * @inheritdoc IncomeVaultValidationCore
     * @dev Delegates to the CMTAT's own pause, freeze and RuleEngine stack. No second copy of it.
     */
    function _validateTransfer(address from, address to, uint256 value) internal view virtual override {
        require(canTransfer(from, to, value), CMTATDividendHost_InvalidTransfer(from, to, value));
    }

    /* ============ Access control — open, the shape is the point ============ */
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeDeposit() internal view virtual override {}
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeWithdraw() internal view virtual override {}
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeDistribute() internal view virtual override {}
    /// @inheritdoc IncomeVaultRestricted
    function _authorizeOperator() internal view virtual override {}
}
