// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {MinimalSnapshotSourceMock} from "./mocks/MinimalSnapshotSourceMock.sol";

/**
* @title The vault only requires what it calls — finding I-1
*/
contract SnapshotSourceTest is HelperContract {
    function setUp() public {
        _deployContracts();
    }

    /**
    * @notice A source implementing only the three functions the vault calls is enough
    * @dev The whole point of I-1: no `snapshotExists`, `snapshotBalanceOf`, `snapshotBalanceOfExact`,
    * `snapshotTotalSupply` or `snapshotTotalSupplyExact` — five functions of `ISnapshotState` the
    * vault never calls and no longer demands.
    */
    function testAThreeFunctionSourceIsAccepted() public {
        MinimalSnapshotSourceMock minimal = new MinimalSnapshotSourceMock();

        Options memory opts;
        opts.constructorData = abi.encode(ZERO_ADDRESS);
        address proxy = Upgrades.deployTransparentProxy(
            "IncomeVault.sol",
            DEFAULT_ADMIN_ADDRESS,
            abi.encodeCall(
                IncomeVault.initialize,
                (DEFAULT_ADMIN_ADDRESS, IERC20(address(tokenPayment)),
                 ISnapshotSource(address(minimal)), IRuleEngine(ZERO_ADDRESS), TIME_LIMIT_TO_WITHDRAW)
            ),
            opts
        );
        IncomeVault vault = IncomeVault(proxy);
        assertEq(address(vault.snapshotEngine()), address(minimal));

        // and a claim against it pays out on those balances: 100/400 of the deposit
        tokenPayment.mint(DEFAULT_ADMIN_ADDRESS, defaultDepositAmount);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(vault), defaultDepositAmount);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vault.deposit(defaultSnapshotTime, defaultDepositAmount);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);

        vm.prank(ADDRESS1);
        vault.claimDividend(defaultSnapshotTime);
        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount / 4);
    }

    /**
    * @notice The real `ISnapshotState` SnapshotEngine still satisfies the narrower interface
    * @dev Signatures are copied verbatim from `ISnapshotState`, so narrowing the type rejects nothing
    * that worked before. This is the compatibility half of I-1.
    */
    function testTheRealSnapshotEngineStillSatisfiesIt() public view {
        ISnapshotSource asSource = ISnapshotSource(address(snapshotEngine));
        assertEq(address(asSource), address(snapshotEngine));
        assertEq(address(incomeVault.snapshotEngine()), address(snapshotEngine));

        // the three calls the vault makes all resolve against the real engine
        (uint256 bal, uint256 supply) = asSource.snapshotInfo(defaultSnapshotTime, ADDRESS1);
        assertEq(bal, 0);
        assertEq(supply, 0);
    }
}
