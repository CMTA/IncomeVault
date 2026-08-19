# IncomeVault — Improvement Backlog

Working document, produced with Claude Code on 2026-08-19 against branch `update`.
**Temporary — delete once the items have been triaged.**

Scope: the whole project — contracts, tests, tooling, documentation, release process.
This is **not** a security audit and **not** a repeat of `doc/audits/CLAUDE_ANALYSIS.md`; where a
finding already lives there it is referenced rather than restated. Nothing below is a vulnerability:
every item is either role-gated, off-chain, or a robustness/process concern.

Each item says what was **verified** versus what is a **suggestion**, because the two deserve different
levels of trust.

## Suggested order

1. ~~**A-1**~~ ✅ done. **A-2** — cheap correctness fix, no design debate.
2. **D1, D3** — the two documentation artefacts that are actively misleading.
3. **B1, B2** — close the test gaps that cover irreversible actions.
4. **C1, C4** — make CI catch what is currently caught only by hand.
5. ~~**A-3**~~ ✅ done (option b). **A-4, E-1** — genuine design decisions; discuss before building.
6. Everything else as capacity allows.

---

## A. Contract robustness

### A-1. `timeLimitToWithdraw = 0` leaves a one-second claim window — ✅ **implemented**

`_timeCode` rejects a claim when `block.timestamp > timeLimit + time`. With `timeLimit == 0` the only
instant that satisfies both that and `block.timestamp >= time` is **exactly** `block.timestamp == time`.

Measured with a throwaway test: at `time` the code is `OK (0)`; one second later it is
`TOO_LATE_TO_WITHDRAW (2)`. Nothing validates the value — not `initialize`, not
`setTimeLimitToWithdraw`.

Consequence: an operator who sets `0` (or a very small value) silently makes a dividend period
unclaimable. It is `INCOME_VAULT_OPERATOR_ROLE`-gated so it is not an attack, but it is a footgun with
no signal — the transaction succeeds and the event fires.

**Implemented.** `_setTimeLimitToWithdraw` now reverts `IncomeVault_TimeLimitToWithdrawZeroNotAllowed`
on zero. The guard sits in the internal setter rather than at the call sites, so it covers **both**
write paths — `initialize` and `setTimeLimitToWithdraw` — and a vault cannot be deployed into the
bricked state either.

Only zero is rejected, not "small" values: zero is broken by definition, while any positive value can
be a deliberate settlement policy, and picking a minimum would impose one. Covered by
`testCannotSetAZeroTimeLimitToWithdraw`, `testCannotInitializeWithAZeroTimeLimitToWithdraw` and
`testAOneSecondTimeLimitIsStillAccepted`; the first two were confirmed to fail with the guard removed.

### A-2. The single-owner variant reverts with an "Admin" error — **verified**

`IncomeVaultOwnable2Step.initialize` rejects a zero owner with
`IncomeVault_AdminWithAddressZeroNotAllowed()` (`IncomeVaultOwnable2Step.sol:65-67`). That deployment
has no admin; it has an **owner**. An integrator decoding the revert is told about a role the contract
does not use.

**Suggested fix:** add `IncomeVault_OwnerWithAddressZeroNotAllowed()`, or rename the existing error to
something policy-neutral. Errors are part of the ABI, so bundle this with the next breaking release.

### A-3. The snapshot source cannot be replaced after initialization — ✅ **implemented (option b)**

`_setSnapshotEngine` is internal and only reached from `initialize`. If the snapshot provider has to be
migrated — a redeployed `SnapshotEngine`, a token moving to embedded snapshots — the vault is stuck and
the only route is a proxy upgrade.

This is a genuine tension rather than an oversight: **changing the source retroactively changes every
historical entitlement**, because past `time` values would resolve against a different contract. A
setter is not obviously safe.

**Implemented as option (b).** `setSnapshotEngine` accepts a change only while `openClaimCount() == 0`,
reverting `IncomeVault_ClaimPeriodOpen(count)` otherwise. The counter is maintained in
`_setStatusClaim`, the single writer of the claim status, and that function became idempotent so a
repeated write cannot drift it.

Gated by a new `_authorizeSnapshotEngineManagement` hook, overridden in **both** deployment variants
per the project's access-control convention.

**Option (c) remains the fully correct answer and is not implemented.** The gate stops a swap under an
open period, but entitlements are still resolved against whichever source is configured when the claim
happens, so re-opening a past `time` after a swap resolves it against the new source. Pinning the
source per `time` at deposit is the only way to close that, and it is a materially larger change.

### A-4. No way to pre-check a distribution — **suggestion**

Since the H-2 fix, one blocked holder reverts the whole `distributeDividend` call. That is the right
semantics, but an operator distributing to a large list can only discover a bad address by spending a
transaction and reading the revert.

**Suggested fix:** a view — `canDistribute(address[] calldata addresses, uint256 time)` returning the
first offending address, or a bitmap — so the list can be cleaned off-chain first. Read-only, no
change to the payout path.

## B. Tests

### B-1. `deactivateContract()` is never exercised — **verified**

`grep -rn 'deactivateContract' test/` returns nothing, and the coverage report confirms
`_authorizeDeactivate` is never entered in either variant. This is the one **irreversible** action in
the system: it permanently disables the contract, and with a proxy the only way back is a new
implementation.

**Suggested fix:** for each variant, test that the correct role can deactivate from the paused state,
that the wrong role cannot, that it requires the pause, and that a deactivated vault refuses payouts.

### B-2. Branch coverage is 68.75% — **verified**

Filtered to `src/` (`--exclude-tests --no-match-coverage '(test|mocks?|script)/'`):

| Metric | |
| --- | --- |
| Lines | 92.09% (233/253) |
| Statements | 94.54% (225/238) |
| **Branches** | **68.75% (22/32)** |
| Functions | 87.01% (67/77) |

Branches lag by more than 20 points. The uncovered ones are specific and mostly cheap:

- zero-address `admin` / `owner_` in both `initialize` implementations;
- the zero-address payment-token guard in `_setERC20TokenPayment`;
- the "no RuleEngine configured" passthrough in `detectTransferRestriction` and
  `messageForTransferRestriction`;
- two arms of `_revertOnInvalidTime`.

Note the ten "never entered" functions are **not** all gaps: most are the abstract `_authorize*`
declarations, which have no body and can never be entered — the overrides are covered. `_msgData` is
genuinely unexercised, and `_authorizeDeactivate` is B-1.

The `solidity-coverage` skill automates this run and its 100% analysis.

### B-3. No fuzz or invariant tests — **suggestion**

The suite is entirely example-based. The accounting has properties worth stating as invariants:

- the sum of everything paid out for a `time` never exceeds `segregatedDividend[time]`;
- `claimedDividend[holder][time]` is monotonic — once true it never returns to false;
- a holder can never be paid twice for the same `time` by any combination of `claimDividend`,
  `claimDividendBatch` and `distributeDividend`;
- `withdraw` can never reduce `segregatedDividend[time]` below zero (currently guarded by a check that
  a fuzz run would confirm).

The third is the one worth writing first: it crosses all three payout paths and is exactly the kind of
thing example tests miss.

### B-4. The Ownable2Step deployment is duplicated across three test files — **verified**

`AccessControlHooks.t.sol`, `VersionModule.t.sol` and `SnapshotSource.t.sol` each contain their own
`Upgrades.deployTransparentProxy("IncomeVaultOwnable2Step.sol", …)` block with the same arguments.
`HelperContract` already owns `_deployContracts()`; a `_deployOwnableVault()` beside it would remove
three copies and one future inconsistency.

## C. Tooling and CI

### C-1. CI runs build and tests only — **verified**

`.github/workflows/ci.yml` runs `npm install`, `forge clean && forge build --sizes`, `forge test --ffi`.
Everything else in this repository's quality story is manual and therefore optional in practice:
the style checker, coverage, Slither, the changelog checklist.

**Suggested additions**, in order of value per line of YAML: the Solidity style check; `forge coverage`
with a floor so the number cannot silently regress; `forge lint`. Slither is worth a separate scheduled
job rather than blocking every push.

### C-2. `forge fmt` conflicts with the project's own NatSpec style — **verified, needs a decision**

`CHANGELOG.md`'s release checklist says to run `forge fmt` and `forge lint`. But `forge fmt --check src/`
currently reports diffs across the codebase: the project writes NatSpec as `* @title …` at column 0
while `forge fmt` wants ` * @title …`. Running the checklist as written would reformat every file.

**Decide one way or the other:** adopt `forge fmt` and take the one-off reformat, or drop it from the
checklist. Leaving a checklist item that nobody can run without a large diff means the checklist stops
being followed at all. (`forge lint` currently emits 14 notes, mostly the pre-existing mixed-case
naming of `ERC20TokenPayment`.)

### C-3. An incremental build breaks the test run — **verified, recurring**

Running `forge test --ffi` after a partial rebuild fails every test with
`Failed to run upgrade safety validation: … Build info file … is not from a full compilation`. The cause
is the OpenZeppelin Upgrades plugin requiring a full build; the fix is `forge clean && forge build`
first. CI already does this, but a contributor running tests locally hits a confusing error that names
neither the cause nor the fix.

**Suggested fix:** a `Makefile` target or npm script (`npm run test` → `forge clean && forge build &&
forge test --ffi`), and a line in the README.

### C-4. No deployment script — **verified**

There is no `script/` directory. `package.json` referenced one until recently. Both deployment variants
need a non-trivial sequence (deploy implementation, deploy proxy, initialize with five arguments, grant
roles), and the ordering constraints are currently documented only in the test helper.

**Suggested fix:** `script/DeployIncomeVault.s.sol` and `script/DeployIncomeVaultOwnable2Step.s.sol`,
using the same `Upgrades` plugin the tests use so the deployment path is the tested one.

## D. Documentation and repository hygiene

### D-1. The committed coverage report belongs to a different project — **verified**

`doc/test/coverage/` contains pages for `RuleEngine.sol`, `RuleWhitelist.sol` and
`RuleSanctionList.sol`. Grepping the whole directory for any IncomeVault contract name returns
**nothing**. It is coverage output from the *RuleEngine* repository, committed here and never replaced.

This is the most misleading artefact in the repository: it looks authoritative and describes another
codebase. **Delete it, or regenerate in place.**

### D-2. `doc/solidityAPI/index.md` is stale — **verified**

Generated by `solidity-docgen` before the CMTAT v3 migration; it predates the base/variant split, the
ERC-7201 storage, the authorization hooks and `ISnapshotSource`. Regenerate with `npx hardhat docgen`
or drop it — a generated API reference that describes a previous architecture is worse than none.

### D-3. `doc/audits/tools/slither-report.md` is stale — **verified**

Predates every refactor in this branch, and the README links it under "Audits". Re-run Slither, or mark
the file with the commit it describes. Neither is expensive; leaving it as is implies a clean run
against the current code.

### D-4. `doc/schema/drawio/` is now entirely unreferenced — **verified**

All four exported PNGs were replaced by PlantUML diagrams. What remains — `IncomeVault.drawio`,
`Engine.drawio`, `Engine-IncomeVault.drawio.png` — is referenced from nowhere. The `.drawio` sources
are editable originals so deletion is a real choice, not obvious cleanup: keep them if anyone still
opens them, drop the directory if not.

### D-5. No `SECURITY.md` and no `@custom:security-contact` — **verified**

The README says to email `admin@cmta.ch`, but there is no `SECURITY.md` (which GitHub surfaces in its
own UI) and no `@custom:security-contact` NatSpec tag on the deployable contracts (which block
explorers surface on verified source). A researcher looking at the deployed contract has no in-band
route to report.

## E. Product gaps

### E-1. A holder cannot delegate their claim — **suggestion**

`claimDividend` always pays `_msgSender()`. There is no `claimDividendFor(holder, time)` and no
operator concept, so a custodian cannot claim on behalf of the holders it serves, and a holder who has
lost gas access cannot have anyone claim for them. `distributeDividend` is the issuer's tool, not the
holder's.

ERC-7540's `setOperator` (with ERC-7741 signed authorisation) is the standard shape for this; the
comparison section in `doc/README.md` already notes the vault lacks it. Adding a holder-authorised
operator is the single largest usability gap.

### E-2. No batch deposit — **suggestion**

An issuer opening several periods calls `deposit` once per `time`. A `depositBatch(times[], amounts[])`
would cut the transaction count for the common "quarterly coupons for the year" setup. Small, and
symmetric with the existing batch claim.

### E-3. Dust is only recoverable by an untimed sweep — **suggestion**

Rounding down leaves a residue per period, recovered with `withdraw(time, …)` after
`timeLimitToWithdraw`. Nothing computes what the residue *is*, so an issuer sweeping has to reconstruct
it off-chain from the deposit minus the sum of `DividendClaimed` events. A view returning the
unclaimed remainder for a `time` would make the sweep a one-step operation.

## F. Release readiness

### F-1. Version string versus release heading — **open, see `CLAUDE_ANALYSIS.md` G-1**

`VERSION = "1.1.0"` against a `## 2.0.0` changelog heading, where the changelog's own rule makes this
release MAJOR. One line either way; it only needs a decision.

### F-2. The project depends on two release candidates — **verified**

`lib/CMTAT` is at **v3.3.0-rc3** and `lib/RuleEngine` at **v3.0.0-rc5**. This was the coherent choice —
RuleEngine v3.0.0-rc5 pins CMTAT v3.3.0-rc3, and SnapshotEngine v0.5.0 pins v3.3.0-rc1 — but shipping a
dividend vault against RC dependencies is a decision to make consciously, not to inherit. Repin to
stable tags before any deployment carrying real value, and re-run the suite when doing so.

### F-3. `evm_version = 'prague'` limits deployment targets — **suggestion**

`foundry.toml` targets Prague, and the vault uses `ReentrancyGuardTransient` (EIP-1153 transient
storage), which is unavailable on chains that have not adopted Cancun or later. If any target chain is
behind, both the EVM version and that guard need revisiting. Worth stating the intended chains
somewhere in the docs.

---

## Explicitly not recommended

Recorded so they are not re-proposed:

- **Making the vault ERC-4626 compliant.** See `doc/README.md` → "Comparison with ERC-4626 / ERC-7540
  vaults". A 4626 share entitles whoever holds it now; a dividend is allocated by record date. The
  standard has no operation for paying out without burning shares.
- **Removing the `isFrozen(from)` check** to save gas. See `CLAUDE_ANALYSIS.md` H-3: it costs a measured
  2,262 gas per claim, but removing it turns `setAddressFrozen(vault)` into a silent no-op that reports
  success.
- **Reintroducing `uint256[50] private __gap`.** Storage is ERC-7201 namespaced; the contract
  deliberately declares zero sequential slots.
- **Adding an ERC-165 guard on the snapshot source.** See `CLAUDE_ANALYSIS.md` I-1: the canonical
  `SnapshotEngine` advertises no id for it, so the guard would reject the intended implementation.
