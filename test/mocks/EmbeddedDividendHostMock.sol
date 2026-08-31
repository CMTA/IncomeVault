// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {IncomeVaultOpen} from "../../src/public/IncomeVaultOpen.sol";
import {IncomeVaultRestricted} from "../../src/public/IncomeVaultRestricted.sol";
import {IncomeVaultValidationCore} from "../../src/modules/IncomeVaultValidationCore.sol";
import {IncomeVaultSnapshotCore} from "../../src/modules/IncomeVaultSnapshotCore.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title A host that embeds the dividend logic without any CMTAT at all — findings M-1 and M-2
 * @dev
 * This contract is the regression guard for the two modularity splits, and it only has to **compile**.
 *
 * Before M-1, `IncomeVaultOpen` and `IncomeVaultRestricted` each inherited CMTAT's `PauseModule` and
 * `EnforcementModule` transitively, so a host that already had its own could not embed them —
 * `Error (5005)`, linearization impossible, which no override can repair. Before M-2, the snapshot
 * source was a stored address behind a `snapshotEngine()` getter that a host could not replace.
 *
 * It answers the questions the payout paths ask, and nothing more:
 *
 * - {IncomeVaultValidationCore-_validateTransfer} — here, a trivial "always allowed" policy standing in
 *   for whatever the host already owns;
 * - the three {IncomeVaultSnapshotCore} hooks — answered **from the host itself**, with no external
 *   snapshot contract and no stored address, which is the M-2 property;
 * - the four `_authorize*` hooks — here, open, because the point is the *shape* of the dependency, not
 *   the policy.
 *
 * Re-couple either dependency to a concrete implementation and this file stops compiling.
 * {CMTATDividendHostMock} is the same guard for a host that *is* a CMTAT with internal snapshots.
 */
contract EmbeddedDividendHostMock is IncomeVaultOpen, IncomeVaultRestricted {
    /// @dev stands in for whatever balances the host already records
    uint256 public constant HOLDER_BALANCE = 100;
    /// @dev stands in for the host's own total supply
    uint256 public constant TOTAL_SUPPLY = 400;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Wire up the embedded dividend logic
     * @param paymentToken the ERC-20 the dividends are paid in
     * @param timeLimitToWithdraw_ the claim window length
     */
    function initialize(IERC20 paymentToken, uint256 timeLimitToWithdraw_) public initializer {
        _setERC20TokenPayment(paymentToken);
        __IncomeVaultRestricted_init_unchained(timeLimitToWithdraw_);
    }

    /* ============ the host IS its own snapshot source — finding M-2 ============ */
    /// @inheritdoc IncomeVaultSnapshotCore
    function _snapshotInfo(uint256, address) internal pure virtual override returns (uint256, uint256) {
        return (HOLDER_BALANCE, TOTAL_SUPPLY);
    }

    /// @inheritdoc IncomeVaultSnapshotCore
    function _snapshotInfoBatch(uint256, address[] calldata addresses)
        internal
        pure
        virtual
        override
        returns (uint256[] memory balances, uint256)
    {
        balances = new uint256[](addresses.length);
        for (uint256 i = 0; i < addresses.length; ++i) {
            balances[i] = HOLDER_BALANCE;
        }
        return (balances, TOTAL_SUPPLY);
    }

    /// @inheritdoc IncomeVaultSnapshotCore
    function _snapshotInfoBatch(uint256[] calldata times, address[] memory addresses)
        internal
        pure
        virtual
        override
        returns (uint256[][] memory balances, uint256[] memory supplies)
    {
        balances = new uint256[][](times.length);
        supplies = new uint256[](times.length);
        for (uint256 t = 0; t < times.length; ++t) {
            uint256[] memory row = new uint256[](addresses.length);
            for (uint256 i = 0; i < addresses.length; ++i) {
                row[i] = HOLDER_BALANCE;
            }
            balances[t] = row;
            supplies[t] = TOTAL_SUPPLY;
        }
    }

    /* ============ the host answers the validation question itself — finding M-1 ============ */
    /**
     * @inheritdoc IncomeVaultValidationCore
     * @dev Stands in for whatever policy the host already owns. Always allows.
     */
    function _validateTransfer(address, address, uint256) internal view virtual override {}

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
