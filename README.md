# IncomeVault

The `IncomeVault` is a prototype to perform coupon-payment dividend with a token supporting on-chain snapshots, typically a [CMTAT](https://github.com/CMTA/CMTAT) bound to a [SnapshotEngine](https://github.com/CMTA/SnapshotEngine).

![IncomeVault architecture](./doc/schema/plantuml/incomevault-architecture.png)

_Diagram source: [doc/schema/plantuml/incomevault-architecture.puml](./doc/schema/plantuml/incomevault-architecture.puml).
The detailed step-by-step flow is in [doc/README.md](./doc/README.md)._

> This project has not undergone an audit and is provided as-is without any warranties.

## Introduction

The dividends are deposited in a Vault. Once the claims are open, a token holder can then perform a claim to get his dividends for a given period.

Currently, the vault supports only dividend under the form of another ERC-20 and it is suitable for the following use-case:

- Dividends in ERC-20 compatible, which could be an ERC-20 stablecoin such as USDC or USDT for example
- Interest paid out at given intervals which shall be a configurable parameter (i.e. every 6 months, every 1 year)

The `IncomeVault` is **not** an [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) tokenized vault, and deliberately so: an ERC-4626 share entitles whoever holds it *now*, whereas a dividend must be allocated to whoever held the security token at a **record date**. See [Comparison with ERC-4626 / ERC-7540 vaults](./doc/README.md#comparison-with-erc-4626--erc-7540-vaults) for the full comparison, including when a 4626 vault *is* the right tool.

For the specific case where dividends are distributed in shares, meaning additional payout of the “existing” CMTAT Token, it is not currently supported due to the following reasons:
\- With the current architecture, depending on when you decide to mint the new tokens, you will increase the total supply used to compute the token holder shares. Therefore, you will reduce the dividends distributed to the token holders.
\- In general, for yield tokens, the formula used can be different.

## Compatibility

- The dividends can be paid with ERC-20 tokens as described in the [ERC-20](https://eips.ethereum.org/EIPS/eip-20) specification
- The shares used to compute the dividends part are read through the interface `ISnapshotSource` (`src/interfaces/ISnapshotSource.sol`), a strict subset of `ISnapshotState` as defined in the [SnapshotEngine](https://github.com/CMTA/SnapshotEngine) repository. It declares only the three functions the vault calls, so any `ISnapshotState` implementation satisfies it and a custom provider does not have to implement the five it would never use.

The vault is **not** tied to the CMTAT: any contract implementing `ISnapshotState` can be used as the snapshot source, for example

- the external `SnapshotEngine` bound to a CMTAT or to any other ERC-20,
- a token embedding the snapshot modules directly (`CMTATStandaloneInternalSnapshot`, `CMTATUpgradeableInternalSnapshot`),
- any custom contract exposing `snapshotInfo` / `snapshotInfoBatch`.

The address is provided at initialization and is exposed by the public getter `dividendSnapshotSource()`.
The vault reaches it through the three hooks of `IncomeVaultSnapshotCore`, so a token that already records
snapshots can answer them from itself instead of pointing at a separate contract.

## Audits

The contracts are NOT audited, do not use them for production without auditing them !

Static analysis is run with [Slither](https://github.com/crytic/slither) and [Aderyn](https://github.com/Cyfrin/aderyn). 

Every finding is triaged in a feedback file rather than left as a raw count, and the whole picture is summarised in [doc/audits/AUDIT_OVERVIEW.md](./doc/audits/AUDIT_OVERVIEW.md).

| Version | Tool | Result | Report | Triage |
| --- | --- | --- | --- | --- |
| v1.1.0 | Slither 0.11.5 | 0 High · 5 Med · 6 Low · 23 Info — nothing to fix | [report](./doc/audits/tools/v1.1.0/slither-report.md) | [feedback](./doc/audits/tools/v1.1.0/slither-report-feedback.md) |
| v1.1.0 | Aderyn 0.6.5 | 0 High · 10 Low — nothing to fix | [report](./doc/audits/tools/v1.1.0/aderyn-report.md) | [feedback](./doc/audits/tools/v1.1.0/aderyn-report-feedback.md) |
| v1.0.0 | Slither | superseded — predates the CMTAT v3 migration | [report](./doc/audits/tools/v1.0.0/slither-report.md) | — |

```bash
slither . --checklist --filter-paths "node_modules,lib,test" \
  > doc/audits/tools/v1.1.0/slither-report.md
aderyn -x mocks --output doc/audits/tools/v1.1.0/aderyn-report.md
```

Both runs exclude mocks and tests. Filter on `lib` rather than on dependency names: this is a Foundry project, and a name-based filter silently puts the whole vendored tree in scope when a dependency it does not list is added. 

Check `grep -c 'lib/\|node_modules/' <report>` returns 0 before trusting any count.

## Documentation

Here a summary of the main documentation

| Document                              | Link/Files                                             |
| ------------------------------------- | ------------------------------------------------------ |
| Specification & technical choice      | [doc/README.md](./doc/README.md)                       |
| Solidity API (docgen)                 | [doc/solidityAPI/index.md](./doc/solidityAPI/index.md) |
| Toolchain                             | [doc/TOOLCHAIN.md](./doc/TOOLCHAIN.md)                 |
| Surya report                          | [doc/surya](./doc/surya/)                              |

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
 forge build --contracts src/deployment/IncomeVault.sol
```

### Testing

You can run the tests with

```
make test
```

`make help` lists every target. Use `make test` rather than `forge test` directly:

> The OpenZeppelin Foundry Upgrades plugin validates upgrade safety from Foundry's build-info and **rejects the output of an incremental compile**. 
>
> Running `forge test --ffi` straight after editing a contract therefore fails *every* test with
> `Failed to run upgrade safety validation: … Build info file … is not from a full compilation`, which names neither the cause nor the fix. `make test` does the full build first. (`--ffi` is required for the same reason: the plugin shells out to `@openzeppelin/upgrades-core`.)

Other useful targets:

```
make install          # submodules + npm dependencies
make coverage         # line/branch/function coverage of src/
make coverage-report  # the same, as HTML in doc/coverage
make gas              # gas report
make fmt-check lint   # formatting and lint
make doc              # regenerate the UML and Surya diagrams
```

`npm run test`, `npm run build`, `npm run coverage` and `npm run lint` delegate to the same targets, so there is one definition rather than two.

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
