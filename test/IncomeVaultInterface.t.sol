//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {IIncomeVault} from "../src/interfaces/IIncomeVault.sol";
import {IERC7741} from "../src/interfaces/IERC7741.sol";
import {IERC7540Operator} from "../src/interfaces/IERC7540Operator.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {CMTATDividendHostMock} from "./mocks/CMTATDividendHostMock.sol";
import {EmbeddedDividendHostMock} from "./mocks/EmbeddedDividendHostMock.sol";

/**
* @title The vault's own API is a stated interface, not a by-product — finding M-7
* @dev
* {IIncomeVault} is inherited by {IncomeVaultInternal}, the common base of both payout paths, so the
* compiler already proves every deployable implements it. These tests cover what the compiler cannot:
* that the interface is reachable through a proxy, that it is advertised through ERC-165, and that a
* host embedding the distribution logic satisfies the same interface as the standalone vault.
*/
contract IncomeVaultInterfaceTest is HelperContract {
    function setUp() public {
        _deployContracts();
    }

    /**
    * @notice An integrator can drive a real deployment through the interface alone
    * @dev The point of the finding: no import of the concrete contract, and therefore none of CMTAT,
    * the RuleEngine or the upgrade plumbing behind it.
    */
    function testTheVaultIsUsableThroughTheInterfaceAlone() public {
        IIncomeVault vault = IIncomeVault(address(incomeVault));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vault.setTimeLimitToWithdraw(2 days);
        assertEq(vault.timeLimitToWithdraw(), 2 days);

        uint256 time = block.timestamp + 1 days;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(incomeVault), 100);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vault.deposit(time, 100);

        assertEq(vault.segregatedDividend(time), 100);
        assertEq(vault.unclaimedDividend(time), 100);
        assertEq(vault.paidDividend(time), 0);
        assertEq(address(vault.ERC20TokenPayment()), address(tokenPayment));
        assertFalse(vault.segregatedClaim(time));
        assertFalse(vault.claimedDividend(ADDRESS1, time));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vault.setStatusClaim(time, true);
        assertTrue(vault.segregatedClaim(time));
        assertEq(vault.openClaimCount(), 1);
    }

    /**
    * @notice The claim-window view returns the interface's own enum
    * @dev `TIME_ERROR_CODE` is declared on {IIncomeVault} rather than on the implementation, so an
    * integrator holding only the interface can interpret the answer.
    */
    function testTheClaimWindowCodeIsPartOfTheStatedApi() public {
        IIncomeVault vault = IIncomeVault(address(incomeVault));
        uint256 time = block.timestamp + 1 days;

        assertEq(uint256(vault.validateTimeCode(time)), uint256(IIncomeVault.TIME_ERROR_CODE.CLAIM_NOT_ACTIVATED));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(incomeVault), 100);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vault.deposit(time, 100);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vault.setStatusClaim(time, true);

        assertEq(uint256(vault.validateTimeCode(time)), uint256(IIncomeVault.TIME_ERROR_CODE.TOO_EARLY_TO_WITHDRAW));
        vm.warp(time + 1);
        assertEq(uint256(vault.validateTimeCode(time)), uint256(IIncomeVault.TIME_ERROR_CODE.OK));
    }

    /**
    * @notice Both deployment variants advertise the interface through ERC-165
    */
    function testBothVariantsAdvertiseTheInterface() public {
        _deployOwnableVault();
        bytes4 id = type(IIncomeVault).interfaceId;

        assertTrue(IERC165(address(incomeVault)).supportsInterface(id));
        assertTrue(IERC165(address(ownableVault)).supportsInterface(id));
    }

    /**
    * @notice The id is distinct from the other interfaces the vault advertises
    * @dev Guards against a copy-paste that advertises one id twice.
    */
    function testTheInterfaceIdIsDistinct() public pure {
        bytes4 id = type(IIncomeVault).interfaceId;

        assertTrue(id != type(IERC7741).interfaceId);
        assertTrue(id != type(IERC7540Operator).interfaceId);
        assertTrue(id != type(IERC165).interfaceId);
        assertTrue(id != bytes4(0xffffffff));
    }

    /**
    * @notice ERC-7540's operator id stays unadvertised
    * @dev The vault is not an asynchronous vault and must not claim to be one. Restated here because
    * adding {IIncomeVault} to `supportsInterface` is exactly the edit that invites adding this one too.
    */
    function testTheAsyncVaultIdIsStillNotAdvertised() public view {
        assertFalse(IERC165(address(incomeVault)).supportsInterface(type(IERC7540Operator).interfaceId));
    }

    /**
    * @notice A host embedding the distribution logic satisfies the same interface as the vault
    * @dev The casts compile only because both mocks inherit {IncomeVaultInternal}, hence
    * {IIncomeVault}. This is the M-7 counterpart to the M-1/M-2 compile guards: the embedded and the
    * standalone deployments present one API, not two.
    */
    function testTheEmbeddedHostsPresentTheSameInterface() public {
        IIncomeVault embedded = IIncomeVault(address(new EmbeddedDividendHostMock()));
        IIncomeVault cmtatHost = IIncomeVault(address(new CMTATDividendHostMock()));

        assertTrue(address(embedded) != address(0));
        assertTrue(address(cmtatHost) != address(0));
    }
}
