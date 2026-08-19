# IncomeVault — Agent Guide

> **Note — keep in sync:** `AGENTS.md` and `CLAUDE.md` must always be **identical**.
> Any edit to one must be applied verbatim to the other.

> **Note — commit messages:** After each group of modifications or each feature
> added, always provide a **one-line GitHub commit message** (Conventional-Commits
> style, e.g. `feat: ...`, `fix: ...`, `docs: ...`).
>
> **Never put `!` in a commit message** — not as the breaking-change marker
> (`feat!: ...`), not anywhere else. In an interactive bash, `!` inside double quotes
> triggers history expansion, so `git commit -m "feat!: ..."` aborts with
> `bash: !: unrecognized history modifier`. Signal a breaking change with an
> uppercase `BREAKING CHANGE:` line in the commit body instead, and keep the subject
> line free of `!`.

## What this project is

`IncomeVault` is a CMTA prototype smart contract that distributes coupon/dividend
payments to the holders of a security token. Dividends are deposited in the vault in an
**ERC-20 payment token** (e.g. USDC), segregated per distribution date (`time`), and claimed
pro-rata using an on-chain snapshot read through the **`ISnapshotState`** interface
([SnapshotEngine](https://github.com/CMTA/SnapshotEngine)).

The vault is **token agnostic**: it never calls the token, only the snapshot source. Any contract
implementing `ISnapshotState` works — the external `SnapshotEngine` bound to a CMTAT (or to any
ERC-20), a token embedding the snapshot modules, or a custom implementation.

> **The contracts are NOT audited.** Do not present them as production-ready.

## Key concepts

- **Segregated deposits by `time`** — `time` is a Unix timestamp identifying a
  distribution. State is keyed by it: `segregatedDividend[time]`,
  `segregatedClaim[time]`, `claimedDividend[holder][time]`.
- **Claim flow** — the snapshot source schedules a snapshot at `time` → deposit role calls
  `deposit(time, amount)` → operator calls `setStatusClaim(time, true)` → holders
  call `claimDividend(time)` / `claimDividendBatch(times)`.
- **Snapshot source** — `snapshotEngine` (`ISnapshotState`), set at initialization, never zero.
  Only `snapshotInfo` and the two `snapshotInfoBatch` overloads are used.
- **Pro-rata formula** — `senderDividend = (senderBalance * segregatedDividend[time]) / tokenTotalSupply`,
  rounded down. Dust stays in the vault; the issuer withdraws it after `timeLimitToWithdraw`.
- **Claim window** — `validateTime` / `validateTimeCode` reject a claim when the
  claim is not activated, `block.timestamp < time` (too early), or
  `block.timestamp > time + timeLimitToWithdraw` (too late).
- **Access control — authorization-hook pattern.** The logic contracts declare *what* is protected:
  one `internal view virtual` hook per capability, invoked by a modifier, declared **without a body**.
  The deployment contract declares *who*: `IncomeVault` overrides every hook with `onlyRole(...)`,
  `IncomeVaultOwnable2Step` with `onlyOwner`. The two are chosen at deployment and are not
  interchangeable. Capability table: `doc/README.md` → Access control.
- **Transfer restriction** — a claim is treated as a transfer from the vault to the holder and goes
  through `IncomeVaultValidationModule`: pause, address freeze, and an optional `IRuleEngine`.
  Rejected payouts revert with `IncomeVault_InvalidTransfer(from, to, value)`.
- **RuleEngine is read-only here** — the vault uses `IRuleEngine.canTransfer` only. It is not a
  bound token, so `transferred(...)` would revert, and a payout must not mutate stateful rules.
- **Upgradeable** — deployed behind an OpenZeppelin **Transparent Proxy**;
  `initialize(...)` replaces the constructor. State is held in an **ERC-7201** namespaced struct
  (`IncomeVault.storage.IncomeVaultInternal`, slot `0xe4f8b033…0c00`), as in OZ Upgradeable and
  CMTAT v3 — there is no `__gap` and no sequential storage slot.
- **Gasless / meta-tx** — inherits CMTAT's `ERC2771Module` (ERC-2771). The forwarder address is set
  in the constructor and is **immutable**. `_msgSender()`, `_msgData()` and
  `_contextSuffixLength()` are overridden to resolve the
  `ERC2771ContextUpgradeable` / `ContextUpgradeable` diamond.
- **Reentrancy** — claims use `nonReentrant` from `ReentrancyGuardTransient` (EIP-1153);
  `_transferDividend` sets `claimedDividend[holder][time] = true` *before* the ERC-20 transfer.

## File tree

```
src/
├── IncomeVaultBase.sol                    # Policy-agnostic logic: modules, __IncomeVaultBase_init_unchained,
│                                          #   ERC-2771 _msgSender/_msgData overrides. Hooks left abstract.
├── IncomeVault.sol                        # Deployment: AccessControlModule; 8 hooks -> onlyRole(...)
├── IncomeVaultOwnable2Step.sol            # Deployment: Ownable2StepUpgradeable; 8 hooks -> onlyOwner
├── modules/
│   └── IncomeVaultValidationModule.sol    # AccessControl + Pause + Enforcement + RuleEngine;
│                                          #   canTransfer, setRuleEngine, detectTransferRestriction
├── public/
│   ├── IncomeVaultOpen.sol                # Permissionless: claimDividend, claimDividendBatch, validateTime(Code|Batch)
│   └── IncomeVaultRestricted.sol          # Role-gated: deposit, withdraw, withdrawAll, distributeDividend,
│                                          #   setStatusClaim, setTimeLimitToWithdraw
└── libraries/
    ├── IncomeVaultInternal.sol            # ERC-7201 storage struct + getters, _computeDividend(Batch),
    │                                      #   _transferDividend, _set{SnapshotEngine,ERC20TokenPayment,TimeLimitToWithdraw}
    ├── IncomeVaultInvariantStorage.sol    # Custom errors and events shared by every variant
    ├── IncomeVaultRolesStorage.sol        # The four INCOME_VAULT_*_ROLE constants — inherited ONLY by IncomeVault
    └── Ownable2StepERC165Module.sol       # ERC-165 advertisement of ERC-173 / Ownable2Step

test/
├── HelperContract.sol                     # Constants + `_deployContracts()`: CMTAT, SnapshotEngine, payment token, proxy
├── mocks/ERC20PaymentMock.sol             # Minimal ERC-20 used as payment token
├── IncomeVault.t.sol                      # Single claim: deposit, claim, pause, freeze, error cases
├── IncomeVaultStorage.t.sol               # ERC-7201: slot derivation, field offsets, getters
├── AccessControlHooks.t.sol               # Both variants: every hook accepts/rejects, role separation,
│                                          #   Ownable2Step handover, ERC-165
├── IncomeVaultBatch.t.sol                 # claimDividendBatch behaviour
├── IncomeVaultRestricted.t.sol            # Access control, deposit/withdraw/withdrawAll, distributeDividend
└── RuleEngineIntegration.t.sol            # End-to-end with RuleEngine + RuleWhitelistMock
```

Tests deploy the vault through `Upgrades` (openzeppelin-foundry-upgrades), which requires `--ffi`,
`@openzeppelin/upgrades-core` from npm, and a **full** build (`forge clean && forge build`).

## Other important files

| Path | Purpose |
| --- | --- |
| `foundry.toml` | solc 0.8.36, optimizer 200 runs, EVM `prague`, `ffi`, `ast`, `build_info`, `storageLayout`, `fs_permissions` on `./out` (needed by OZ Upgrades) |
| `remappings.txt` | `CMTAT/`, `RuleEngine/`, `SnapshotEngine/`, `OZ/`, `OZUpgradeable/`, `@openzeppelin/*`, `openzeppelin-foundry-upgrades/`, `forge-std/` |
| `hardhat.config.js` | Only used for `solidity-docgen` (`npx hardhat docgen`), mirrors the Foundry solc settings |
| `package.json` | npm scripts: lint (ethlint/prettier), `uml`, `surya:*`, `docgen`; dependency `@openzeppelin/upgrades-core` |
| `.soliumrc.json`, `.soliumignore` | Ethlint/Solium configuration |
| `CHANGELOG.md` | changelog.md conventions; current release `2.0.0` |
| `doc/README.md` | The reference doc: snapshot source, roles table, claim restrictions, formula, threat model & FAQ, plus the technical choices (upgradeability, pause, token agnosticism, reentrancy, gasless GSN/ERC-2771) and the schema/graphs |
| `doc/TOOLCHAIN.md` | Tested dependency versions, doc-generation and lint commands |
| `doc/solidityAPI/index.md` | Generated Solidity API (docgen) — stale since the CMTAT v3 migration, refresh with `npx hardhat docgen` |
| `doc/surya/`, `doc/schema/` | Surya call graphs, inheritance graphs and markdown reports (one per `src/**/*.sol`), UML class diagram, PlantUML sources and the remaining drawio diagrams. Regenerate with `npm run surya:graph` + `surya:inheritance` + `surya:report` (output goes to the scratch `docOut/`, then replaces `doc/surya/`) and `npm run uml` |
| `doc/schema/plantuml/` | PlantUML sources (`.puml`) and their rendered `.png`. The `.puml` is the source of truth — edit it, then re-render with `plantuml -tpng doc/schema/plantuml/<name>.puml` and **look at the PNG**: PlantUML exits 0 on warnings and draws them into the image as a yellow banner. Embed the image in the docs, never the source text |
| `doc/audits/tools/slither-report.md` | Slither static-analysis report — stale |
| `.github/workflows/ci.yml` | CI: recursive checkout, `npm install`, `forge clean && forge build --sizes`, `forge test -vvv --ffi` |

## Dependencies (tested versions)

- Solidity **0.8.36**, EVM target `prague` (contracts declare `pragma ^0.8.24`)
- CMTAT **v3.3.0-rc3** (submodule `lib/CMTAT`)
- RuleEngine **v3.0.0-rc5** (submodule `lib/RuleEngine`)
- SnapshotEngine **v0.5.0** (submodule `lib/SnapshotEngine`)
- openzeppelin-contracts **v5.7.0** (submodule)
- openzeppelin-contracts-upgradeable **v5.7.0** (submodule)
- openzeppelin-foundry-upgrades **v0.4.2** (submodule)
- forge-std **v1.16.1** (submodule)

CMTAT v3.3.0 and RuleEngine v3.0.0 are release candidates — they are what the CMTA ecosystem is
currently aligned on (RuleEngine v3.0.0-rc5 pins CMTAT v3.3.0-rc3). Submodules are **not** updated
automatically — pin them to a release tag, never to an intermediary commit.

## Common commands

```bash
git submodule update --init --recursive    # initialize submodules (required first)
npm install                                # @openzeppelin/upgrades-core, needed by the Upgrades plugin

forge clean && forge build                 # a FULL build is required by the upgrade safety validation
forge build --sizes                        # as run in CI
forge test --ffi                           # --ffi is mandatory (OZ Upgrades plugin)
forge test --ffi --match-contract IncomeVaultTest --match-test testHolderCanClaimWithDepositAndOneHolder
forge coverage --ffi                       # known not to work with the proxy deployment

npm run lint:sol                           # ethlint on src/
npm run lint:sol:prettier                  # prettier-plugin-solidity
npm run surya:graph && npm run surya:inheritance && npm run surya:report   # then replace doc/surya/ with docOut/
npm run uml && npx hardhat docgen

slither . --checklist --filter-paths "openzeppelin-contracts|test|CMTAT|RuleEngine|SnapshotEngine|forge-std" > slither-report.md
```

## Conventions & invariants

- **Versioning:** `CHANGELOG.md` follows [changelog.md](https://changelog.md/);
  add an entry for any user-visible contract change.
- **Upgrade safety:** the state lives in the ERC-7201 struct `IncomeVaultInternalStorage`
  (namespace `IncomeVault.storage.IncomeVaultInternal`). Append new fields to the **end** of that
  struct; never reorder or remove existing ones. Do **not** reintroduce `uint256[50] private __gap`
  — namespaced storage replaces it, and the contract must keep declaring zero sequential slots.
  A new module with its own state gets its own namespace, never a sequential variable; recompute
  its slot with `SlotDerivation.erc7201Slot()` and keep the derivation comment above the constant.
  `IncomeVault` has an `/// @custom:oz-upgrades-unsafe-allow constructor` annotation
  — keep it and keep `_disableInitializers()` in the constructor.
- **Authorization hooks:** a hook is `internal view virtual` on the declaration **and on every
  override** — `view` is what makes "an auth hook cannot mutate state" compiler-enforced, and it is
  free. CMTAT declares its hooks non-`view`; overriding them `view` is legal (an override may
  tighten mutability) and is what this project does. Override bodies stay **empty**, with the check
  riding on the modifier (`onlyRole(...)` / `onlyOwner`), never a bare `_checkRole` call. A new
  guarded capability means a new hook plus an override in **every** deployment variant.
- **Role constants live with the layer that enforces them.** They belong in
  `IncomeVaultRolesStorage`, inherited only by `IncomeVault` — never in `IncomeVaultInvariantStorage`,
  or the Ownable variant would publish a role it never checks.
- **`@inheritdoc` needs the base imported by name** in the referencing file, even when it is already
  in scope through inheritance; otherwise the build fails with "references inexistent contract".
- **Claim accounting:** always set `claimedDividend[holder][time]` before any
  external call; keep `nonReentrant` on the claim entry points.
- **Deposits vs. open claims:** do not deposit for a `time` whose claim status is
  already `true` — it dilutes holders who have not yet claimed.
- **ERC-20 safety:** use `SafeERC20` (`safeTransfer` / `safeTransferFrom`) for the
  payment token.
- **Style:** 4-space indent, NatSpec (`@notice` / `@param` / `@dev`) on public and
  internal functions, custom errors prefixed `IncomeVault_`, named imports
  (`import {X} from "..."`), `SPDX-License-Identifier: MPL-2.0` header on every Solidity file.
- **Documentation:** the README and `doc/` must state that the contracts are not
  audited; keep that disclaimer intact.

## Known quirks (verify before "fixing")

- `distributeDividend` deliberately bypasses the ValidationModule (no pause / freeze / RuleEngine
  check): it is an issuer-driven push, unlike the holder-driven claims.
- The `newDeposit` event keeps its lowercase name for backward compatibility with the v1 ABI.
- `IncomeVaultInvariantStorage` declares `event SnapshotEngineSet`, not `SnapshotEngine`, so the
  name does not collide with the `SnapshotEngine` contract in tests and integrations.
- `forge coverage` does not work here — the tests deploy through a proxy.
