// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== IncomeVault === */
import {ISnapshotSource} from "../interfaces/ISnapshotSource.sol";
import {IncomeVaultInternal} from "../libraries/IncomeVaultInternal.sol";
import {IncomeVaultSnapshotCore} from "./IncomeVaultSnapshotCore.sol";

/**
* @title The standalone vault's answer to {IncomeVaultSnapshotCore} — an external source
* @dev
* Holds an {ISnapshotSource} and forwards the three queries to it. This is what the deployable vault
* uses; a host that is itself the snapshot source overrides the hooks instead and never inherits this
* module.
*
* The getter is deliberately **not** called `snapshotEngine()`. CMTAT's `ISnapshotEngineModule`
* declares `snapshotEngine() returns (ISnapshotEngine)`, and a same-name, same-parameter function with
* a *different return type* cannot be reconciled by any override — a contract inheriting both simply
* does not compile. Naming this after the capability rather than the generic concept removes the
* collision entirely.
*/
abstract contract IncomeVaultSnapshotModule is IncomeVaultSnapshotCore, IncomeVaultInternal {
    /* ============ Modifier ============ */
    /// @dev Restricts the replacement of the snapshot source
    modifier onlySnapshotSourceManager() {
        _authorizeSnapshotSourceManagement();
        _;
    }

    /* ============ ERC-7201 ============ */
    /**
    * @dev Slot holding the ERC-7201 namespaced storage of this module, derived as
    * keccak256(abi.encode(uint256(keccak256("IncomeVault.storage.SnapshotSource")) - 1)) & ~bytes32(uint256(0xff))
    * The derivation is re-checked in `test/SnapshotSource.t.sol`.
    */
    bytes32 private constant SnapshotSourceStorageLocation =
        0x45a69a32b5b7efb4ae8ac48e2427653ef15920a29875121a072e6b49aaccac00;

    /* ==== ERC-7201 State Variables === */
    /// @custom:storage-location erc7201:IncomeVault.storage.SnapshotSource
    struct SnapshotSourceStorage {
        // Where the holder balances are read from
        ISnapshotSource _source;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State functions ============ */
    /**
    * @notice Replace the contract the vault reads the holder balances from
    * @dev
    * Only accepted while **no claim period is open** — `openClaimCount()` must be zero. Changing the
    * source under an open period would silently re-price every unclaimed dividend of that period,
    * because the amounts are computed from the source at claim time, not fixed at deposit.
    *
    * @custom:security The restriction narrows the hazard, it does not remove it: entitlements resolve
    * against whichever source is configured *when the claim happens*, so re-opening a past `time`
    * after a swap resolves it against the new source. Holders who already claimed are protected;
    * holders who had not are not.
    *
    * @param source the new snapshot source, must implement {ISnapshotSource} and be non-zero
    */
    function setDividendSnapshotSource(ISnapshotSource source) public virtual onlySnapshotSourceManager {
        uint256 open = openClaimCount();
        if (open != 0) {
            revert IncomeVault_ClaimPeriodOpen(open);
        }
        if (address(source) == address(dividendSnapshotSource())) {
            revert IncomeVault_SameValue();
        }
        _setDividendSnapshotSource(source);
    }

    /* ============ View functions ============ */
    /**
    * @notice The contract the vault reads the holder balances from
    * @return The configured {ISnapshotSource}
    */
    function dividendSnapshotSource() public view virtual returns (ISnapshotSource) {
        SnapshotSourceStorage storage $ = _getSnapshotSourceStorage();
        return $._source;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /* ============ State functions ============ */
    /**
    * @notice Sets the snapshot source used to compute the dividends
    * @dev reverts if `source` is the zero address
    * @param source any contract implementing {ISnapshotSource}
    */
    function _setDividendSnapshotSource(ISnapshotSource source) internal virtual {
        if (address(source) == address(0)) {
            revert IncomeVault_SnapshotSourceWithAddressZeroNotAllowed();
        }
        SnapshotSourceStorage storage $ = _getSnapshotSourceStorage();
        $._source = source;
        emit DividendSnapshotSourceSet(source);
    }

    /* ============ View functions ============ */
    /// @inheritdoc IncomeVaultSnapshotCore
    function _snapshotInfo(uint256 time, address tokenHolder)
        internal
        view
        virtual
        override
        returns (uint256, uint256)
    {
        return dividendSnapshotSource().snapshotInfo(time, tokenHolder);
    }

    /// @inheritdoc IncomeVaultSnapshotCore
    function _snapshotInfoBatch(uint256 time, address[] calldata addresses)
        internal
        view
        virtual
        override
        returns (uint256[] memory, uint256)
    {
        return dividendSnapshotSource().snapshotInfoBatch(time, addresses);
    }

    /// @inheritdoc IncomeVaultSnapshotCore
    function _snapshotInfoBatch(uint256[] calldata times, address[] memory addresses)
        internal
        view
        virtual
        override
        returns (uint256[][] memory, uint256[] memory)
    {
        return dividendSnapshotSource().snapshotInfoBatch(times, addresses);
    }

    /* ============ Access Control ============ */
    /**
    * @dev Authorization hook invoked before {setDividendSnapshotSource}.
    * Implemented by the deployment contract with the desired access-control policy.
    */
    function _authorizeSnapshotSourceManagement() internal view virtual;

    /* ============ ERC-7201 ============ */
    /**
    * @dev Returns the ERC-7201 namespaced storage of this module
    * @return $ the storage struct
    */
    function _getSnapshotSourceStorage() internal pure returns (SnapshotSourceStorage storage $) {
        assembly {
            $.slot := SnapshotSourceStorageLocation
        }
    }
}
