# TOOLCHAIN

<!-- toc -->

- [Dependencies](#dependencies)
- [Node.JS  package](#nodejs--package)
  - [Dev](#dev)
- [Submodule](#submodule)
- [Generate documentation](#generate-documentation)
  - [docgen](#docgen)
  - [sol2uml](#sol2uml)
  - [Surya](#surya)
  - [Slither](#slither)
- [Coverage](#coverage)
- [Code style guidelines](#code-style-guidelines)

<!-- /toc -->

## Dependencies

The toolchain includes the following components, where the versions are the latest ones that we tested:

- Solidity 0.8.36, EVM target `prague`
- OpenZeppelin Contracts (submodule) [v5.7.0](https://github.com/OpenZeppelin/openzeppelin-contracts/releases/tag/v5.7.0)
- OpenZeppelin Contracts Upgradeable (submodule) [v5.7.0](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/releases/tag/v5.7.0)
- OpenZeppelin Foundry Upgrades (submodule) [v0.4.2](https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades/releases/tag/v0.4.2)
- CMTAT [v3.3.0-rc3](https://github.com/CMTA/CMTAT/releases/tag/v3.3.0-rc3)
- RuleEngine [v3.0.0-rc5](https://github.com/CMTA/RuleEngine/releases/tag/v3.0.0-rc5)
- SnapshotEngine [v0.5.0](https://github.com/CMTA/SnapshotEngine/releases/tag/v0.5.0)
- forge-std [v1.16.1](https://github.com/foundry-rs/forge-std/releases/tag/v1.16.1)

> CMTAT v3.3.0 and RuleEngine v3.0.0 are still release candidates. They are the versions the CMTA ecosystem is aligned on: RuleEngine v3.0.0-rc5 pins CMTAT v3.3.0-rc3, and SnapshotEngine v0.5.0 pins CMTAT v3.3.0-rc1. Pin them to a stable release as soon as one is published.

## Node.JS  package

This part describe the list of libraries present in the file `package.json`.

### Dev

This section concerns the packages installed in the section `devDependencies` of package.json

[hardhat-foundry](https://hardhat.org/hardhat-runner/docs/advanced/hardhat-and-foundry)

[Hardhat](https://hardhat.org/) plugin for integration with Foundry

**[Ethlint](https://github.com/duaraghav8/Ethlint)** Solidity static analyzer.

**[prettier-plugin-solidity](https://github.com/prettier-solidity/prettier-plugin-solidity)**

A [Prettier plugin](https://prettier.io/docs/en/plugins.html) for automatically formatting your [Solidity](https://github.com/ethereum/solidity) code.

#### Documentation

**[sol2uml](https://github.com/naddison36/sol2uml)**

Generate UML for smart contracts

**[solidity-docgen](https://github.com/OpenZeppelin/solidity-docgen)**

Program that extracts documentation for a Solidity project.

**[Surya](https://github.com/ConsenSys/surya)**

Utility tool for smart contract systems.



## Submodule

**[OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)** OpenZeppelin Contracts The version of the library used is available in the [READEME](../README.md)

Warning:
- Submodules are not automatically updated when the host repository is updated.
- Only update the module to a specific version, not an intermediary commit.



## Generate documentation

### [docgen](https://github.com/OpenZeppelin/solidity-docgen)

>Solidity-docgen is a program that extracts documentation for a Solidity project.

```
npx hardhat docgen 
```

### [sol2uml](https://github.com/naddison36/sol2uml)

>Generate UML for smart contracts

You can generate UML for smart contracts by running the following command:

```bash
npm run-script uml
npm run-script uml:test
```

Or only specified contracts

```
npx sol2uml class -i -c src/deployment/IncomeVault.sol
```



The related component can be installed with `npm install` (see [package.json](./package.json)).

### [Surya](https://github.com/ConsenSys/surya)

Three bash scripts in [doc/script](./script) regenerate the whole documentation set — one call graph, one inheritance graph and one markdown report per `.sol` file under `src/`:

```bash
npm run-script surya:graph          # doc/script/script_surya_graph.sh
npm run-script surya:inheritance    # doc/script/script_surya_inheritance.sh
npm run-script surya:report         # doc/script/script_surya_report.sh
```

Run `surya:graph` **first**: it creates the scratch directory `docOut/` with `mkdir -p`, which the two other scripts expect to already exist.

The output lands in `docOut/{surya_graph,surya_inheritance,surya_report}` at the repository root. Replace the committed directories under [doc/surya](./surya) with it, deleting the old ones first so the diagrams of a renamed or removed contract do not survive:

```bash
rm -rf doc/surya/surya_graph doc/surya/surya_inheritance doc/surya/surya_report
mkdir -p doc/surya/surya_graph doc/surya/surya_inheritance doc/surya/surya_report
mv docOut/surya_graph/*       doc/surya/surya_graph/
mv docOut/surya_inheritance/* doc/surya/surya_inheritance/
mv docOut/surya_report/*      doc/surya/surya_report/
rm -rf docOut
```

Graphviz (`dot`) is required — without it the scripts silently produce 0-byte PNGs. To generate a single graph by hand:

```bash
npx surya graph src/deployment/IncomeVault.sol | dot -Tpng > surya_graph_IncomeVault.png
```

> Known `surya graph` bug: it crashes on a contract calling `super.<fn>()` when the base is declared in another file, and because the scripts pipe into `dot` the crash shows up as an empty PNG rather than an error. Check for `find doc/surya -name '*.png' -size 0` after regenerating.

### [Slither](https://github.com/crytic/slither)

>Slither is a Solidity static analysis framework written in Python3

```bash
 slither .  --checklist --filter-paths "openzeppelin-contracts|test|CMTAT|forge-std" > slither-report.md
```



## Coverage

```bash
make coverage           # summary table in the terminal
make coverage-report    # HTML in doc/coverage (needs lcov + genhtml)
```

`doc/coverage/` is **generated and git-ignored**. It is not committed on purpose: a coverage report goes stale on the next contract change, and this repository already carried another project's coverage output — `RuleEngine.sol`, `RuleWhitelist.sol`, `RuleSanctionList.sol` — for long enough that it read as authoritative. A report describing the wrong codebase is worse than no report. `make coverage-report` also drops a `README.md` into that directory, copied from `doc/script/coverage-README.md`, since genhtml recreates the directory each run.

Coverage **does** work here, contrary to an older note in the agent guides: the suite runs under it despite deploying through a proxy. Current figures are roughly 96% of lines and 98% of branches.

Two files report **0%**, which is expected rather than a gap: `IncomeVaultSnapshotCore` and `IncomeVaultValidationCore` declare hooks with no bodies, so there is nothing in them to execute. Function coverage is the least useful of the four figures for the same reason — it counts the empty `_authorize*` overrides, whose whole purpose is to carry a modifier.

Scope is `src/` only:

```
forge coverage --ffi --exclude-tests --no-match-coverage '(test|mocks?|script)/'
```

`--ffi` is required, as everywhere else: the OpenZeppelin Upgrades plugin shells out to `@openzeppelin/upgrades-core`.

## Code style guidelines

We use the following tools to ensure consistent coding style:

[Prettier](https://github.com/prettier-solidity/prettier-plugin-solidity)

```
npm run-script lint:sol:prettier 
```

[Ethlint / Solium](https://github.com/duaraghav8/Ethlint)

```
npm run-script lint:sol 
npm run-script lint:sol:fix 
npm run-script lint:sol:test 
npm run-script lint:sol:test:fix
```

The related components can be installed with `npm install` (see [package.json](./package.json)).
