# Technical choice

[TOC]

## Functionality

### Upgradeable

The `IncomeVault` is upgradeable and can be deployed with a Transparent Proxy.

### Urgency mechanism

Through the ValidationModule, the contract can be put in paused, forbidding all claims.


### Gasless support

> The gasless integration was not part of the audit performed by ABDK on the version [1.0.1](https://github.com/CMTA/RuleEngine/releases/tag/1.0.1)

The IncomeVault contract supports client-side gasless transactions using the [Gas Station Network](https://docs.opengsn.org/#the-problem) (GSN) pattern, the main open standard for transfering fee payment to another account than that of the transaction issuer. The contract uses the OpenZeppelin contract `ERC2771Context`, which allows a contract to get the original client with `_msgSender()` instead of the fee payer given by `msg.sender` .

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
