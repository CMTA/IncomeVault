// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.24;

/* ==== Foundry === */
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
/* ==== OpenZeppelin === */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
/* ==== CMTAT === */
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
/* ==== IncomeVault === */
import {IncomeVaultOwnable2Step} from "../src/IncomeVaultOwnable2Step.sol";
import {ISnapshotSource} from "../src/interfaces/ISnapshotSource.sol";

/**
* @title Deploy the role-based {IncomeVault} behind a transparent proxy
* @dev
* Run with:
*
* ```bash
* forge script script/DeployIncomeVaultOwnable2Step.s.sol --rpc-url <RPC> --broadcast --ffi
* ```
*
* `--ffi` is required: the OpenZeppelin Upgrades plugin shells out to the upgrades-core npm package
* for the upgrade-safety validation, which also needs a **full** build — run `forge clean && forge build`
* first or every run fails with "not from a full compilation".
*
* Configuration comes from the environment; {deploy} takes it explicitly so the same code path is
* exercised by `test/script/Deploy.t.sol` without any environment at all.
*/
contract DeployIncomeVaultOwnable2Step is Script {
    /**
    * @notice Everything the deployment needs
    * @dev `forwarder` and `ruleEngine` may be the zero address — gasless support and rule checks are
    * both optional. Every other member must be set.
    */
    struct Config {
        // owner of the ProxyAdmin, i.e. who may upgrade the implementation
        address proxyAdmin;
        // receives ownership of the vault (ERC-173); holds every capability
        address owner;
        // ERC-2771 trusted forwarder, or the zero address to disable gasless support
        address forwarder;
        // ERC-20 the dividends are paid in
        IERC20 paymentToken;
        // source of the holder balances
        ISnapshotSource snapshotEngine;
        // optional transfer-restriction engine, or the zero address
        IRuleEngine ruleEngine;
        // delay after the dividend time during which a claim is accepted, must be non-zero
        uint256 timeLimitToWithdraw;
    }

    /**
    * @notice Entry point — reads the configuration from the environment and broadcasts
    * @return vault the deployed proxy, typed as {IncomeVault}
    */
    function run() external returns (IncomeVaultOwnable2Step vault) {
        Config memory config = configFromEnv();
        vm.startBroadcast();
        vault = deploy(config);
        vm.stopBroadcast();
        logDeployment(vault, config);
    }

    /**
    * @notice Deploy and initialize the vault
    * @dev No broadcasting here, so tests can call it directly.
    * @param config the deployment configuration
    * @return vault the deployed proxy, typed as {IncomeVault}
    */
    function deploy(Config memory config) public returns (IncomeVaultOwnable2Step vault) {
        checkConfig(config);

        Options memory opts;
        // the implementation's constructor takes the ERC-2771 forwarder
        opts.constructorData = abi.encode(config.forwarder);

        address proxy = Upgrades.deployTransparentProxy(
            "IncomeVaultOwnable2Step.sol",
            config.proxyAdmin,
            abi.encodeCall(
                IncomeVaultOwnable2Step.initialize,
                (
                    config.owner,
                    config.paymentToken,
                    config.snapshotEngine,
                    config.ruleEngine,
                    config.timeLimitToWithdraw
                )
            ),
            opts
        );
        return IncomeVaultOwnable2Step(proxy);
    }

    /**
    * @notice Read the configuration from environment variables
    * @dev `FORWARDER` and `RULE_ENGINE` default to the zero address; everything else is required.
    * @return config the configuration
    */
    function configFromEnv() public view returns (Config memory config) {
        config = Config({
            proxyAdmin: vm.envAddress("PROXY_ADMIN"),
            owner: vm.envAddress("VAULT_OWNER"),
            forwarder: vm.envOr("FORWARDER", address(0)),
            paymentToken: IERC20(vm.envAddress("PAYMENT_TOKEN")),
            snapshotEngine: ISnapshotSource(vm.envAddress("SNAPSHOT_ENGINE")),
            ruleEngine: IRuleEngine(vm.envOr("RULE_ENGINE", address(0))),
            timeLimitToWithdraw: vm.envUint("TIME_LIMIT_TO_WITHDRAW")
        });
    }

    /**
    * @notice Reject a configuration that would deploy a broken vault
    * @dev
    * The contract validates the zero addresses itself, so this only adds what it **cannot** check:
    * that the two external dependencies are actually contracts. Passing an EOA — a mistyped address,
    * or a token address from the wrong chain — deploys a vault that initializes successfully and then
    * reverts on the first claim.
    * @param config the configuration to check
    */
    function checkConfig(Config memory config) public view {
        require(config.proxyAdmin != address(0), "DeployIncomeVaultOwnable2Step: PROXY_ADMIN is zero");
        require(config.owner != address(0), "DeployIncomeVaultOwnable2Step: VAULT_OWNER is zero");
        require(config.timeLimitToWithdraw != 0, "DeployIncomeVaultOwnable2Step: TIME_LIMIT_TO_WITHDRAW is zero");
        require(
            address(config.paymentToken).code.length > 0,
            "DeployIncomeVaultOwnable2Step: PAYMENT_TOKEN is not a contract"
        );
        require(
            address(config.snapshotEngine).code.length > 0,
            "DeployIncomeVaultOwnable2Step: SNAPSHOT_ENGINE is not a contract"
        );
        if (address(config.ruleEngine) != address(0)) {
            require(
                address(config.ruleEngine).code.length > 0,
                "DeployIncomeVaultOwnable2Step: RULE_ENGINE is set but is not a contract"
            );
        }
    }

    /**
    * @notice Print what was deployed
    * @param vault the deployed proxy
    * @param config the configuration used
    */
    function logDeployment(IncomeVaultOwnable2Step vault, Config memory config) public view {
        console.log("IncomeVault (proxy):   ", address(vault));
        console.log("  version:             ", vault.version());
        console.log("  owner:               ", vault.owner());
        console.log("  proxy admin:         ", config.proxyAdmin);
        console.log("  payment token:       ", address(vault.ERC20TokenPayment()));
        console.log("  snapshot source:     ", address(vault.dividendSnapshotSource()));
        console.log("  rule engine:         ", address(vault.ruleEngine()));
        console.log("  timeLimitToWithdraw: ", vault.timeLimitToWithdraw());
    }
}
