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

- **Not an ERC-4626 vault, deliberately** — a 4626 share entitles whoever holds it *now*; a dividend is
  allocated by **record date**. `doc/README.md` → "Comparison with ERC-4626 / ERC-7540 vaults" has the
  full reasoning and the cases where 4626/7540 *would* be right. Do not "standardise" this onto 4626.
- **Segregated deposits by `time`** — `time` is a Unix timestamp identifying a
  distribution. State is keyed by it: `segregatedDividend[time]`,
  `segregatedClaim[time]`, `claimedDividend[holder][time]`.
- **Claim flow** — the snapshot source schedules a snapshot at `time` → deposit role calls
  `deposit(time, amount)` → operator calls `setStatusClaim(time, true)` → holders
  call `claimDividend(time)` / `claimDividendBatch(times)`.
- **The EIP-712 domain version is `"1"` and must stay `"1"`.** It is set in
  `__IncomeVaultBase_init_unchained`; bumping it with a release would invalidate every ERC-7741
  signature already issued. ERC-7741's id `0xa9e50872` **is** advertised through `supportsInterface`
  (the standard requires it) — unlike ERC-7540's operator id, which is not.
- **`IIncomeVault` is the stated API and is compiler-enforced.** It is inherited by
  `IncomeVaultInternal`, the common base of both payout paths, so every deployable *and* any embedded
  host implements it — add a public function to the distribution surface and you add it here too. It
  owns the `TIME_ERROR_CODE` enum, because `validateTimeCode` returns it. Keep it inheriting **nothing**:
  `type(...).interfaceId` covers only directly-declared selectors, and both deployment variants
  advertise that id.
- **Directory layout says what a file *is*.** `deployment/` holds only deployable contracts,
  `modules/` only abstract capability mixins, `storage/` only declarations, `interfaces/` only
  interfaces, and `IncomeVaultBase.sol` is the single composition root at the root. **`public/` is the
  exception and is deliberate** (M-5): it groups the external surface by *who may call*, because on a
  compliance contract the gated/ungated boundary is the first thing a reviewer checks. Do not merge
  `IncomeVaultOpen` and `IncomeVaultRestricted` into one "distribution module".
- **One capability, one module, one ERC-7201 namespace.** The project runs four namespaces:
  `IncomeVaultInternal` (distribution), `SnapshotSource`, `Operator` and `ERC7741Module`. Claim
  delegation is `IncomeVaultOperatorModule`, not a mapping in the distribution struct (M-6). A new
  capability with state gets its own namespace — never a field appended to someone else's.
- **Claim delegation reuses ERC-7540's operator signatures exactly.** `IERC7540Operator` must keep
  `type(...).interfaceId == 0xe3bc4e65`; a test asserts it. Do **not** add that id to
  `supportsInterface` — the vault is not an asynchronous vault and must not advertise as one.
- **Snapshot source** — reached through the three hooks of `IncomeVaultSnapshotCore`, never a direct
  call. `IncomeVaultSnapshotModule` is the standalone answer: an `ISnapshotSource` set at initialization,
  never zero, exposed by `dividendSnapshotSource()` and stored in its **own** ERC-7201 namespace.
  `ISnapshotSource` (`src/interfaces/ISnapshotSource.sol`) declares exactly the three functions the vault
  calls — a strict subset of the SnapshotEngine's `ISnapshotState`, signatures verbatim, so every
  `ISnapshotState` implementation satisfies it. **Do not add an ERC-165 guard on it**: the canonical
  `SnapshotEngine` advertises no id for it and the guard would reject it. If the vault ever needs a
  fourth function, add it here — not by widening back to `ISnapshotState`.
- **`transferDividendSelf` is a self-call helper with no role check.** Its only protection is
  `msg.sender == address(this)` (raw `msg.sender`, never `_msgSender()`, so a forwarder cannot
  impersonate the vault). It exists because `try`/`catch` needs an external call. Never relax that
  guard, and never add another public entry point to `_transferDividend`.
- **Every payout must come out of its own period.** `_transferDividend` refuses an amount larger than
  `unclaimedDividend(time)`. Without it, a claim made after a mid-window sweep is funded from another
  period's deposit. Unreachable in normal operation — a period's entitlements sum to at most its
  deposit — so the check only bites when a period has been over-swept.
- **`segregatedDividend` is the pro-rata denominator, not a balance.** It is fixed at the deposit for
  the whole period and never reduced by a payout. What a period still holds is
  `unclaimedDividend(time) = segregatedDividend - paidDividend`, and that is what bounds `withdraw`.
  Never bound a sweep by `segregatedDividend` alone — that let a fully-claimed period drain another
  period's funds.
- **`_setStatusClaim` is idempotent and owns `_openClaimCount`.** It is the only writer of the claim
  status; a repeated write returns early so the counter stays exact. `setDividendSnapshotSource` depends on
  that counter reaching zero, so any new path that changes a claim status must go through it.
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
- **The payout paths must not inherit a policy.** `IncomeVaultOpen`/`IncomeVaultRestricted` inherit
  `IncomeVaultValidationCore` (the `_validateTransfer` question) — never `IncomeVaultValidationModule`
  (one answer). The module is inherited by the **deployment** contracts, like the access-control base.
  Re-coupling them makes the logic unembeddable in any CMTAT: C3 fails with `Error (5005)`, which no
  override can repair. Same rule for the snapshot side: they inherit `IncomeVaultSnapshotCore` (the
  three questions) — never `IncomeVaultSnapshotModule` (one answer). `test/mocks/` holds the two
  compile-time guards: `EmbeddedDividendHostMock.sol` (a non-CMTAT host) and `CMTATDividendHostMock.sol`
  (a `CMTATUpgradeableInternalSnapshot` paying its own dividends).
- **`ReentrancyGuardTransient` is listed last** in the payout paths, matching CMTAT's ordering. Moving
  it earlier reintroduces the same unresolvable linearization failure.
- **Transfer restriction** — every payout, pull (`claimDividend`) **and** push (`distributeDividend`),
  goes through `IncomeVaultValidationModule`: pause, address freeze, and an optional `IRuleEngine`.
  Rejected payouts revert with `IncomeVault_InvalidTransfer(from, to, value)`; in a batch one blocked
  holder reverts the whole call rather than being skipped, so a compliance failure cannot be silently
  dropped. Any new payout path must call `_validateTransfer` too.
- **RuleEngine is read-only here** — the vault uses `IRuleEngine.canTransfer` only. It is not a
  bound token, so `transferred(...)` would revert, and a payout must not mutate stateful rules.
- **Upgradeable** — deployed behind an OpenZeppelin **Transparent Proxy**;
  `initialize(...)` replaces the constructor. State is held in an **ERC-7201** namespaced struct
  (`IncomeVault.storage.IncomeVaultInternal`, slot `0xe4f8b033…0c00`), as in OZ Upgradeable and
  CMTAT v3 — there is no `__gap` and no sequential storage slot.
- **Gasless / meta-tx is a deployment decision** (M-8). `IncomeVaultBase` has **no** ERC-2771;
  `IncomeVaultBaseERC2771` adds CMTAT's `ERC2771Module` plus the `_msgSender`/`_msgData`/
  `_contextSuffixLength` overrides that resolve the `ERC2771ContextUpgradeable` / `ContextUpgradeable`
  diamond, and both shipped deployments inherit that. The forwarder is set in the constructor and is
  **immutable**. Do not move `ERC2771Module` back into `IncomeVaultBase`: a forwarder can name any
  `_msgSender()`, so a deployment that does not want one must be able to not have one.
  `test/mocks/NoForwarderVaultMock.sol` is the guard.
- **Reentrancy** — claims use `nonReentrant` from `ReentrancyGuardTransient` (EIP-1153);
  `_transferDividend` sets `claimedDividend[holder][time] = true` *before* the ERC-20 transfer.

## File tree

```
src/
├── IncomeVaultBase.sol                    # The composition root: assembles the modules,
│                                          #   __IncomeVaultBase_init_unchained. Hooks left abstract.
│                                          #   NO access-control, NO validation, NO meta-tx policy.
├── IncomeVaultBaseERC2771.sol             # The base plus ERC-2771: forwarder constructor and the
│                                          #   _msgSender/_msgData/_contextSuffixLength overrides.
│                                          #   Both shipped deployments inherit THIS one.
├── deployment/                            # What you actually deploy — nothing abstract lives here
│   ├── IncomeVault.sol                    # AccessControlModule; every hook -> onlyRole(...)
│   └── IncomeVaultOwnable2Step.sol        # Ownable2StepUpgradeable; every hook -> onlyOwner
├── public/                                # The external surface, split by WHO MAY CALL. Deliberate:
│   │                                      #   the gated/ungated boundary is the thing a reviewer of a
│   │                                      #   compliance contract checks first. Do not merge these two.
│   ├── IncomeVaultOpen.sol                # Permissionless: claimDividend, claimDividendBatch, validateTime(Code|Batch)
│   └── IncomeVaultRestricted.sol          # Role-gated: deposit, withdraw, withdrawAll, distributeDividend,
│                                          #   setStatusClaim, setTimeLimitToWithdraw
├── modules/                               # Abstract capability mixins, one per capability
│   ├── IncomeVaultInternal.sol            # Distribution state: the ERC-7201 struct + getters,
│   │                                      #   _computeDividend(Batch), _transferDividend, _setStatusClaim
│   ├── IncomeVaultValidationCore.sol      # ONLY `_validateTransfer` — inherits nothing, keep it that way
│   ├── IncomeVaultValidationModule.sol    # Pause + Enforcement + RuleEngine; canTransfer,
│   │                                      #   setRuleEngine, detectTransferRestriction. Hooks abstract.
│   ├── IncomeVaultSnapshotCore.sol        # ONLY the 3 snapshot hooks — inherits nothing, keep it that way
│   ├── IncomeVaultSnapshotModule.sol      # One answer: a stored ISnapshotSource in its OWN ERC-7201
│   │                                      #   namespace; dividendSnapshotSource, setDividendSnapshotSource
│   ├── IncomeVaultOperatorModule.sol      # ERC-7540 claim delegation in its OWN ERC-7201 namespace;
│   │                                      #   setOperator, isOperator, _requireHolderOrOperator
│   ├── ERC7741Module.sol                  # EIP-712 signed operator authorisation, own ERC-7201 namespace
│   ├── VersionModule.sol                  # VERSION constant behind IERC3643Version.version()
│   └── Ownable2StepERC165Module.sol       # ERC-165 advertisement of ERC-173 / Ownable2Step
├── interfaces/
│   ├── IIncomeVault.sol                   # The stated distribution API + the TIME_ERROR_CODE enum;
│   │                                      #   inherited by IncomeVaultInternal so solc enforces it
│   ├── ISnapshotSource.sol                # The 3 snapshot functions the vault calls — subset of ISnapshotState
│   ├── IERC7540Operator.sol               # The ERC-7540 operator subset, verbatim; id MUST stay 0xe3bc4e65
│   └── IERC7741.sol                       # Signed operator authorisation; id MUST stay 0xa9e50872
└── storage/                               # Declaration-only: nothing here has behaviour
    ├── IncomeVaultInvariantStorage.sol    # Custom errors and events shared by every variant
    └── IncomeVaultRolesStorage.sol        # The four INCOME_VAULT_*_ROLE constants — inherited ONLY by IncomeVault

script/
├── DeployIncomeVault.s.sol                # role-based variant; `deploy(config)` split from `run()`
└── DeployIncomeVaultOwnable2Step.s.sol    # single-owner variant

test/
├── HelperContract.sol                     # Constants + `_deployContracts()` / `_deployOwnableVault()`
├── IncomeVault.t.sol                      # Single claim: deposit, claim, pause, freeze, error cases
├── IncomeVaultBatch.t.sol                 # claimDividendBatch behaviour
├── IncomeVaultRestricted.t.sol            # deposit/withdraw/withdrawAll/distributeDividend + access control
├── IncomeVaultStorage.t.sol               # ERC-7201: slot derivation, field offsets, the two namespaces
├── AccessControlHooks.t.sol               # Both variants: every hook accepts/rejects, role separation,
│                                          #   Ownable2Step handover, ERC-165
├── VersionModule.t.sol                    # version() on EVERY deployable contract — keep exhaustive
├── CodeQuality.t.sol                      # regressions for CLAUDE_ANALYSIS.md findings, incl. the
│                                          #   push/pull claim-window parity (H-1) and restrictions (H-2)
├── IncomeVaultInterface.t.sol             # M-7: drive a proxy through IIncomeVault alone, ERC-165 id,
│                                          #   embedded hosts present the same interface
├── SnapshotSource.t.sol                   # I-1: a 3-function source is enough; the real engine still fits
├── SetDividendSnapshotSource.t.sol        # M-2 setter: gated on openClaimCount() == 0, zero-address, event
├── RuleEngineIntegration.t.sol            # End-to-end with RuleEngine + RuleWhitelistMock
├── DistributeBestEffort.t.sol             # A-4: one blocked holder is skipped, not reverted
├── DepositBatch.t.sol                     # depositBatch, incl. the per-transaction gas comparison
├── UnclaimedDividend.t.sol                # E-3: saturating residue, per-period withdraw bound
├── Operator.t.sol                         # ERC-7540 operator subset: setOperator, claim-for
├── OperatorAuthorization.t.sol            # ERC-7741 signed authorisation, EIP-712, ERC-1271
├── Deactivate.t.sol                       # deactivateContract, permanent kill
├── EdgeCases.t.sol                        # zero supply, zero balance, boundary times
├── script/Deploy.t.sol                    # C-4: both deployment scripts, config validation
├── NoForwarderDeployment.t.sol            # M-8: a vault on the plain base has no isTrustedForwarder,
│                                          #   the shipped ones still do, and payouts work either way
├── invariant/                             # handler + 7 invariants; validate any change by sabotaging
│                                          #   the contract and checking an invariant actually fails
└── mocks/
    ├── ERC20PaymentMock.sol               # Minimal ERC-20 used as payment token
    ├── MinimalSnapshotSourceMock.sol      # I-1: implements ISnapshotSource and nothing else
    ├── IncomeVaultOverrideMock.sol        # compile guard for the `virtual` convention
    ├── NoForwarderVaultMock.sol           # M-8 guard: a deployment on IncomeVaultBase, no ERC-2771
    ├── EmbeddedDividendHostMock.sol       # M-1/M-2 compile guard: a non-CMTAT host paying dividends
    └── CMTATDividendHostMock.sol          # M-1/M-2 compile guard: a CMTATUpgradeableInternalSnapshot
                                           #   paying its own dividends, its own snapshots, own canTransfer
```

Tests deploy the vault through `Upgrades` (openzeppelin-foundry-upgrades), which requires `--ffi`,
`@openzeppelin/upgrades-core` from npm, and a **full** build (`forge clean && forge build`).

## Other important files

| Path | Purpose |
| --- | --- |
| `foundry.toml` | solc 0.8.36, optimizer 200 runs, EVM `prague`, `ffi`, `ast`, `build_info`, `storageLayout`, `fs_permissions` on `./out` (needed by OZ Upgrades) |
| `remappings.txt` | `CMTAT/`, `RuleEngine/`, `SnapshotEngine/`, `OZ/`, `OZUpgradeable/`, `@openzeppelin/*`, `openzeppelin-foundry-upgrades/`, `forge-std/` |
| `hardhat.config.js` | Only used for `solidity-docgen` (`npx hardhat docgen`), mirrors the Foundry solc settings. `settings` must stay **inside** `solidity` — at the top level Hardhat ignores it and the optimizer silently does not run. `docgen.outputDir` writes straight to `doc/solidityAPI`, so regenerating needs no manual move |
| `package.json` | npm scripts: lint (ethlint/prettier), `uml`, `surya:*`, `docgen`; dependency `@openzeppelin/upgrades-core` |
| `.soliumrc.json`, `.soliumignore` | Ethlint/Solium configuration |
| `CHANGELOG.md` | changelog.md conventions; current release `2.0.0` |
| `doc/README.md` | The reference doc: snapshot source, roles table, claim restrictions, formula, threat model & FAQ, plus the technical choices (upgradeability, pause, token agnosticism, reentrancy, gasless GSN/ERC-2771) and the schema/graphs |
| `doc/cmtat-standard/` | The CMTA framework functional specifications PDF, plus `CMTAT-Distribution-impl.md`: the full comparison of section 3.2.4 (functionalities 27-32) against this implementation, what the vault adds, why 31/32 need no new state, and ten proposed changes to the specification. `doc/README.md` keeps only a summary table and links here |
| `doc/script/gen_toc.py` | Regenerates the tables of contents in `doc/README.md` and `doc/TOOLCHAIN.md`: `python3 doc/script/gen_toc.py doc/README.md 3`. They are **generated markdown lists between `<!-- toc -->` markers**, not `[TOC]` — GitHub does not render `[TOC]`. Re-run it after adding or renaming a heading |
| `doc/TOOLCHAIN.md` | Tested dependency versions, doc-generation and lint commands |
| `doc/solidityAPI/index.md` | Generated Solidity API. Refresh with `npx hardhat docgen`; it writes in place. **`solidity-docgen` must be patched first** — it matches tag names with `\w`, which excludes `$`, so `@return $` aborts the run and `@param $` silently drops the description. `npm install` reverts the patch; re-apply with the `solidity-docgen-doc` skill's `patch_docgen.sh` (D-2) |
| `doc/surya/`, `doc/schema/` | Surya call graphs, inheritance graphs and markdown reports (one per `src/**/*.sol`), UML class diagram, PlantUML sources and the remaining drawio diagrams. Regenerate with `npm run surya:graph` + `surya:inheritance` + `surya:report` (output goes to the scratch `docOut/`, then replaces `doc/surya/`) and `npm run uml` |
| `doc/schema/plantuml/` | PlantUML sources (`.puml`) and their rendered `.png`. `incomevault-architecture` is the overview embedded in **both** READMEs — keep it low-detail; `incomevault-global`, `-claimdividend`, `-ruleengine` and `-segregated-deposit` are the detailed ones in `doc/README.md`. The `.puml` is the source of truth — edit it, then re-render with `plantuml -tpng doc/schema/plantuml/<name>.puml` and **look at the PNG**: PlantUML exits 0 on warnings and draws them into the image as a yellow banner. Embed the image in the docs, never the source text |
| `doc/audits/tools/v1.1.0/CLAUDE_ANALYSIS_SECOND.md` | Second-pass code-quality review. Ids restart at `A-1`; read it **with** `CLAUDE_ANALYSIS.md`, which it does not repeat. Includes two explicit do-not-change verdicts (I-1, G-2) recorded so they are not re-opened |
| `doc/audits/AUDIT_OVERVIEW.md` | The security overview: scope, both analyzers' results, the two real findings, and the substantive defects the reviews caught that static analysis did not |
| `doc/audits/tools/vX.Y.Z/` | Per-release tool output: `slither-report.md`, `aderyn-report.md` and a `*-feedback.md` triaging every finding. Filter Slither on `lib`, not on dependency names, and check the report cites no `lib/` before trusting a count |
| `doc/audits/tools/v1.1.0/CLAUDE_ANALYSIS.md` | Code-quality review (not a security audit). Findings carry stable ids (`A-1`, `H-2`, …) — cite them in commits and code comments, and read the Outstanding table before re-opening anything |
| `script/` | Deployment scripts, one per variant. Excluded from the style check and from coverage; their `require` messages are deliberate. Tested by `test/script/Deploy.t.sol` |
| `Makefile` | The task definitions — `make help` lists them. npm scripts and CI both delegate here, so there is one definition. Every compiling target does a **full** build because the Upgrades plugin rejects an incremental one |
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

> Test helpers live in `HelperContract`: `_deployContracts()` builds the CMTAT, snapshot engine,
> payment token and role-based vault; `_deployOwnableVault()` adds the single-owner variant. Do not
> re-inline either — five suites used to carry a copy.

```bash
make help                                  # every target, and why the build must be full
make install                               # submodules + npm dependencies
make test                                  # THE way to run the suite: full build, then forge test --ffi
make coverage                              # src/ only, tests and mocks excluded

# `forge test --ffi` on its own fails every test after an incremental build — the Upgrades plugin
# rejects partial build-info. Use `make test` unless nothing has been recompiled since the last clean.
forge test --ffi --match-contract IncomeVaultTest   # fine right after a `make build`

npm run lint:sol                           # ethlint on src/
npm run lint:sol:prettier                  # prettier-plugin-solidity
npm run surya:graph && npm run surya:inheritance && npm run surya:report   # then replace doc/surya/ with docOut/
npm run uml && npx hardhat docgen

slither . --checklist --filter-paths "openzeppelin-contracts|test|CMTAT|RuleEngine|SnapshotEngine|forge-std" > slither-report.md
```

## Conventions & invariants

- **Versioning:** `CHANGELOG.md` follows [changelog.md](https://changelog.md/) and states the project's
  own semver rule at the top — an **incompatible proxy storage change, a changed external API, or a
  reworked internal architecture is a MAJOR bump**. Add an entry for any user-visible contract change.
  A release bumps two things that must agree: the `CHANGELOG.md` heading and the `VERSION` constant in
  `src/modules/VersionModule.sol`. Add every new deployable contract to `test/VersionModule.t.sol`,
  which is exhaustive by design.
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
- **`_authorizeRuleEngineManagement` shares its name with CMTAT's on purpose.** Both this project's
  `IncomeVaultValidationModule` and CMTAT's `ValidationModuleRuleEngine` sit on the same
  `ValidationModuleRuleEngineInternal`, whose ERC-7201 slot is a hardcoded constant — so a contract
  inheriting both has exactly **one** RuleEngine. One capability, one hook; a single override answering
  both declarations is correct. **Do not prefix or rename it** (M-4): two names over one slot means two
  policies for one door, and the weaker wins.
- **Role constants live with the layer that enforces them.** They belong in
  `IncomeVaultRolesStorage`, inherited only by `IncomeVault` — never in `IncomeVaultInvariantStorage`,
  or the Ownable variant would publish a role it never checks.
- **`@inheritdoc` needs the base imported by name** in the referencing file, even when it is already
  in scope through inheritance; otherwise the build fails with "references inexistent contract".
- **Claim accounting:** always set `claimedDividend[holder][time]` before any
  external call; keep `nonReentrant` on the claim entry points.
- **Deposits vs. open claims:** do not deposit for a `time` whose claim status is
  already `true` — it dilutes holders who have not yet claimed.
- **The claim window is shared.** `TIME_ERROR_CODE`, `_timeCode` and `_revertOnInvalidTime` live in
  `IncomeVaultInternal` so both the pull path (`claimDividend`) and the push path
  (`distributeDividend`) apply them. Any new payout path must call them too: without the "too early"
  bound, `ISnapshotState` falls back to live balances and the payout is computed from the wrong figures.
- **ERC-20 safety:** use `SafeERC20` (`safeTransfer` / `safeTransferFrom`) for the
  payment token.
- **Style:** 4-space indent, NatSpec (`@notice` / `@param` / `@dev`) on public and
  internal functions, custom errors prefixed `IncomeVault_`, named imports
  (`import {X} from "..."`), `SPDX-License-Identifier: MPL-2.0` header on every Solidity file.
- **Never point at a documentation *path* from a contract comment.** Documentation moves — this repo has
  already reorganised `doc/` twice — but a comment is frozen in the verified source of a deployed
  contract and can never be corrected. Worse, someone reading that source on a block explorer has no
  `doc/` to open. Put the substance in the comment and drop the pointer; if the derivation is genuinely
  too long, state the conclusion and let the doc carry the derivation with no cross-reference either way.
  Two exceptions: a **bare filename** that survives any reorganisation and is actionable on its own
  (`CHANGELOG.md` in `VersionModule` is the one in-tree example), and an audit finding cited by id
  (`CLAUDE_ANALYSIS.md` plus `H-2`), which is an immutable record rather than living documentation.
  Mocks and tests are exempt — they are never deployed.
- **Documentation:** the README and `doc/` must state that the contracts are not
  audited; keep that disclaimer intact.

## Known quirks (verify before "fixing")

- `distributeDividend` deliberately bypasses the ValidationModule (no pause / freeze / RuleEngine
  check): it is an issuer-driven push, unlike the holder-driven claims.
- The `newDeposit` event keeps its lowercase name for backward compatibility with the v1 ABI.
- `IncomeVaultInvariantStorage` declares `event DividendSnapshotSourceSet`, and the getter is
  `dividendSnapshotSource()`. **Never name either of them `snapshotEngine`**: CMTAT declares
  `snapshotEngine()` with the same parameters and a *different return type*, which Solidity cannot
  reconcile by any override — see the snapshot bullet in Key concepts.
- `forge coverage` does not work here — the tests deploy through a proxy.
