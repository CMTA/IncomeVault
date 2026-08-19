# IncomeVault

> This project is not audited !
>
> If you want to use this project, perform your own verification or send an email to [admin@cmta.ch](mailto:admin@cmta.ch).

The `IncomeVault` is a prototype to perform coupon-payment dividend with a token supporting on-chain snapshots, typically a [CMTAT](https://github.com/CMTA/CMTAT) bound to a [SnapshotEngine](https://github.com/CMTA/SnapshotEngine).

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
- The shares used to compute the dividends part are read through the interface `ISnapshotState`, defined in the [SnapshotEngine](https://github.com/CMTA/SnapshotEngine) repository. This interface is responsible to provide information on the token holder's balance and the total supply for a specific time.

The vault is **not** tied to the CMTAT: any contract implementing `ISnapshotState` can be used as the snapshot source, for example

- the external `SnapshotEngine` bound to a CMTAT or to any other ERC-20,
- a token embedding the snapshot modules directly (`CMTATStandaloneInternalSnapshot`, `CMTATUpgradeableInternalSnapshot`),
- any custom contract exposing `snapshotInfo` / `snapshotInfoBatch`.

The address is provided at initialization through the parameter `snapshotEngine_` and is exposed by the public getter `snapshotEngine()`.

## Audits

The contracts are NOT audited, do not use them for production without auditing them !!!!

A report performed with [Slither](https://github.com/crytic/slither) is available in [doc/audits/tools](./doc/audits/tools/slither-report.md)

## Documentation

Here a summary of the main documentation

| Document                | Link/Files                                             |
| ----------------------- | ------------------------------------------------------ |
| Specification           | [doc/README.md](./doc/README.md)                       |
| Technical documentation | [doc/technical.md](./doc/technical.md)                 |
| Solidity API (docgen)   | [doc/solidityAPI/index.md](./doc/solidityAPI/index.md) |
| Toolchain               | [doc/TOOLCHAIN.md](./doc/TOOLCHAIN.md)                 |
| Surya report            | [doc/surya](./doc/surya/)                              |

## Foundry

The project is developed with [Foundry](https://book.getfoundry.sh)

### Initialization

You must first initialize the submodules, with

```
git submodule update --init --recursive
```

The upgrade safety validation performed by the [OpenZeppelin Foundry Upgrades](https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades) plugin requires `@openzeppelin/upgrades-core`:

```
npm install
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
forge clean && forge build
forge test --ffi
```

> `--ffi` is required: the tests deploy the vault behind a transparent proxy with the OpenZeppelin
> Foundry Upgrades plugin, whose validation runs `@openzeppelin/upgrades-core` and needs a **full**
> (non incremental) build, hence the `forge clean` before `forge build`.

To run a specific test, use

```
forge test --match-contract <contract name> --match-test <function name>
```

See also the test framework's [official documentation](https://book.getfoundry.sh/forge/tests), and that of the [test commands](https://book.getfoundry.sh/reference/forge/test-commands).

#### Coverage

> Unfortunately, tests are performed with a proxy deployment and the coverage command does not work currently in this configuration.

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
