// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/**
* @title What the dividend logic needs from a snapshot provider — and nothing more
* @dev
* The payout paths need three answers: one holder's balance at a `time`, many holders' balances at a
* `time`, and one holder's balances across many `time`s. This contract is those three questions, and
* **inherits nothing**.
*
* Declaring them as hooks rather than as calls on a stored address is what lets a host *be* its own
* snapshot source. A `CMTATStandaloneInternalSnapshot` already exposes `snapshotInfo` and both
* `snapshotInfoBatch` overloads, so it answers these from itself — no external call, no stored
* address, and no `snapshotEngine()` getter to collide with the one it already has.
*
* {IncomeVaultSnapshotModule} is the answer used by the standalone vault: an external
* {ISnapshotSource} held in storage. It is one implementation, not the only one.
*/
abstract contract IncomeVaultSnapshotCore {
    /**
    * @dev Balance of one holder and the total supply, at `time`
    * @param time the dividend time
    * @param tokenHolder the holder to look up
    * @return tokenHolderBalance the holder's recorded balance
    * @return totalSupply the recorded total supply
    */
    function _snapshotInfo(uint256 time, address tokenHolder)
        internal
        view
        virtual
        returns (uint256 tokenHolderBalance, uint256 totalSupply);

    /**
    * @dev Balances of many holders and the total supply, at one `time`
    * @param time the dividend time
    * @param addresses the holders to look up
    * @return tokenHolderBalances one balance per address
    * @return totalSupply the recorded total supply
    */
    function _snapshotInfoBatch(uint256 time, address[] calldata addresses)
        internal
        view
        virtual
        returns (uint256[] memory tokenHolderBalances, uint256 totalSupply);

    /**
    * @dev Balances of holders across many `time`s
    * @param times the dividend times
    * @param addresses the holders to look up
    * @return tokenHolderBalances one row per time
    * @return totalSupplies one total supply per time
    */
    function _snapshotInfoBatch(uint256[] calldata times, address[] memory addresses)
        internal
        view
        virtual
        returns (uint256[][] memory tokenHolderBalances, uint256[] memory totalSupplies);
}
