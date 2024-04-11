# IncomeVault

The `IncomeVault`is  a prototype to perform coupon-payment dividend with a CMTAT and the snapshotModule

## Introduction

The dividends are deposited in a Vault. Once the claims are open, a token holder can then perform a claim to get his dividends for a given period.

Currently, the vault supports only dividend under the form of another ERC-20 and it is suitable for the following use-case:

- Dividends in ERC-20 compatible, which could be an ERC-20 stablecoin such as USDC or USDT for example
- Interest paid out at given intervals which shall be a configurable parameter (i.e. every 6 months, every 1 year)

For the specific case where dividends are distributed in shares, meaning additional payout of the “existing” CMTAT Token, it is not currently supported due to the following reasons:
\- With the current architecture, depending on when you decide to mint the new tokens, you will increase the total supply used to compute the token holder shares. Therefore, you will reduce the dividends distributed to the token holders.
\- In general, for yield tokens, the formula used can be different.

## Compatibility

- The dividends can be paid with ERC-20 tokens as described in the [ERC-20](https://eips.ethereum.org/EIPS/eip-20) specification
- The shares used to compute the dividends part have to be a smart contract implementing the interface `ICMTATSnapshot` as described in the CMTAT. This interface is responsible to provide information on the  token holder's balance and the total supply for a specific time.

## Audits

The contracts are NOT audited, do not use them for production without auditing them !!!!

A report performed with [Slither](https://github.com/crytic/slither) is available in [doc/audits/tools](./doc/audits/tools/slither-report.md)

## Documentation

Here a summary of the main documentation

| Document                | Link/Files                               |
| ----------------------- | ---------------------------------------- |
| Specification           | [doc/specification](./doc/specification) |
| Technical documentation | [doc/technical](./doc/technical)         |
| Toolchain               | [doc/TOOLCHAIN.md](./doc/TOOLCHAIN.md)   |
| Surya report            | [doc/surya](./doc/surya/)                |

## Foundry

The project is developed with [Foundry](https://book.getfoundry.sh)

### Initialization

You must first initialize the submodules, with

```
forge install
```

See also the command's [documentation](https://book.getfoundry.sh/reference/forge/forge-install).

Later you can update all the submodules with:

```
forge update
```

See also the command's [documentation](https://book.getfoundry.sh/reference/forge/forge-update).



### Compilation

The official documentation is available in the Foundry [website](https://book.getfoundry.sh/reference/forge/build-commands) 

```
 forge build --contracts src/IncomeVault.sol
```

### Testing

You can run the tests with

```
forge test
```

To run a specific test, use

```
forge test --match-contract <contract name> --match-test <function name>
```

See also the test framework's [official documentation](https://book.getfoundry.sh/forge/tests), and that of the [test commands](https://book.getfoundry.sh/reference/forge/test-commands).

#### Coverage

> Unfortunately, tests are performed with a proxy deployment and the coverage command does not work currently in this configuration

* Perform a code coverage

```
forge coverage --ffi
```

* Generate LCOV report

```
forge coverage --ffi --report lcov
```

- Generate `index.html`

```bash
forge coverage --ffi --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage
```

See [Solidity Coverage in VS Code with Foundry](https://mirror.xyz/devanon.eth/RrDvKPnlD-pmpuW7hQeR5wWdVjklrpOgPCOA-PJkWFU) &  [Foundry forge coverage](https://www.rareskills.io/post/foundry-forge-coverage)
