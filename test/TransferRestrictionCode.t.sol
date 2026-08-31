//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";

/**
 * @title The ERC-1404 view answers for the whole payout decision — finding H-1
 * @dev
 * `detectTransferRestriction` used to consult only the RuleEngine, so a paused vault or a frozen
 * holder was reported as unrestricted while `canTransfer` said false and the claim reverted. Two views
 * on one contract disagreed about the same payout, and the one carrying the ERC-1404 name was wrong.
 *
 * The invariant these tests pin is **agreement**: `detectTransferRestriction(...) == 0` exactly when
 * `canTransfer(...)` is true. Each state is checked through both views, so removing any branch of
 * either breaks a test rather than silently reintroducing the gap.
 */
contract TransferRestrictionCodeTest is HelperContract {
    uint8 constant OK = uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    uint8 constant PAUSED = uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_REJECTED_PAUSED);
    uint8 constant DEACTIVATED = uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_REJECTED_DEACTIVATED);
    uint8 constant FROM_FROZEN = uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_REJECTED_FROM_FROZEN);
    uint8 constant TO_FROZEN = uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_REJECTED_TO_FROZEN);

    function setUp() public {
        _deployContracts();
    }

    /// @dev The two views must never disagree, whatever the state.
    function _assertAgree(address from, address to, uint256 value) internal view {
        bool allowed = incomeVault.canTransfer(from, to, value);
        uint8 code = incomeVault.detectTransferRestriction(from, to, value);
        assertEq(allowed, code == OK, "canTransfer and detectTransferRestriction disagree");
    }

    /**
     * @notice With nothing restricting it, the payout is reported as unrestricted
     */
    function testUnrestrictedPayoutReportsOk() public view {
        assertEq(incomeVault.detectTransferRestriction(address(incomeVault), ADDRESS1, 100), OK);
        _assertAgree(address(incomeVault), ADDRESS1, 100);
    }

    /**
     * @notice A paused vault is reported as paused, not as unrestricted
     * @dev This is the regression: before H-1 this returned 0 while the claim reverted.
     */
    function testPausedVaultReportsPaused() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.pause();

        assertEq(incomeVault.detectTransferRestriction(address(incomeVault), ADDRESS1, 100), PAUSED);
        assertFalse(incomeVault.canTransfer(address(incomeVault), ADDRESS1, 100));
        _assertAgree(address(incomeVault), ADDRESS1, 100);
    }

    /**
     * @notice A deactivated vault reports the more specific code, not merely "paused"
     * @dev Deactivation requires the pause state, so both branches match; the specific one must win.
     */
    function testDeactivatedVaultReportsDeactivated() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.pause();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deactivateContract();

        assertEq(incomeVault.detectTransferRestriction(address(incomeVault), ADDRESS1, 100), DEACTIVATED);
        _assertAgree(address(incomeVault), ADDRESS1, 100);
    }

    /**
     * @notice A frozen recipient is reported, and distinguished from a frozen sender
     */
    function testFrozenPartiesReportTheirOwnCode() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setAddressFrozen(ADDRESS1, true, "Blacklist");

        assertEq(incomeVault.detectTransferRestriction(address(incomeVault), ADDRESS1, 100), TO_FROZEN);
        _assertAgree(address(incomeVault), ADDRESS1, 100);

        // the same holder as the sender side yields the FROM code instead
        assertEq(incomeVault.detectTransferRestriction(ADDRESS1, ADDRESS2, 100), FROM_FROZEN);
        _assertAgree(ADDRESS1, ADDRESS2, 100);
    }

    /**
     * @notice Every code the vault can return has a message, without a RuleEngine configured
     * @dev Previously every code answered "No restriction", including codes that mean something.
     */
    function testEveryVaultCodeHasAMessage() public view {
        assertEq(incomeVault.messageForTransferRestriction(OK), "NoRestriction");
        assertEq(incomeVault.messageForTransferRestriction(PAUSED), "EnforcedPause");
        assertEq(incomeVault.messageForTransferRestriction(DEACTIVATED), "ContractDeactivated");
        assertEq(incomeVault.messageForTransferRestriction(FROM_FROZEN), "AddrFromIsFrozen");
        assertEq(incomeVault.messageForTransferRestriction(TO_FROZEN), "AddrToIsFrozen");
        // a code the vault never issues, with no RuleEngine to ask
        assertEq(incomeVault.messageForTransferRestriction(200), "UnknownCode");
    }

    /**
     * @notice The messages are CMTAT's, so a console written against a CMTAT reads payouts unchanged
     */
    function testMessagesMatchTheCmtatVocabulary() public view {
        assertEq(incomeVault.messageForTransferRestriction(PAUSED), "EnforcedPause");
        assertEq(incomeVault.messageForTransferRestriction(FROM_FROZEN), "AddrFromIsFrozen");
    }
}
