// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/**
 * @title ISnapshotSource
 * @notice The read surface the {IncomeVault} needs from a snapshot provider — nothing more.
 * @dev
 * This is the **minimum** a contract must expose to be usable as the vault's snapshot source. It is a
 * strict subset of `ISnapshotState` (defined by the CMTA
 * [SnapshotEngine](https://github.com/CMTA/SnapshotEngine)), which declares eight functions where the
 * vault calls three; the five it does not call describe balances and supplies the vault never reads.
 *
 * The signatures are copied verbatim from `ISnapshotState`, so **every `ISnapshotState`
 * implementation already satisfies this interface** — the `SnapshotEngine`, a token embedding the
 * snapshot modules, or a custom provider. Solidity has no implicit conversion between unrelated
 * interfaces, so pass one with an explicit cast: `ISnapshotSource(address(engine))`.
 *
 * @custom:security The vault does **not** verify this interface through ERC-165, deliberately. The
 * canonical `SnapshotEngine` does not advertise an id for it, so a guard would reject the very
 * implementation the vault is built for. And ERC-165 expresses shape, never semantics: a provider
 * returning attacker-chosen balances satisfies this interface exactly as an honest one does. Trusting
 * the snapshot source remains a configuration decision, not something a type or an interface check can
 * establish.
 */
interface ISnapshotSource {
    /**
     * @notice Retrieve both an account's balance and the total supply at the snapshot for a given timestamp in a single call.
     * @param time The timestamp identifying the snapshot to query.
     * @param tokenHolder The address whose balance is being requested.
     * @return tokenHolderBalance The recorded balance of the tokenHolder at the snapshot (or current balance if no snapshot).
     * @return totalSupply The recorded total supply at the snapshot (or current total supply if no snapshot).
     */
    function snapshotInfo(uint256 time, address tokenHolder)
        external
        view
        returns (uint256 tokenHolderBalance, uint256 totalSupply);

    /**
     * @notice Retrieve the balances of multiple accounts and the total supply at the snapshot for a given timestamp in a single call.
     * @param time The timestamp identifying the snapshot to query.
     * @param addresses The array of addresses to query balances for.
     * @return tokenHolderBalances An array containing each address's balance at the snapshot (or current balance if no snapshot).
     * @return totalSupply The recorded total supply at the snapshot (or current total supply if no snapshot).
     */
    function snapshotInfoBatch(uint256 time, address[] calldata addresses)
        external
        view
        returns (uint256[] memory tokenHolderBalances, uint256 totalSupply);

    /**
     * @notice Retrieve balances of multiple accounts at multiple snapshots, as well as the total supply at each snapshot.
     * @param times An array of timestamps identifying each snapshot to query.
     * @param addresses The array of addresses to query balances for at each snapshot.
     * @return tokenHolderBalances A 2D array where each row corresponds to the balances of all provided addresses at a given snapshot time.
     * @return totalSupplies An array containing the total supply at each snapshot time (or current supply if no snapshot).
     */
    function snapshotInfoBatch(uint256[] calldata times, address[] calldata addresses)
        external
        view
        returns (uint256[][] memory tokenHolderBalances, uint256[] memory totalSupplies);
}
