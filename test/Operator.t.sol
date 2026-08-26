// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {IERC7540Operator} from "../src/interfaces/IERC7540Operator.sol";

/**
 * @title Claim delegation — finding E-1
 * @dev Shape borrowed from ERC-7540: the holder authorises an operator, the operator triggers the
 * claim, and the dividends still go to the holder.
 */
contract OperatorTest is HelperContract {
    address constant CUSTODIAN = address(31);
    address constant STRANGER = address(32);

    function setUp() public {
        _deployContracts();
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);
    }

    /* ============ granting ============ */
    function testOperatorStartsUnset() public view {
        assertEq(incomeVault.isOperator(ADDRESS1, CUSTODIAN), false);
    }

    function testSetOperatorGrantsAndEmits() public {
        vm.expectEmit(true, true, false, true);
        emit IERC7540Operator.OperatorSet(ADDRESS1, CUSTODIAN, true);
        vm.prank(ADDRESS1);
        bool ok = incomeVault.setOperator(CUSTODIAN, true);

        assertTrue(ok, "ERC-7540 setOperator returns true");
        assertEq(incomeVault.isOperator(ADDRESS1, CUSTODIAN), true);
    }

    function testSetOperatorRevokes() public {
        vm.prank(ADDRESS1);
        incomeVault.setOperator(CUSTODIAN, true);
        vm.prank(ADDRESS1);
        incomeVault.setOperator(CUSTODIAN, false);
        assertEq(incomeVault.isOperator(ADDRESS1, CUSTODIAN), false);
    }

    /**
     * @notice Authorisation is per holder — granting for one does not grant for another
     */
    function testAuthorisationIsPerHolder() public {
        vm.prank(ADDRESS1);
        incomeVault.setOperator(CUSTODIAN, true);
        assertEq(incomeVault.isOperator(ADDRESS2, CUSTODIAN), false);
    }

    /* ============ claiming on behalf ============ */
    /**
     * @notice The operator triggers the claim; the **holder** receives the dividends
     */
    function testOperatorClaimsAndTheHolderIsPaid() public {
        vm.prank(ADDRESS1);
        incomeVault.setOperator(CUSTODIAN, true);

        vm.prank(CUSTODIAN);
        incomeVault.claimDividendFor(ADDRESS1, defaultSnapshotTime);

        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount, "holder is paid");
        assertEq(tokenPayment.balanceOf(CUSTODIAN), 0, "operator receives nothing");
        assertEq(incomeVault.claimedDividend(ADDRESS1, defaultSnapshotTime), true);
    }

    function testHolderCanUseClaimForOnThemselves() public {
        vm.prank(ADDRESS1);
        incomeVault.claimDividendFor(ADDRESS1, defaultSnapshotTime);
        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount);
    }

    function testOperatorBatchClaim() public {
        vm.prank(ADDRESS1);
        incomeVault.setOperator(CUSTODIAN, true);

        uint256[] memory times = new uint256[](1);
        times[0] = defaultSnapshotTime;
        vm.prank(CUSTODIAN);
        incomeVault.claimDividendBatchFor(ADDRESS1, times);

        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount);
        assertEq(tokenPayment.balanceOf(CUSTODIAN), 0);
    }

    /* ============ refusals ============ */
    function testStrangerCannotClaimForAHolder() public {
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_UnauthorizedOperator.selector, ADDRESS1, STRANGER));
        vm.prank(STRANGER);
        incomeVault.claimDividendFor(ADDRESS1, defaultSnapshotTime);

        assertEq(tokenPayment.balanceOf(ADDRESS1), 0);
    }

    function testRevokedOperatorCannotClaim() public {
        vm.prank(ADDRESS1);
        incomeVault.setOperator(CUSTODIAN, true);
        vm.prank(ADDRESS1);
        incomeVault.setOperator(CUSTODIAN, false);

        vm.expectRevert(abi.encodeWithSelector(IncomeVault_UnauthorizedOperator.selector, ADDRESS1, CUSTODIAN));
        vm.prank(CUSTODIAN);
        incomeVault.claimDividendFor(ADDRESS1, defaultSnapshotTime);
    }

    /**
     * @notice An operator for one holder cannot claim for another
     */
    function testOperatorCannotCrossToAnotherHolder() public {
        vm.prank(ADDRESS1);
        incomeVault.setOperator(CUSTODIAN, true);

        vm.expectRevert(abi.encodeWithSelector(IncomeVault_UnauthorizedOperator.selector, ADDRESS2, CUSTODIAN));
        vm.prank(CUSTODIAN);
        incomeVault.claimDividendFor(ADDRESS2, defaultSnapshotTime);
    }

    /* ============ every other rule still applies ============ */
    function testOperatorCannotClaimTwice() public {
        vm.prank(ADDRESS1);
        incomeVault.setOperator(CUSTODIAN, true);
        vm.prank(CUSTODIAN);
        incomeVault.claimDividendFor(ADDRESS1, defaultSnapshotTime);

        vm.expectRevert(abi.encodeWithSelector(IncomeVault_DividendAlreadyClaimed.selector));
        vm.prank(CUSTODIAN);
        incomeVault.claimDividendFor(ADDRESS1, defaultSnapshotTime);
    }

    function testOperatorCannotClaimForAFrozenHolder() public {
        vm.prank(ADDRESS1);
        incomeVault.setOperator(CUSTODIAN, true);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setAddressFrozen(ADDRESS1, true, "");

        vm.expectRevert(
            abi.encodeWithSelector(
                IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS1, defaultDepositAmount
            )
        );
        vm.prank(CUSTODIAN);
        incomeVault.claimDividendFor(ADDRESS1, defaultSnapshotTime);
    }

    function testOperatorCannotClaimOutsideTheWindow() public {
        vm.prank(ADDRESS1);
        incomeVault.setOperator(CUSTODIAN, true);
        vm.warp(defaultSnapshotTime + TIME_LIMIT_TO_WITHDRAW + 1);

        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TooLateToWithdraw.selector, block.timestamp));
        vm.prank(CUSTODIAN);
        incomeVault.claimDividendFor(ADDRESS1, defaultSnapshotTime);
    }

    /* ============ conformance with the ERC-7540 operator subset ============ */
    /**
     * @notice The interface id matches the value ERC-7540 assigns to its operator methods
     * @dev
     * This is what pins the signatures to the standard. ERC-7540 states that `0xe3bc4e65` represents
     * "the operator methods that all ERC-7540 Vaults implement"; `IERC7540Operator` inherits nothing,
     * so `type(...).interfaceId` is exactly `setOperator(address,bool) ^ isOperator(address,address)`.
     * Change either signature and this fails — which is the point, because a custodian written against
     * ERC-7540 would then silently stop working.
     */
    function testOperatorInterfaceIdMatchesTheStandard() public pure {
        assertEq(type(IERC7540Operator).interfaceId, bytes4(0xe3bc4e65));
    }

    /**
     * @notice The vault really is callable through the standard interface type
     */
    function testCallableThroughTheStandardInterface() public {
        IERC7540Operator asStandard = IERC7540Operator(address(incomeVault));

        vm.prank(ADDRESS1);
        assertTrue(asStandard.setOperator(CUSTODIAN, true), "setOperator MUST return true");
        assertEq(asStandard.isOperator(ADDRESS1, CUSTODIAN), true);

        vm.prank(CUSTODIAN);
        incomeVault.claimDividendFor(ADDRESS1, defaultSnapshotTime);
        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount);
    }

    /**
     * @notice The vault deliberately does NOT advertise the id through ERC-165
     * @dev Sharing the operator methods does not make it an asynchronous ERC-7540 vault; a caller
     * discovering `0xe3bc4e65` would reasonably expect the request lifecycle and ERC-7575's `share()`,
     * neither of which exists here. Asserted so the under-claim is a decision, not an oversight.
     */
    function testDoesNotClaimToBeAnErc7540Vault() public view {
        assertEq(incomeVault.supportsInterface(bytes4(0xe3bc4e65)), false);
        assertEq(incomeVault.supportsInterface(bytes4(0xce3bbe50)), false, "not an async deposit vault");
        assertEq(incomeVault.supportsInterface(bytes4(0x620ee8e4)), false, "not an async redeem vault");
        assertEq(incomeVault.supportsInterface(bytes4(0x2f0a18c5)), false, "not an ERC-7575 vault");
    }
}
