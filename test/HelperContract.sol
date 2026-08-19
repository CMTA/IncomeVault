//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
/* ==== CMTAT === */
import {CMTATStandaloneSnapshot} from "CMTAT/deployment/snapshot/CMTATStandaloneSnapshot.sol";
import {ICMTATConstructor} from "CMTAT/interfaces/technical/ICMTATConstructor.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {ISnapshotEngine} from "CMTAT/interfaces/engine/ISnapshotEngine.sol";
/* ==== SnapshotEngine === */
import {SnapshotEngine} from "SnapshotEngine/deployment/SnapshotEngine.sol";
import {IERC20SnapshotCompatible} from "SnapshotEngine/interface/IERC20SnapshotCompatible.sol";
import {ISnapshotState} from "SnapshotEngine/interface/ISnapshotState.sol";
/* ==== OpenZeppelin === */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
/* ==== IncomeVault === */
import {IncomeVault} from "../src/IncomeVault.sol";
import {IncomeVaultInvariantStorage} from "../src/libraries/IncomeVaultInvariantStorage.sol";
import {IncomeVaultRolesStorage} from "../src/libraries/IncomeVaultRolesStorage.sol";
import {ERC20PaymentMock} from "./mocks/ERC20PaymentMock.sol";

/**
* @title Constants and shared deployment used by the tests
*/
abstract contract HelperContract is Test, IncomeVaultInvariantStorage, IncomeVaultRolesStorage {
    // EOA to perform tests
    address constant ZERO_ADDRESS = address(0);
    address constant DEFAULT_ADMIN_ADDRESS = address(1);
    // Operator
    address constant INCOME_VAULT_OPERATOR_ADDRESS = address(2);
    address constant INCOME_VAULT_DEPOSIT_OPERATOR_ADDRESS = address(3);
    address constant INCOME_VAULT_WITHDRAW_OPERATOR_ADDRESS = address(8);
    // Other
    address constant ATTACKER = address(4);
    address constant ADDRESS1 = address(5);
    address constant ADDRESS2 = address(6);
    address constant ADDRESS3 = address(7);
    address constant TOKEN_PAYMENT_ADMIN = address(8);
    address constant CMTAT_ADMIN = address(9);

    string constant DEFAULT_ADMIN_ROLE_HASH =
        "0x0000000000000000000000000000000000000000000000000000000000000000";

    uint8 constant NO_ERROR = 0;

    // Forwarder
    string ERC2771ForwarderDomain = 'ERC2771ForwarderDomain';

    uint256 constant TIME_LIMIT_TO_WITHDRAW = 365 days;

    // Contracts
    /// @dev security token, source of the holder balances
    CMTATStandaloneSnapshot CMTAT_CONTRACT;
    /// @dev external snapshot engine bound to `CMTAT_CONTRACT`, implements {ISnapshotState}
    SnapshotEngine snapshotEngine;
    /// @dev ERC-20 used to pay the dividends
    ERC20PaymentMock tokenPayment;
    IncomeVault incomeVault;

    // CMTAT value
    uint8 constant DECIMALS = 0;
    uint256 constant ADDRESS1_INITIAL_AMOUNT = 5000;

    uint256 defaultSnapshotTime = block.timestamp + 50;
    uint256 constant defaultDepositAmount = 2000;
    // Payment token minted to the deposit account
    uint256 constant tokenBalance = 5000;

    // Custom error OpenZeppelin
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
    * @dev Deploys the CMTAT, the external SnapshotEngine bound to it, the payment token and the
    * IncomeVault behind a transparent proxy. The vault reads the balances through {ISnapshotState},
    * so the snapshot engine — not the token — is what it is wired to.
    */
    function _deployContracts(IRuleEngine ruleEngine_) internal {
        // Security token
        CMTAT_CONTRACT = new CMTATStandaloneSnapshot(
            ZERO_ADDRESS,
            CMTAT_ADMIN,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", DECIMALS),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN",
                IERC1643CMTAT.DocumentInfo("", "", 0x00),
                "CMTAT_info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(ZERO_ADDRESS))
        );

        // Snapshot engine bound to the security token
        snapshotEngine = new SnapshotEngine(
            IERC20SnapshotCompatible(address(CMTAT_CONTRACT)),
            CMTAT_ADMIN
        );
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.setSnapshotEngine(ISnapshotEngine(address(snapshotEngine)));

        // Payment token
        tokenPayment = new ERC20PaymentMock("Payment Token", "PAY");

        // IncomeVault, deployed behind a transparent proxy
        Options memory opts;
        opts.constructorData = abi.encode(ZERO_ADDRESS);
        address proxy = Upgrades.deployTransparentProxy(
            "IncomeVault.sol",
            DEFAULT_ADMIN_ADDRESS,
            abi.encodeCall(
                IncomeVault.initialize,
                (
                    DEFAULT_ADMIN_ADDRESS,
                    IERC20(address(tokenPayment)),
                    ISnapshotState(address(snapshotEngine)),
                    ruleEngine_,
                    TIME_LIMIT_TO_WITHDRAW
                )
            ),
            opts
        );
        incomeVault = IncomeVault(proxy);

        tokenPayment.mint(DEFAULT_ADMIN_ADDRESS, tokenBalance);
    }

    function _deployContracts() internal {
        _deployContracts(IRuleEngine(ZERO_ADDRESS));
    }

    /* ============ Shared arrange helpers ============ */
    function _performOnlyDeposit() internal {
        _performOnlyDeposit(defaultSnapshotTime, defaultDepositAmount);
    }

    function _performOnlyDeposit(uint256 time, uint256 amount) internal {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(incomeVault), amount);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.deposit(time, amount);
    }

    /// @dev schedule the snapshot on the engine, then mint the security token
    function _mintCMTATTokens() internal {
        vm.prank(CMTAT_ADMIN);
        snapshotEngine.scheduleSnapshot(defaultSnapshotTime);

        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.mint(ADDRESS1, ADDRESS1_INITIAL_AMOUNT);
    }

    function _performDeposit() internal {
        _performOnlyDeposit();
        _mintCMTATTokens();
    }
}
