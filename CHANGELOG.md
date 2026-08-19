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
  - Perform a code coverage and update the files in the corresponding directory [./doc/test/coverage](./doc/test/coverage)
  - Perform an audit with several audit tools (Aderyn and Slither), update the report in the corresponding directory [./doc/audits/tools](./doc/audits/tools)
  - Update surya doc by running the 3 scripts in [./doc/script](./doc/script)
  - Update changelog

## 2.0.0

### Breaking changes

- The vault is no longer tied to the CMTAT. The holder balances and the total supply are read
  through the [`ISnapshotState`](https://github.com/CMTA/SnapshotEngine) interface, so **any**
  contract implementing it can be used as the snapshot source (the external `SnapshotEngine`, or a
  token embedding the snapshot logic). The state variable `CMTAT_TOKEN` (`ICMTATSnapshot`) is
  replaced by `snapshotEngine` (`ISnapshotState`).
- `initialize` no longer takes an `IAuthorizationEngine`, removed by CMTAT v3. New signature:
  `initialize(address admin, IERC20 ERC20TokenPayment_, ISnapshotState snapshotEngine_, IRuleEngine ruleEngine_, uint256 timeLimitToWithdraw_)`.
- The vault no longer inherits the CMTAT `ValidationModule`. Its own
  `IncomeVaultValidationModule` composes the CMTAT `AccessControlModule`, `PauseModule` and
  `EnforcementModule` and calls the RuleEngine through the view entry point
  `IRuleEngine.canTransfer`. A rejected payout now reverts with
  `IncomeVault_InvalidTransfer(from, to, value)` instead of `CMTAT_InvalidTransfer`.
- `withdraw` and `withdrawAll` use `SafeERC20.safeTransfer` directly; the self-approval step and
  the error `IncomeVault_FailApproval` are removed.
- The state moved from sequential storage slots guarded by `uint256[50] private __gap` to a single
  **ERC-7201 namespaced storage** struct, as OpenZeppelin Upgradeable and CMTAT v3 do. Every `__gap`
  is removed and `IncomeVault` now declares **no** sequential storage slot at all. The external ABI
  is unchanged — `snapshotEngine()`, `ERC20TokenPayment()`, `claimedDividend()`, `segregatedDividend()`,
  `segregatedClaim()` and `timeLimitToWithdraw()` are kept as explicit getters — but the storage
  layout is **not** compatible with a 1.x/2.0-rc deployment: this is a redeploy, not an upgrade.

### Added

- Events for every state write that had none: `ClaimStatusSet`, `ERC20TokenPaymentSet`,
  `TimeLimitToWithdrawSet`, `Withdraw` and `WithdrawAll`. Each is emitted from the internal `_setX`
  helper that performs the write, so they also fire during `initialize` — a vault configured once at
  deployment now has a complete on-chain trail. See `CLAUDE_ANALYSIS.md` C-1 to C-4.
- `doc/audits/CLAUDE_ANALYSIS.md`, a code-quality review (not a security audit).
- `VersionModule`, exposing the release version through `IERC3643Version.version()`, as the CMTAT,
  RuleEngine and SnapshotEngine do. `VERSION` currently reads **1.1.0**; note this conflicts with the
  MAJOR rule stated above, which this release triggers (incompatible proxy storage change, changed
  `initialize` signature, reworked internal architecture). Align `VERSION` with the release heading
  before tagging.
- `IncomeVaultOwnable2Step`, a second deployment contract using a single ERC-173 owner
  (`Ownable2StepUpgradeable`) instead of roles. The variant is chosen at deployment and cannot be
  swapped afterwards. It **cannot express separated duties** — the owner both funds and drains the
  vault — so it suits simple deployments only.
- `Ownable2StepERC165Module`, advertising ERC-173 and the Ownable2Step selectors.

### Changed

- The snapshot source is now typed `ISnapshotSource` (new, `src/interfaces/ISnapshotSource.sol`) rather
  than `ISnapshotState`: the three functions the vault calls instead of the eight `ISnapshotState`
  declares. Signatures are copied verbatim, so every `ISnapshotState` implementation still satisfies it;
  callers pass one with an explicit cast, `ISnapshotSource(address(engine))`. **Storage layout and ABI are
  unchanged** — interface types encode as `address` — so this is a source-level change only.
  Finding I-1 of `CLAUDE_ANALYSIS.md`.
- `validateTimeBatch` reads `timeLimitToWithdraw` once instead of once per element, and both batch
  entrypoints take `calldata` instead of `memory`. Measured **-1,949 gas (-5.5%)** on an 8-element
  batch, -241 gas per additional element. See `CLAUDE_ANALYSIS.md` A-1.
- The five `public` functions of `IncomeVaultOpen` are now `virtual`, matching every other public
  function in the project. See `CLAUDE_ANALYSIS.md` E-1.
- Access control moved to the authorization-hook pattern. `IncomeVaultBase` (new) and the logic
  modules declare one `internal view virtual` hook per capability (`_authorizeDeposit`,
  `_authorizeWithdraw`, `_authorizeDistribute`, `_authorizeOperator`,
  `_authorizeRuleEngineManagement`, plus the CMTAT `_authorizePause`, `_authorizeDeactivate`,
  `_authorizeFreeze`); the deployment contract supplies the policy. `IncomeVault` keeps exactly the
  roles it had, so its behaviour is unchanged.
- The four `INCOME_VAULT_*_ROLE` constants moved from `IncomeVaultInvariantStorage` to the new
  `IncomeVaultRolesStorage`, inherited only by `IncomeVault`, so the single-owner variant does not
  publish roles it never checks.

### Fixed

- `distributeDividend` now applies the same transfer restrictions as a holder-driven claim — pause,
  address freeze and the RuleEngine. It previously bypassed the ValidationModule entirely, so an
  address the RuleEngine refuses, or a frozen holder, could still be paid by the issuer, and pausing
  the vault did not stop a distribution. One blocked holder reverts the whole distribution rather than
  being skipped. Finding H-2 of `CLAUDE_ANALYSIS.md`.
- `distributeDividend` now applies the same claim window as `claimDividend` (claims open, `time`
  reached, withdraw limit not expired). It previously checked only `segregatedClaim[time]`, so a
  distribution before `time` computed every payout from the **live** balances — `ISnapshotState` falls
  back to them when no snapshot has been recorded — and marked the period claimed at the wrong amount.
  Finding H-1 of `CLAUDE_ANALYSIS.md`.


- `INCOME_VAULT_DISTRIBUTE_ROLE` was defined as `keccak256("INCOME_VAULT_DEPOSIT_ROLE")` and
  therefore shared the deposit role. It is now `keccak256("INCOME_VAULT_DISTRIBUTE_ROLE")`.
- `initialize` checked the payment token against the zero address twice and never checked the
  snapshot source. The snapshot source is now rejected when zero
  (`IncomeVault_SnapshotEngineWithAddressZeroNotAllowed`).

### Toolchain

- Solidity 0.8.36, EVM target `prague`.
- CMTAT v2.4.0 → v3.3.0-rc3, RuleEngine v2.0.0 → v3.0.0-rc5, OpenZeppelin Contracts (and
  Contracts Upgradeable) v5.0.x → v5.7.0, OpenZeppelin Foundry Upgrades v0.1.0 → v0.4.2.
- New submodules: `lib/SnapshotEngine` (v0.5.0) and `lib/forge-std` (v1.16.1).
- `ReentrancyGuardUpgradeable` was removed from OpenZeppelin Contracts Upgradeable v5.7.0; the
  vault now uses `ReentrancyGuardTransient` (EIP-1153).

## 1.0.0
- 🎉 first release!
