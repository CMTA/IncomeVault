//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {NoForwarderVaultMock} from "./mocks/NoForwarderVaultMock.sol";

/**
 * @title Gasless support is a deployment decision — finding M-8
 * @dev
 * {IncomeVaultBase} no longer inherits `ERC2771Module`; {IncomeVaultBaseERC2771} adds it, and the two
 * shipped deployments inherit that. These tests cover the half the compiler cannot: that a vault built
 * on the plain base really has no forwarder, and that the shipped ones still do.
 */
contract NoForwarderDeploymentTest is HelperContract {
    NoForwarderVaultMock vault;

    function setUp() public {
        _deployContracts();
        vault = new NoForwarderVaultMock();
        vault.initialize(
            IERC20(address(tokenPayment)), ISnapshotSource(address(snapshotEngine)), TIME_LIMIT_TO_WITHDRAW
        );
    }

    /**
     * @notice A vault on the plain base carries no ERC-2771 entry point at all
     * @dev `isTrustedForwarder` is `ERC2771ContextUpgradeable`'s. Its absence from the ABI is the
     * evidence that the meta-transaction machinery is genuinely gone, not merely disabled with a zero
     * address — which is all that was possible before the split.
     */
    function testThePlainBaseHasNoForwarderEntryPoint() public {
        (bool found,) = address(vault).call(abi.encodeWithSignature("isTrustedForwarder(address)", ADDRESS1));
        assertFalse(found, "the plain base must not expose isTrustedForwarder");
    }

    /**
     * @notice The shipped deployments keep gasless support
     */
    function testTheShippedDeploymentsStillCarryTheForwarder() public {
        (bool found, bytes memory data) =
            address(incomeVault).call(abi.encodeWithSignature("isTrustedForwarder(address)", ZERO_ADDRESS));
        assertTrue(found, "IncomeVault must still expose isTrustedForwarder");
        assertTrue(abi.decode(data, (bool)), "the configured forwarder must be trusted");
        // the suite deploys with a zero forwarder, so gasless is inert but the machinery is present
    }

    /**
     * @notice The forwarder-free vault still distributes dividends normally
     * @dev The split must remove the context, not the behaviour.
     */
    function testTheForwarderFreeVaultStillPaysDividends() public {
        uint256 time = block.timestamp + 1;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.transfer(address(this), 100);
        tokenPayment.approve(address(vault), 100);

        vault.deposit(time, 100);
        assertEq(vault.segregatedDividend(time), 100);

        vault.setStatusClaim(time, true);
        assertTrue(vault.segregatedClaim(time));
        assertEq(vault.openClaimCount(), 1);
    }
}
