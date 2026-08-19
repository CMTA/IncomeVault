# Technical choice

[TOC]

## Functionality

### Upgradeable

The `IncomeVault` is upgradeable and can be deployed with a Transparent Proxy.

### Urgency mechanism

Through the `PauseModule`, the contract can be put in pause (`PAUSER_ROLE`), forbidding all claims.
A paused contract can also be permanently deactivated with `deactivateContract`
(`DEFAULT_ADMIN_ROLE`).

### Token agnostic

The vault reads the holder balances and the total supply through the `ISnapshotState` interface of
the [SnapshotEngine](https://github.com/CMTA/SnapshotEngine), so it works with any contract
implementing it and not only with the CMTAT. See [specification](./specification.md).

### Reentrancy

`claimDividend` and `claimDividendBatch` are protected with `ReentrancyGuardTransient`
(EIP-1153 transient storage). `ReentrancyGuardUpgradeable` was removed from OpenZeppelin Contracts
Upgradeable v5.7.0; the transient variant is storage-free and therefore proxy safe.


### Gasless support

> The gasless integration was not part of the audit performed by ABDK on the version [1.0.1](https://github.com/CMTA/RuleEngine/releases/tag/1.0.1)

The `IncomeVault` contract supports client-side gasless transactions using the [Gas Station Network](https://docs.opengsn.org/#the-problem) (GSN) pattern, the main open standard for transfering fee payment to another account than that of the transaction issuer. The contract uses the CMTAT `ERC2771Module`, a thin wrapper around the OpenZeppelin contract `ERC2771ContextUpgradeable`, which allows a contract to get the original client with `_msgSender()` instead of the fee payer given by `msg.sender` .

At deployment, the parameter  `forwarder` inside the contract constructor has to be set  with the defined address of the forwarder. Please note that the forwarder can not be changed after deployment.

Please see the OpenGSN [documentation](https://docs.opengsn.org/contracts/#receiving-a-relayed-call) for more details on what is done to support GSN in the contract.

## Schema

### UML

![uml](./schema/classDiagram.svg)



## Graph

### IncomeVault

![surya_graph_IncomeVault](../doc/surya/surya_graph/surya_graph_IncomeVault.sol.png)

### IncomeVaultOpen

![surya_graph_IncomeVaultOpen](../doc/surya/surya_graph/surya_graph_IncomeVaultOpen.sol.png)

### IncomeVaultRestricted

![surya_graph_IncomeVaultRestricted](../doc/surya/surya_graph/surya_graph_IncomeVaultRestricted.sol.png)

> The Surya graphs and the UML schema below are generated from the sources and have not been
> regenerated since the migration to CMTAT v3 / SnapshotEngine. Run `npm run surya:graph` and
> `npm run uml` to refresh them.
