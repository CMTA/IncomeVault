// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {ISnapshotSource} from "../../src/interfaces/ISnapshotSource.sol";

/**
 * @title A snapshot source implementing ONLY what the vault calls
 * @dev
 * This is the point of finding I-1: three functions, not the eight of `ISnapshotState`. If this
 * contract compiles and the vault works against it, the extra five were never required. It returns
 * fixed values — it exists to prove the interface is sufficient, not to model snapshot semantics.
 */
contract MinimalSnapshotSourceMock is ISnapshotSource {
    uint256 public constant BALANCE = 100;
    uint256 public constant TOTAL_SUPPLY = 400;

    /// @inheritdoc ISnapshotSource
    function snapshotInfo(uint256, address)
        external
        pure
        override
        returns (uint256 tokenHolderBalance, uint256 totalSupply)
    {
        return (BALANCE, TOTAL_SUPPLY);
    }

    /// @inheritdoc ISnapshotSource
    function snapshotInfoBatch(uint256, address[] calldata addresses)
        external
        pure
        override
        returns (uint256[] memory tokenHolderBalances, uint256 totalSupply)
    {
        tokenHolderBalances = new uint256[](addresses.length);
        for (uint256 i = 0; i < addresses.length; ++i) {
            tokenHolderBalances[i] = BALANCE;
        }
        return (tokenHolderBalances, TOTAL_SUPPLY);
    }

    /// @inheritdoc ISnapshotSource
    function snapshotInfoBatch(uint256[] calldata times, address[] calldata addresses)
        external
        pure
        override
        returns (uint256[][] memory tokenHolderBalances, uint256[] memory totalSupplies)
    {
        tokenHolderBalances = new uint256[][](times.length);
        totalSupplies = new uint256[](times.length);
        for (uint256 t = 0; t < times.length; ++t) {
            uint256[] memory row = new uint256[](addresses.length);
            for (uint256 i = 0; i < addresses.length; ++i) {
                row[i] = BALANCE;
            }
            tokenHolderBalances[t] = row;
            totalSupplies[t] = TOTAL_SUPPLY;
        }
    }
}
