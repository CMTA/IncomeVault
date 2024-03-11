# Technical choice

[TOC]

## Schema

### UML

![uml](../schema/classDiagram1.0.3.svg)



## Functionality

### Upgradeable

The DebtVault is currently not upgradeable. 

### Urgency mechanism
* Pause
  There are no functionalities to put in pause the contracts.

* We have removed the possibility to Kill the contracts,  to destroy the bytecode, from
  the different contracts (RuleEngine and Rule)  for the following reasons:

  * The opcode SELFDESTRUCT which the property of destroying the contract (= deletion of any storage keys or code) will be remove with the Cancun Upgrade, an upgrade of the Ethereum network.

    Therefore, when the Ethereum Network will integrate this upgrade, this functionality will no longer be available.

    See [https://eips.ethereum.org/EIPS/eip-6780](https://eips.ethereum.org/EIPS/eip-6780) & [https://github.com/ethereum/execution-specs/blob/master/network-upgrades/mainnet-upgrades/cancun.md](https://github.com/ethereum/execution-specs/blob/master/network-upgrades/mainnet-upgrades/cancun.md)


### Gasless support

> The gasless integration was not part of the audit performed by ABDK on the version [1.0.1](https://github.com/CMTA/RuleEngine/releases/tag/1.0.1)

The DebtVault contract supports client-side gasless transactions using the [Gas Station Network](https://docs.opengsn.org/#the-problem) (GSN) pattern, the main open standard for transfering fee payment to another account than that of the transaction issuer. The contract uses the OpenZeppelin contract `ERC2771Context`, which allows a contract to get the original client with `_msgSender()` instead of the fee payer given by `msg.sender` .

At deployment, the parameter  `forwarder` inside the contract constructor has to be set  with the defined address of the forwarder. Please note that the forwarder can not be changed after deployment.

Please see the OpenGSN [documentation](https://docs.opengsn.org/contracts/#receiving-a-relayed-call) for more details on what is done to support GSN in the contract.

https://github.com/ethereum/solidity/issues/10698)
