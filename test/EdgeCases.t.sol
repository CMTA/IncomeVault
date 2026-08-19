// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {IncomeVaultOwnable2Step} from "../src/IncomeVaultOwnable2Step.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
* @title Branch coverage of the guards and the unconfigured paths — finding B-2
* @dev
* These are the branches the behavioural suites never reach: the constructor guards, and the
* "no RuleEngine configured" answers. Each asserts the observable consequence, not just that the
* line executed.
*/
contract EdgeCasesTest is HelperContract {
    function setUp() public {
        _deployContracts();
    }

    /* ============ initializer guards ============ */
    function testCannotInitializeWithAZeroAdmin() public {
        IncomeVault implementation = new IncomeVault(ZERO_ADDRESS);
        bytes memory data = abi.encodeCall(
            IncomeVault.initialize,
            (ZERO_ADDRESS, IERC20(address(tokenPayment)),
             ISnapshotSource(address(snapshotEngine)), IRuleEngine(ZERO_ADDRESS), TIME_LIMIT_TO_WITHDRAW)
        );
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_AdminWithAddressZeroNotAllowed.selector));
        new TransparentUpgradeableProxy(address(implementation), DEFAULT_ADMIN_ADDRESS, data);
    }

    function testCannotInitializeTheOwnableVariantWithAZeroOwner() public {
        IncomeVaultOwnable2Step implementation = new IncomeVaultOwnable2Step(ZERO_ADDRESS);
        bytes memory data = abi.encodeCall(
            IncomeVaultOwnable2Step.initialize,
            (ZERO_ADDRESS, IERC20(address(tokenPayment)),
             ISnapshotSource(address(snapshotEngine)), IRuleEngine(ZERO_ADDRESS), TIME_LIMIT_TO_WITHDRAW)
        );
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_AdminWithAddressZeroNotAllowed.selector));
        new TransparentUpgradeableProxy(address(implementation), DEFAULT_ADMIN_ADDRESS, data);
    }

    function testCannotInitializeWithAZeroPaymentToken() public {
        IncomeVault implementation = new IncomeVault(ZERO_ADDRESS);
        bytes memory data = abi.encodeCall(
            IncomeVault.initialize,
            (DEFAULT_ADMIN_ADDRESS, IERC20(ZERO_ADDRESS),
             ISnapshotSource(address(snapshotEngine)), IRuleEngine(ZERO_ADDRESS), TIME_LIMIT_TO_WITHDRAW)
        );
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TokenPaymentWithAddressZeroNotAllowed.selector));
        new TransparentUpgradeableProxy(address(implementation), DEFAULT_ADMIN_ADDRESS, data);
    }

    /* ============ a holder with no tokens at the snapshot ============ */
    /**
    * @notice Claiming with a zero snapshot balance is refused before any dividend is computed
    * @dev Distinct from `IncomeVault_NoDividendToClaim`, which means "you held tokens but the
    * computed share rounds to zero".
    */
    function testHolderWithNoTokensAtTheSnapshotCannotClaim() public {
        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);

        // ADDRESS3 never received any security token
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_TokenBalanceIsZero.selector));
        vm.prank(ADDRESS3);
        incomeVault.claimDividend(defaultSnapshotTime);
    }

    /* ============ no RuleEngine configured ============ */
    /**
    * @notice With no RuleEngine, the ERC-1404 views answer "no restriction" rather than reverting
    * @dev `_deployContracts()` wires no engine, so these are the unconfigured answers an integrator
    * gets from a vault that relies on pause and freeze alone.
    */
    function testErc1404ViewsWithoutARuleEngine() public view {
        assertEq(address(incomeVault.ruleEngine()), ZERO_ADDRESS);
        assertEq(incomeVault.detectTransferRestriction(address(incomeVault), ADDRESS1, 100), 0);
        assertEq(incomeVault.messageForTransferRestriction(0), "No restriction");
        assertEq(incomeVault.messageForTransferRestriction(42), "No restriction");
        // and the payout is allowed
        assertEq(incomeVault.canTransfer(address(incomeVault), ADDRESS1, 100), true);
    }

    /* ============ every TIME_ERROR_CODE arm ============ */
    /**
    * @notice `validateTime` maps each code to its own error, and `validateTimeCode` reports it
    */
    function testEveryTimeErrorCodeArm() public {
        // 1. claims not activated
        assertEq(uint256(incomeVault.validateTimeCode(defaultSnapshotTime)), 1);
        vm.expectRevert(abi.encodeWithSelector(IncomeVault_ClaimNotActivated.selector));
        incomeVault.validateTime(defaultSnapshotTime);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // 3. too early
        assertEq(uint256(incomeVault.validateTimeCode(defaultSnapshotTime)), 3);
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_TooEarlyToWithdraw.selector, block.timestamp));
        incomeVault.validateTime(defaultSnapshotTime);

        // 0. OK — inside the window, no revert
        vm.warp(defaultSnapshotTime + 50);
        assertEq(uint256(incomeVault.validateTimeCode(defaultSnapshotTime)), 0);
        incomeVault.validateTime(defaultSnapshotTime);

        // 2. too late
        vm.warp(defaultSnapshotTime + TIME_LIMIT_TO_WITHDRAW + 1);
        assertEq(uint256(incomeVault.validateTimeCode(defaultSnapshotTime)), 2);
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_TooLateToWithdraw.selector, block.timestamp));
        incomeVault.validateTime(defaultSnapshotTime);
    }
}
