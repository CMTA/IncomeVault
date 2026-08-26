# CHANGELOG

Please follow [https://changelog.md/](https://changelog.md/) conventions.

## Semantic Version 2.0.0

Given a version number MAJOR.MINOR.PATCH, increment the:

1. MAJOR version when the new version makes:
   -  Incompatible proxy **storage** change internally or through the upgrade of an external library (OpenZeppelin)
   -  A significant change in external APIs (public/external functions) or in the internal architecture
2. MINOR version when the new version adds functionality in a backward compatible manner
3. PATCH version when the new version makes backward compatible bug fixes

See [https://semver.org](https://semver.org)

## Type of changes

- `Summary`: main new features/change with a description (keep it short) (not a changelog tag)
- `Added` for new features.
- `Changed` for changes in existing functionality.
- `Deprecated` for soon-to-be removed features.
- `Removed` for now removed features.
- `Fixed` for any bug fixes.
- `Security` in case of vulnerabilities.

Reference: [keepachangelog.com/en/1.1.0/](https://keepachangelog.com/en/1.1.0/)

Custom changelog tag: `Dependencies`, `Documentation`, `Testing`

## Checklist

> Before a new release, perform the following tasks

- Code: Update the version name, variable VERSION
- Run formatter and linter

```bash
forge fmt
forge lint
```

- Documentation
  - Perform a code coverage: `make coverage-report`. The output lands in `doc/coverage/` and is **git-ignored** — regenerate it, do not commit it
  - Perform an audit with several audit tools (Aderyn and Slither), update the report in the corresponding directory [./doc/audits/tools](./doc/audits/tools)
  - Update surya doc by running the 3 scripts in [./doc/script](./doc/script)
  - Update changelog

## 2.0.0-rc0

### Breaking changes

- The vault is no longer tied to the CMTAT. The holder balances and the total supply are read through the [`ISnapshotState`](https://github.com/CMTA/SnapshotEngine) interface, so **any** contract implementing it can be used as the snapshot source (the external `SnapshotEngine`, or a token embedding the snapshot logic). The state variable `CMTAT_TOKEN` (`ICMTATSnapshot`) is replaced by the snapshot source, reachable through `dividendSnapshotSource()`.
- `initialize` no longer takes an `IAuthorizationEngine`, removed by CMTAT v3. New signature: `initialize(address admin, IERC20 ERC20TokenPayment_, ISnapshotState snapshotEngine_, IRuleEngine ruleEngine_, uint256 timeLimitToWithdraw_)`.
- The vault no longer inherits the CMTAT `ValidationModule`. Its own `IncomeVaultValidationModule` composes the CMTAT `AccessControlModule`, `PauseModule` and `EnforcementModule` and calls the RuleEngine through the view entry point `IRuleEngine.canTransfer`. A rejected payout now reverts with `IncomeVault_InvalidTransfer(from, to, value)` instead of `CMTAT_InvalidTransfer`.
- `withdraw` and `withdrawAll` use `SafeERC20.safeTransfer` directly; the self-approval step and the error `IncomeVault_FailApproval` are removed.
- The state moved from sequential storage slots guarded by `uint256[50] private __gap` to a single **ERC-7201 namespaced storage** struct, as OpenZeppelin Upgradeable and CMTAT v3 do. Every `__gap` is removed and `IncomeVault` now declares **no** sequential storage slot at all. The external ABI is unchanged — `dividendSnapshotSource()`, `ERC20TokenPayment()`, `claimedDividend()`, `segregatedDividend()`, `segregatedClaim()` and `timeLimitToWithdraw()` are kept as explicit getters — but the storage layout is **not** compatible with a 1.x/2.0-rc deployment: this is a redeploy, not an upgrade. The snapshot source later moved out of `IncomeVault.storage.IncomeVaultInternal` into its own namespace (finding M-2), which shifted every remaining field of the internal struct down by one slot.

### Added

- A `Makefile` with the common tasks, and `make test` as the way to run the suite. The OpenZeppelin Upgrades plugin rejects an incremental build, so `forge test --ffi` after editing a contract fails every test with an error naming neither the cause nor the fix; `make test` does the full build first. Verified by reproducing the failure — plain `forge test` after an incremental build: 0 passed, 19 suites failed; `make test` from the identical state: 202 passed. `npm run test|build|coverage|lint` delegate to the same targets, and CI now runs `make test`. Finding C-3 of `CLAUDE_IMPROVEMENT.md`.
- [ERC-7741](https://eips.ethereum.org/EIPS/eip-7741) signed operator authorisation: `authorizeOperator`, `invalidateNonce`, `authorizations` and `DOMAIN_SEPARATOR`, in the new `ERC7741Module` with its own ERC-7201 namespace and the interface declared in `src/interfaces/IERC7741.sol`. A holder signs an EIP-712 message and anyone can submit it, so a custodian can be appointed without the holder ever transacting. Signatures are checked with `SignatureChecker`, so ERC-1271 contract wallets work. `type(IERC7741).interfaceId` equals the standard's `0xa9e50872` (asserted), and both deployment variants advertise it through `supportsInterface` as the standard requires.
- Deployment scripts: `script/DeployIncomeVault.s.sol` and `script/DeployIncomeVaultOwnable2Step.s.sol`, using the same `Upgrades` plugin as the tests so the deployment path is the tested one. Configuration comes from the environment, and `deploy(config)` is separated from `run()` so `test/script/Deploy.t.sol` exercises the same code without one. The scripts reject what the contract cannot check for itself — a payment token, snapshot source or rule engine that is not a contract. Finding C-4 of `CLAUDE_IMPROVEMENT.md`.
- `IERC7540Operator` (`src/interfaces/IERC7540Operator.sol`), declaring the three members whose signatures are ERC-7540's verbatim. `type(IERC7540Operator).interfaceId` equals the standard's `0xe3bc4e65`, asserted in the tests, so a signature drift breaks the build. The vault deliberately does **not** advertise that id through ERC-165 — it shares the operator methods, it is not an asynchronous vault.
- Claim delegation in the shape of ERC-7540: `setOperator(operator, approved)`, `isOperator(controller, operator)`, `claimDividendFor(holder, time)` and `claimDividendBatchFor(holder, times)`, with an `OperatorSet` event matching the standard. The dividends always go to the holder — an operator pays the gas and picks the moment, and can never redirect the payment. Finding E-1 of `CLAUDE_IMPROVEMENT.md`.
- `paidDividend(time)` and `unclaimedDividend(time)`, reporting how much a dividend time has paid out and how much it still holds. The residue an issuer sweeps is now readable on-chain instead of being reconstructed from `DividendClaimed` events. Costs **+22,274 gas on the first claim of each period** (66,687 -> 88,961, a cold `SSTORE` for the new per-time counter); later claims for the same period pay the warm price. Finding E-3.
- `depositBatch(times[], amounts[])`, crediting several dividend times in one transaction and pulling the payment token once for the total. Measured for three periods: **136,263 gas in-call against 116,812 for three separate `deposit` calls** — the batch is the more expensive of the two per call, and wins only once the 21,000 intrinsic cost of each saved transaction is counted (157,546 against 179,812 in total). It is a transaction-count optimisation, not a cheaper deposit. Finding E-2 of `CLAUDE_IMPROVEMENT.md`.
- `distributeDividendBestEffort`, a variant of `distributeDividend` that **skips** a holder whose payout is refused instead of reverting the whole run, returning `(paidCount, skipped[])` and emitting `DividendDistributionSkipped(time, holder, reason)` with the raw revert data. Each payout goes through an external self-call wrapped in `try`/`catch`, so a skipped holder is left completely untouched — not marked as claimed — and can still claim later. `distributeDividend` keeps its all-or-nothing semantics. Finding A-4 of `CLAUDE_IMPROVEMENT.md`.
- `setSnapshotEngine`, allowing the snapshot source to be migrated without a proxy upgrade — but only while **no claim period is open**, since amounts are computed from the source at claim time rather than fixed at deposit. Gated by a new `_authorizeSnapshotEngineManagement` hook (`DEFAULT_ADMIN_ROLE` / owner) and by the new `openClaimCount()` view; reverts `IncomeVault_ClaimPeriodOpen`. Note the gate narrows the hazard rather than removing it — see the security note in `doc/README.md`. Finding A-3 (option b) of `CLAUDE_IMPROVEMENT.md`.
- `openClaimCount()`, the number of dividend times whose claims are currently open.
- Events for every state write that had none: `ClaimStatusSet`, `ERC20TokenPaymentSet`, `TimeLimitToWithdrawSet`, `Withdraw` and `WithdrawAll`. Each is emitted from the internal `_setX` helper that performs the write, so they also fire during `initialize` — a vault configured once at deployment now has a complete on-chain trail. See `CLAUDE_ANALYSIS.md` C-1 to C-4.
- `doc/audits/CLAUDE_ANALYSIS.md`, a code-quality review (not a security audit).
- `VersionModule`, exposing the release version through `IERC3643Version.version()`, as the CMTAT, RuleEngine and SnapshotEngine do. `VERSION` reads **2.0.0**: the release triggers the MAJOR rule stated above on three counts — an incompatible proxy storage change, a changed `initialize` signature, and a reworked internal architecture. The `-rc0` suffix on this heading marks the release as a candidate and is deliberately **not** carried into the contract constant, which reports the version the code will ship as.
- `IncomeVaultOwnable2Step`, a second deployment contract using a single ERC-173 owner (`Ownable2StepUpgradeable`) instead of roles. The variant is chosen at deployment and cannot be swapped afterwards. It **cannot express separated duties** — the owner both funds and drains the vault — so it suits simple deployments only.
- `Ownable2StepERC165Module`, advertising ERC-173 and the Ownable2Step selectors.

### Changed

- The payout paths no longer inherit a transfer-restriction policy. `IncomeVaultValidationCore` declares `_validateTransfer` and inherits nothing; `IncomeVaultValidationModule` is now one *answer* to it, built on the CMTAT modules, and is inherited by the two deployment contracts rather than by `IncomeVaultOpen`/`IncomeVaultRestricted`. `IncomeVaultBase` consequently knows nothing about pause, freeze or the RuleEngine, and `__IncomeVaultBase_init_unchained` lost its `ruleEngine_` argument. `ReentrancyGuardTransient` was also reordered to match CMTAT's convention. Together these mean a host that already owns those modules — a CMTAT with a snapshot engine — can embed the dividend logic instead of hitting an unresolvable `Error (5005)`. No behaviour change; all 202 tests pass unchanged.
- The snapshot source is no longer a stored address behind a `snapshotEngine()` getter. `IncomeVaultSnapshotCore` declares the three questions the payout paths actually ask — `_snapshotInfo` and the two `_snapshotInfoBatch` overloads — and inherits nothing. `IncomeVaultSnapshotModule` is one *answer* to them: an `ISnapshotSource` held in **its own** ERC-7201 namespace (`IncomeVault.storage.SnapshotSource`). This removes a name collision that no override list could repair: CMTAT already declares `snapshotEngine()` with the same parameters and a **different return type**, so a CMTAT could not embed the dividend logic at all. Renames, all pre-release: `snapshotEngine()` to `dividendSnapshotSource()`, `setSnapshotEngine` to `setDividendSnapshotSource`, `_authorizeSnapshotEngineManagement` to `_authorizeSnapshotSourceManagement`, the event `SnapshotEngineSet` to `DividendSnapshotSourceSet(ISnapshotSource indexed)` and the error `IncomeVault_SnapshotEngineWithAddressZeroNotAllowed` to `IncomeVault_SnapshotSourceWithAddressZeroNotAllowed`. `initialize` is unchanged.
- `IIncomeVault` (`src/interfaces/IIncomeVault.sol`) states the distribution API — claiming, funding, pushing payouts, claim administration and the state getters — so an integrator imports one interface instead of a concrete contract and its whole dependency graph. It is inherited by `IncomeVaultInternal`, the common base of both payout paths, so the compiler keeps it in step with the implementation, and both deployment variants advertise its id through `supportsInterface`. The enum `TIME_ERROR_CODE` moved from `IncomeVaultInternal` to `IIncomeVault`: it is the return type of `validateTimeCode` and therefore part of the stated API. Its ABI encoding (`uint8`) is unchanged; only the qualified Solidity name moves. ERC-7540's operator id is still deliberately not advertised.
- Claim delegation moved out of the distribution storage into `IncomeVaultOperatorModule` (`src/modules/IncomeVaultOperatorModule.sol`), with its own ERC-7201 namespace `IncomeVault.storage.Operator` (slot `0x70af7571...5500`). `setOperator`, `isOperator`, `_setOperator` and `_requireHolderOrOperator` were gathered there from `IncomeVaultOpen` and `IncomeVaultInternal`, so one capability now lives in one module with one namespace, as `ERC7741Module` already did. The external ABI is unchanged. `_isOperator` was the **last** field of `IncomeVaultInternalStorage`, so removing it shifts no other field — but the mapping's slot does move, which is why this had to happen before a deployment.
- The `src/` layout now says what each file **is**, following CMTAT's own convention. `src/deployment/` holds the two deployable contracts; `src/libraries/` is gone — it contained four abstract contracts and no `library` — with `IncomeVaultInternal` and `Ownable2StepERC165Module` moving to `src/modules/` and the two declaration-only contracts to `src/storage/`. `IncomeVaultBase.sol` is the only file left at the root. `src/public/` is unchanged on purpose: splitting the external surface by who may call it is what makes the gated/ungated boundary legible. Import paths only; no contract renamed, no ABI change.
- Gasless support is now chosen at deployment. `IncomeVaultBase` no longer inherits `ERC2771Module`; the new `IncomeVaultBaseERC2771` adds it along with the `_msgSender`/`_msgData`/`_contextSuffixLength` overrides, and both shipped deployments inherit that instead — so their behaviour, ABI and forwarder handling are unchanged. A deployment that does not want a trusted forwarder now inherits `IncomeVaultBase` directly and carries none of the machinery, where previously declining meant passing the zero address and paying for it anyway.
- `doc/solidityAPI/index.md` is regenerated from the current contracts (8,737 -> 76,812 bytes); it had described the pre-CMTAT-v3 architecture. `npx hardhat docgen` now writes straight to `doc/solidityAPI` via `docgen.outputDir`, instead of into `docs/` for a manual move. Two blockers had to go first: `solidity-docgen` aborts on a `@return` naming the `$` ERC-7201 storage accessor, so those four tags are removed (OpenZeppelin leaves the accessors undocumented); and `hardhat.config.js` declared `settings` at the top level where Hardhat ignores it, so docgen compiled without the optimizer and reported a spurious contract-size warning. Documentation and tooling only, no contract behaviour change. Finding D-2 of `CLAUDE_IMPROVEMENT.md`.
- Two unused imports removed: `IERC165` in `Ownable2StepERC165Module` and `ISnapshotSource` in `IncomeVaultRestricted`, the latter left over from finding M-2. Found by Aderyn; re-running it took L-9 from 6 instances to 4, the remaining four being `@inheritdoc` false positives. No bytecode change — an unused import contributes no code.
- `detectTransferRestriction` now reports the whole payout decision instead of only the RuleEngine's part. A paused vault, a deactivated vault or a frozen party used to be reported as unrestricted while `canTransfer` returned false and the claim reverted, so the two views on one contract disagreed and the one carrying the ERC-1404 name was wrong. It returns CMTAT's `REJECTED_CODE_BASE` codes. `messageForTransferRestriction` answers for each of those codes with CMTAT's own strings, and returns `UnknownCode` rather than `No restriction` for a code it cannot explain. Finding H-1 of `CLAUDE_ANALYSIS_SECOND.md`.
- `_transferDividend`, `_computeDividend` and `_computeDividendBatch` are now `virtual`, matching the five internal functions they sit beside in `IncomeVaultInternal`. `_transferDividend` is the payout routine and the sanctioned way to extend it is an override, since the guide forbids adding another public entry point to it — it could not be overridden. Finding E-1 of `CLAUDE_ANALYSIS_SECOND.md`.
- The saturating remainder rule is extracted as `_unclaimed(segregated, paid)`, used by both `unclaimedDividend` and `_transferDividend`, and each reads its period slots once. Measured **167 gas** off every claim (118,924 to 118,757) with one source of truth for a rule the two callers must agree on. Finding B-1 of `CLAUDE_ANALYSIS_SECOND.md`.
- The deposit write, its zero-amount check and its `newDeposit` event move into a single internal `_deposit`, called once by `deposit` and once per element by `depositBatch`. Both paths carried a copy of all three, so the rule that a deposit is validated, recorded and announced together was held by convention rather than structurally. The batch's single `safeTransferFrom` for the whole total stays outside the helper, which is the reason that function exists. No behaviour change; the batch path measures 283 gas cheaper. Finding C-1 of `CLAUDE_ANALYSIS_SECOND.md`.
- `_revertOnInvalidTime` ends in an unconditional `else` instead of a fourth `else if`. `TIME_ERROR_CODE` is exhaustive, so the extra comparison was dead — and the old shape **failed open**: a value added to the enum without a matching arm fell through and silently allowed the claim. It now reverts.
- The snapshot source is now typed `ISnapshotSource` (new, `src/interfaces/ISnapshotSource.sol`) rather than `ISnapshotState`: the three functions the vault calls instead of the eight `ISnapshotState` declares. Signatures are copied verbatim, so every `ISnapshotState` implementation still satisfies it; callers pass one with an explicit cast, `ISnapshotSource(address(engine))`. **Storage layout and ABI are unchanged** — interface types encode as `address` — so this is a source-level change only. Finding I-1 of `CLAUDE_ANALYSIS.md`.
- `validateTimeBatch` reads `timeLimitToWithdraw` once instead of once per element, and both batch entrypoints take `calldata` instead of `memory`. Measured **-1,949 gas (-5.5%)** on an 8-element batch, -241 gas per additional element. See `CLAUDE_ANALYSIS.md` A-1.
- The five `public` functions of `IncomeVaultOpen` are now `virtual`, matching every other public function in the project. See `CLAUDE_ANALYSIS.md` E-1.
- Access control moved to the authorization-hook pattern. `IncomeVaultBase` (new) and the logic modules declare one `internal view virtual` hook per capability (`_authorizeDeposit`, `_authorizeWithdraw`, `_authorizeDistribute`, `_authorizeOperator`, `_authorizeRuleEngineManagement`, plus the CMTAT `_authorizePause`, `_authorizeDeactivate`, `_authorizeFreeze`); the deployment contract supplies the policy. `IncomeVault` keeps exactly the roles it had, so its behaviour is unchanged.
- The four `INCOME_VAULT_*_ROLE` constants moved from `IncomeVaultInvariantStorage` to the new `IncomeVaultRolesStorage`, inherited only by `IncomeVault`, so the single-owner variant does not publish roles it never checks.

### Testing

- Invariant suite (`test/invariant/`): a bounded handler drives deposits, claims, batch claims, both distribution variants, withdrawals, freezes, pauses and time warps against six invariants — no over-payment, no holder paid twice for one period across **any** combination of the three payout paths, monotonic claim flags, no unexplained batch payout, no value leaking to a non-holder, and per-time accounting bounded by deposits. 3,072 calls per invariant, budget pinned in `foundry.toml`. Finding B-3 of `CLAUDE_IMPROVEMENT.md`.
- The single-owner deployment used in five test files moved into `HelperContract._deployOwnableVault()`. Finding B-4.
- `deactivateContract` is now covered in both deployment variants: the pause precondition, the irreversibility (a deactivated vault can never be unpaused), double-deactivation, that every payout path is refused afterwards, and that `PAUSER_ROLE` alone is not sufficient. It was previously untested despite being the only irreversible action in the system. Finding B-1 of `CLAUDE_IMPROVEMENT.md`.
- Branch coverage of `src/` raised from **68.75% to 97.56%** (lines 92.09% → 95.65%, statements 94.54% → 97.54%): the initializer guards, a holder with no tokens at the snapshot, the ERC-1404 views with no RuleEngine configured, and every `TIME_ERROR_CODE` arm. Finding B-2.

### Fixed

- A payout is now bounded by what its own dividend time still holds. Sweeping a period mid-window lowers `segregatedDividend`, so a holder claiming afterwards was priced against the reduced figure while the period no longer held that much — and the shortfall was silently funded from **another period's deposit**. Such a claim now reverts `IncomeVault_NotEnoughAmount`. Found by the invariant suite; a deterministic reproduction is `testAClaimCannotBeFundedByAnotherPeriod`.
- `unclaimedDividend` saturates at zero instead of underflowing on an over-drawn period. A view must never revert.
- `withdraw` is now bounded by what a dividend time **still holds** (`unclaimedDividend`) rather than by what was deposited into it. `segregatedDividend` is the pro-rata denominator and is never reduced by a payout, so the old bound let a fully-claimed period be swept again — draining the funds deposited for a *different* period and leaving its holders unpayable, with no error raised. Finding E-3 of `CLAUDE_IMPROVEMENT.md`.
- `timeLimitToWithdraw` can no longer be set to zero, at initialization or through `setTimeLimitToWithdraw`. Zero collapsed the claim window `[time, time + limit]` to the single instant `block.timestamp == time` — one second later every claim already reverted `TooLateToWithdraw` — so a period became effectively unclaimable with no signal, the transaction having succeeded and the event fired. Reverts with `IncomeVault_TimeLimitToWithdrawZeroNotAllowed`. Any positive value is still accepted. Finding A-1 of `CLAUDE_IMPROVEMENT.md`.
- `distributeDividend` now applies the same transfer restrictions as a holder-driven claim — pause, address freeze and the RuleEngine. It previously bypassed the ValidationModule entirely, so an address the RuleEngine refuses, or a frozen holder, could still be paid by the issuer, and pausing the vault did not stop a distribution. One blocked holder reverts the whole distribution rather than being skipped. Finding H-2 of `CLAUDE_ANALYSIS.md`.
- `distributeDividend` now applies the same claim window as `claimDividend` (claims open, `time` reached, withdraw limit not expired). It previously checked only `segregatedClaim[time]`, so a distribution before `time` computed every payout from the **live** balances — `ISnapshotState` falls back to them when no snapshot has been recorded — and marked the period claimed at the wrong amount. Finding H-1 of `CLAUDE_ANALYSIS.md`.


- `INCOME_VAULT_DISTRIBUTE_ROLE` was defined as `keccak256("INCOME_VAULT_DEPOSIT_ROLE")` and therefore shared the deposit role. It is now `keccak256("INCOME_VAULT_DISTRIBUTE_ROLE")`.
- `initialize` checked the payment token against the zero address twice and never checked the snapshot source. The snapshot source is now rejected when zero (`IncomeVault_SnapshotEngineWithAddressZeroNotAllowed`).

### Toolchain

- Solidity 0.8.36, EVM target `prague`.
- CMTAT v2.4.0 → v3.3.0-rc3, RuleEngine v2.0.0 → v3.0.0-rc5, OpenZeppelin Contracts (and Contracts Upgradeable) v5.0.x → v5.7.0, OpenZeppelin Foundry Upgrades v0.1.0 → v0.4.2.
- New submodules: `lib/SnapshotEngine` (v0.5.0) and `lib/forge-std` (v1.16.1).
- `ReentrancyGuardUpgradeable` was removed from OpenZeppelin Contracts Upgradeable v5.7.0; the vault now uses `ReentrancyGuardTransient` (EIP-1153).

## 1.0.0
- 🎉 first release!
