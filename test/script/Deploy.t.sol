// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "../HelperContract.sol";
import {DeployIncomeVault} from "../../script/DeployIncomeVault.s.sol";
import {DeployIncomeVaultOwnable2Step} from "../../script/DeployIncomeVaultOwnable2Step.s.sol";

/**
* @title The deployment scripts — finding C-4
* @dev
* The scripts are the documented way to deploy, so they are tested like anything else. Each case
* drives `deploy(config)` directly, which is why that function is separated from the environment
* reading in `run()` — the tested code path is the one an operator runs.
*
* The assertions that matter are not "an address came back" but "the vault this produced actually
* pays a dividend".
*/
contract DeployScriptTest is HelperContract {
    DeployIncomeVault roleScript;
    DeployIncomeVaultOwnable2Step ownerScript;

    address constant PROXY_ADMIN = address(41);
    address constant VAULT_ADMIN = address(42);
    address constant VAULT_OWNER = address(43);

    function setUp() public {
        _deployContracts();
        roleScript = new DeployIncomeVault();
        ownerScript = new DeployIncomeVaultOwnable2Step();
    }

    function _roleConfig() internal view returns (DeployIncomeVault.Config memory) {
        return DeployIncomeVault.Config({
            proxyAdmin: PROXY_ADMIN,
            admin: VAULT_ADMIN,
            forwarder: ZERO_ADDRESS,
            paymentToken: IERC20(address(tokenPayment)),
            snapshotEngine: ISnapshotSource(address(snapshotEngine)),
            ruleEngine: IRuleEngine(ZERO_ADDRESS),
            timeLimitToWithdraw: TIME_LIMIT_TO_WITHDRAW
        });
    }

    function _ownerConfig() internal view returns (DeployIncomeVaultOwnable2Step.Config memory) {
        return DeployIncomeVaultOwnable2Step.Config({
            proxyAdmin: PROXY_ADMIN,
            owner: VAULT_OWNER,
            forwarder: ZERO_ADDRESS,
            paymentToken: IERC20(address(tokenPayment)),
            snapshotEngine: ISnapshotSource(address(snapshotEngine)),
            ruleEngine: IRuleEngine(ZERO_ADDRESS),
            timeLimitToWithdraw: TIME_LIMIT_TO_WITHDRAW
        });
    }

    /* ============ role-based variant ============ */
    function testDeploysAnInitializedVault() public {
        IncomeVault vault = roleScript.deploy(_roleConfig());

        assertEq(address(vault.ERC20TokenPayment()), address(tokenPayment));
        assertEq(address(vault.snapshotEngine()), address(snapshotEngine));
        assertEq(address(vault.ruleEngine()), ZERO_ADDRESS);
        assertEq(vault.timeLimitToWithdraw(), TIME_LIMIT_TO_WITHDRAW);
        assertEq(vault.version(), "1.1.0");
        assertTrue(vault.hasRole(bytes32(0), VAULT_ADMIN), "admin holds DEFAULT_ADMIN_ROLE");
    }

    /**
    * @notice The deployed vault cannot be initialized a second time
    */
    function testTheDeployedVaultIsAlreadyInitialized() public {
        IncomeVault vault = roleScript.deploy(_roleConfig());
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        vault.initialize(
            VAULT_ADMIN, IERC20(address(tokenPayment)),
            ISnapshotSource(address(snapshotEngine)), IRuleEngine(ZERO_ADDRESS), TIME_LIMIT_TO_WITHDRAW
        );
    }

    /**
    * @notice The real test: a vault the script produced actually pays a dividend
    */
    function testTheDeployedVaultPaysADividendEndToEnd() public {
        IncomeVault vault = roleScript.deploy(_roleConfig());

        vm.prank(CMTAT_ADMIN);
        snapshotEngine.scheduleSnapshot(defaultSnapshotTime);
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.mint(ADDRESS1, ADDRESS1_INITIAL_AMOUNT);

        tokenPayment.mint(VAULT_ADMIN, defaultDepositAmount);
        vm.prank(VAULT_ADMIN);
        tokenPayment.approve(address(vault), defaultDepositAmount);
        vm.prank(VAULT_ADMIN);
        vault.deposit(defaultSnapshotTime, defaultDepositAmount);
        vm.prank(VAULT_ADMIN);
        vault.setStatusClaim(defaultSnapshotTime, true);

        vm.warp(defaultSnapshotTime + 50);
        vm.prank(ADDRESS1);
        vault.claimDividend(defaultSnapshotTime);

        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount);
    }

    /* ============ single-owner variant ============ */
    function testDeploysAnInitializedOwnableVault() public {
        IncomeVaultOwnable2Step vault = ownerScript.deploy(_ownerConfig());

        assertEq(vault.owner(), VAULT_OWNER);
        assertEq(address(vault.snapshotEngine()), address(snapshotEngine));
        assertEq(vault.timeLimitToWithdraw(), TIME_LIMIT_TO_WITHDRAW);
        assertEq(vault.version(), "1.1.0");
    }

    function testTheDeployedOwnableVaultIsOperableByItsOwner() public {
        IncomeVaultOwnable2Step vault = ownerScript.deploy(_ownerConfig());
        vm.prank(VAULT_OWNER);
        vault.setStatusClaim(defaultSnapshotTime, true);
        assertEq(vault.segregatedClaim(defaultSnapshotTime), true);
    }

    /* ============ configuration guards ============ */
    /**
    * @notice The check the contract cannot do for itself: an EOA where a contract belongs
    * @dev A mistyped address, or one copied from another chain, initializes fine and then reverts on
    * the first claim. Catching it in the script is the whole point of having one.
    */
    function testRejectsAPaymentTokenThatIsNotAContract() public {
        DeployIncomeVault.Config memory config = _roleConfig();
        config.paymentToken = IERC20(address(0xBEEF));
        vm.expectRevert(bytes("DeployIncomeVault: PAYMENT_TOKEN is not a contract"));
        roleScript.deploy(config);
    }

    function testRejectsASnapshotEngineThatIsNotAContract() public {
        DeployIncomeVault.Config memory config = _roleConfig();
        config.snapshotEngine = ISnapshotSource(address(0xBEEF));
        vm.expectRevert(bytes("DeployIncomeVault: SNAPSHOT_ENGINE is not a contract"));
        roleScript.deploy(config);
    }

    function testRejectsARuleEngineThatIsNotAContract() public {
        DeployIncomeVault.Config memory config = _roleConfig();
        config.ruleEngine = IRuleEngine(address(0xBEEF));
        vm.expectRevert(bytes("DeployIncomeVault: RULE_ENGINE is set but is not a contract"));
        roleScript.deploy(config);
    }

    function testRejectsAZeroProxyAdmin() public {
        DeployIncomeVault.Config memory config = _roleConfig();
        config.proxyAdmin = ZERO_ADDRESS;
        vm.expectRevert(bytes("DeployIncomeVault: PROXY_ADMIN is zero"));
        roleScript.deploy(config);
    }

    function testRejectsAZeroAdmin() public {
        DeployIncomeVault.Config memory config = _roleConfig();
        config.admin = ZERO_ADDRESS;
        vm.expectRevert(bytes("DeployIncomeVault: VAULT_ADMIN is zero"));
        roleScript.deploy(config);
    }

    function testRejectsAZeroTimeLimit() public {
        DeployIncomeVault.Config memory config = _roleConfig();
        config.timeLimitToWithdraw = 0;
        vm.expectRevert(bytes("DeployIncomeVault: TIME_LIMIT_TO_WITHDRAW is zero"));
        roleScript.deploy(config);
    }

    function testRejectsAZeroOwnerOnTheOwnableVariant() public {
        DeployIncomeVaultOwnable2Step.Config memory config = _ownerConfig();
        config.owner = ZERO_ADDRESS;
        vm.expectRevert(bytes("DeployIncomeVaultOwnable2Step: VAULT_OWNER is zero"));
        ownerScript.deploy(config);
    }

    /**
    * @notice A rule engine is optional and the zero address is accepted
    */
    function testAZeroRuleEngineIsAccepted() public {
        IncomeVault vault = roleScript.deploy(_roleConfig());
        assertEq(address(vault.ruleEngine()), ZERO_ADDRESS);
    }
}
