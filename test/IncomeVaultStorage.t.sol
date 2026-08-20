// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {SlotDerivation} from "@openzeppelin/contracts/utils/SlotDerivation.sol";

/**
* @title Checks the ERC-7201 namespaced storage of the IncomeVault
* @dev
* The slot constant in {IncomeVaultInternal} is hardcoded, so it is re-derived here with
* {SlotDerivation-erc7201Slot} and compared against what the deployed proxy actually stores.
*/
contract IncomeVaultStorageTest is HelperContract {
    using SlotDerivation for string;

    string constant NAMESPACE = "IncomeVault.storage.IncomeVaultInternal";
    /// @dev the value hardcoded in IncomeVaultInternal
    bytes32 constant EXPECTED_SLOT = 0xe4f8b033bcfc537db031b0e68e3c1ab0f1de86cf03893d031b6590510b0c0c00;
    /// @dev the snapshot source lives in its own namespace, so a host embedding the dividend logic
    /// can answer the snapshot hooks itself and never allocate this slot at all
    string constant SNAPSHOT_NAMESPACE = "IncomeVault.storage.SnapshotSource";
    /// @dev the value hardcoded in IncomeVaultSnapshotModule
    bytes32 constant EXPECTED_SNAPSHOT_SLOT = 0x45a69a32b5b7efb4ae8ac48e2427653ef15920a29875121a072e6b49aaccac00;

    function setUp() public {
        _deployContracts();
    }

    /**
    * @notice The hardcoded constant matches the ERC-7201 derivation of the namespace
    */
    function testStorageLocationMatchesTheErc7201Derivation() public pure {
        assertEq(NAMESPACE.erc7201Slot(), EXPECTED_SLOT);
        assertEq(SNAPSHOT_NAMESPACE.erc7201Slot(), EXPECTED_SNAPSHOT_SLOT);
    }

    /**
    * @notice ERC-7201 requires the last byte of the slot to be zeroed
    */
    function testStorageLocationIsAligned() public pure {
        assertEq(uint256(EXPECTED_SLOT) & 0xff, 0);
        assertEq(uint256(EXPECTED_SNAPSHOT_SLOT) & 0xff, 0);
    }

    /**
    * @notice The two namespaces are disjoint, so neither module can corrupt the other
    */
    function testTheTwoNamespacesDoNotOverlap() public pure {
        assertTrue(EXPECTED_SLOT != EXPECTED_SNAPSHOT_SLOT);
    }

    /**
    * @notice The proxy really stores the state at the namespaced slot, in the declared field order
    * @dev field 0 is `_ERC20TokenPayment`, field 4 is `_timeLimitToWithdraw`
    */
    function testProxyStoresTheStateAtTheNamespacedSlot() public view {
        bytes32 slot = NAMESPACE.erc7201Slot();

        bytes32 rawPaymentToken = vm.load(address(incomeVault), slot);
        assertEq(address(uint160(uint256(rawPaymentToken))), address(incomeVault.ERC20TokenPayment()));

        bytes32 rawTimeLimit = vm.load(address(incomeVault), bytes32(uint256(slot) + 4));
        assertEq(uint256(rawTimeLimit), TIME_LIMIT_TO_WITHDRAW);
        assertEq(uint256(rawTimeLimit), incomeVault.timeLimitToWithdraw());
    }

    /**
    * @notice The snapshot source is stored in its own namespace, not in the internal one
    */
    function testTheSnapshotSourceLivesInItsOwnNamespace() public view {
        bytes32 raw = vm.load(address(incomeVault), SNAPSHOT_NAMESPACE.erc7201Slot());
        assertEq(address(uint160(uint256(raw))), address(snapshotEngine));
        assertEq(address(uint160(uint256(raw))), address(incomeVault.dividendSnapshotSource()));
    }

    /**
    * @notice Slot 0 is free: no state is declared outside the ERC-7201 namespaces
    */
    function testNoStateInTheSequentialSlots() public view {
        for (uint256 i = 0; i < 8; ++i) {
            assertEq(vm.load(address(incomeVault), bytes32(i)), bytes32(0));
        }
    }

    /**
    * @notice The public getters kept by the migration still expose the whole state
    */
    function testGettersExposeTheNamespacedState() public {
        _performDeposit();
        assertEq(incomeVault.segregatedDividend(defaultSnapshotTime), defaultDepositAmount);
        assertEq(incomeVault.segregatedClaim(defaultSnapshotTime), false);
        assertEq(incomeVault.claimedDividend(ADDRESS1, defaultSnapshotTime), false);
        assertEq(address(incomeVault.ERC20TokenPayment()), address(tokenPayment));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        assertEq(incomeVault.segregatedClaim(defaultSnapshotTime), true);
    }
}
