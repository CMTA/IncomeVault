//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {IncomeVaultOverrideMock} from "./mocks/IncomeVaultOverrideMock.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title The `virtual` convention is reached, not merely compiled — finding E-1
 * @dev
 * `IncomeVaultOverrideMock` guards the convention at compile time: dropping `virtual` from any function
 * it overrides fails with `Error (4334)`. That alone does not prove the override is *called* — a
 * silently shadowed one compiles and never runs.
 *
 * These tests drive a real deposit-and-claim through the mock and assert the counters moved, which is
 * what distinguishes an override that is reached from one that merely exists.
 *
 * The proxy is deployed directly rather than through `Upgrades`, because the plugin's upgrade-safety
 * validation is for production contracts and this is a test double.
 */
contract OverrideMockTest is HelperContract {
    IncomeVaultOverrideMock vault;

    function setUp() public {
        _deployContracts();
        _mintCMTATTokens(); // schedules the snapshot at defaultSnapshotTime, then mints to ADDRESS1

        IncomeVaultOverrideMock impl = new IncomeVaultOverrideMock(ZERO_ADDRESS);
        vault = IncomeVaultOverrideMock(
            address(
                new TransparentUpgradeableProxy(
                    address(impl),
                    DEFAULT_ADMIN_ADDRESS,
                    abi.encodeCall(
                        IncomeVault.initialize,
                        (
                            DEFAULT_ADMIN_ADDRESS,
                            IERC20(address(tokenPayment)),
                            ISnapshotSource(address(snapshotEngine)),
                            IRuleEngine(ZERO_ADDRESS),
                            TIME_LIMIT_TO_WITHDRAW
                        )
                    )
                )
            )
        );
    }

    /**
     * @notice A claim reaches both the public and the internal override
     */
    function testAClaimReachesTheOverriddenRoutines() public {
        uint256 time = defaultSnapshotTime;

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(vault), 1_000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vault.deposit(time, 1_000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vault.setStatusClaim(time, true);
        vm.warp(time + 10);

        assertEq(vault.claimCount(), 0);
        assertEq(vault.transferCount(), 0);

        vm.prank(ADDRESS1);
        vault.claimDividend(time);

        assertEq(vault.claimCount(), 1, "public claimDividend override was not reached");
        assertEq(vault.transferCount(), 1, "internal _transferDividend override was not reached");
    }

    /**
     * @notice The overridden payout still pays the right amount
     * @dev An override that is reached but breaks the behaviour would be worse than one that is skipped.
     */
    function testTheOverriddenPayoutStillPaysCorrectly() public {
        uint256 time = defaultSnapshotTime;

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(vault), 1_000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vault.deposit(time, 1_000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vault.setStatusClaim(time, true);
        vm.warp(time + 10);

        uint256 before = tokenPayment.balanceOf(ADDRESS1);
        vm.prank(ADDRESS1);
        vault.claimDividend(time);

        assertGt(tokenPayment.balanceOf(ADDRESS1), before, "the holder was not paid");
        assertEq(vault.paidDividend(time), tokenPayment.balanceOf(ADDRESS1) - before);
    }
}
