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
3. ~~**B-1, B-2, B-3, B-4**~~ ✅ done. **B-5** — the untested gasless path.
4. ~~**C-4**~~ ✅ done. **C-1** — make CI catch what is currently caught only by hand.
5. ~~**A-3, A-4, E-1**~~ ✅ all done.
6. ~~**E-2**~~ ✅ done. Everything else as capacity allows.

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

### A-4. No way to pre-check a distribution — ✅ **implemented (best-effort variant)**

Since the H-2 fix, one blocked holder reverts the whole `distributeDividend` call. That is the right
semantics, but an operator distributing to a large list can only discover a bad address by spending a
transaction and reading the revert.

**Implemented differently, and better.** Rather than a pre-check view that could go stale between the
query and the transaction, `distributeDividendBestEffort` skips the refused holders in the same call:
it returns `(paidCount, skipped[])` and emits `DividendDistributionSkipped` with the raw revert data
per skip. The operator gets the answer *and* the payout in one transaction instead of two.

Each payout is attempted through an external self-call wrapped in `try`/`catch` — the only way to catch
a revert from the RuleEngine view or from `safeTransfer` — which also gives per-holder atomicity: a
skipped holder is not marked as claimed and can still claim later.

The self-call helper `transferDividendSelf` is guarded by `msg.sender == address(this)`; removing that
guard was confirmed to fail `testNobodyCanCallTheSelfHelperDirectly`.

## B. Tests

### B-1. `deactivateContract()` is never exercised — ✅ **implemented**

`grep -rn 'deactivateContract' test/` returns nothing, and the coverage report confirms
`_authorizeDeactivate` is never entered in either variant. This is the one **irreversible** action in
the system: it permanently disables the contract, and with a proxy the only way back is a new
implementation.

**Implemented.** `test/Deactivate.t.sol`, nine tests across both variants: the pause precondition
(`ExpectedPause`), the irreversibility (`CMTAT_PauseModule_ContractIsDeactivated` on any later
`unpause`), `AlreadyDeactivated` on a second call, that both `claimDividend` and `distributeDividend`
are refused afterwards, that an attacker cannot deactivate, and that **`PAUSER_ROLE` alone is not
enough** — deactivation needs the admin even though pausing does not.

### B-2. Branch coverage is 68.75% — ✅ **implemented (now 97.56%)**

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

**Implemented.** `test/EdgeCases.t.sol` covers the reachable gaps — the three initializer guards
(zero admin, zero owner, zero payment token), a holder with no tokens at the snapshot
(`IncomeVault_TokenBalanceIsZero`, distinct from `NoDividendToClaim`), the ERC-1404 views with no
RuleEngine configured, and every `TIME_ERROR_CODE` arm through both `validateTimeCode` and
`validateTime`.

`_revertOnInvalidTime` was also restructured to end in an unconditional `else`, which removed three
dead branches on an exhaustive enum **and** closed a fail-open path (see the changelog).

| Metric | before | after |
| --- | --- | --- |
| Lines | 92.09% | **95.65%** |
| Statements | 94.54% | **97.54%** |
| Branches | 68.75% | **97.56%** |
| Functions | 87.01% | **89.41%** |

**What is deliberately left uncovered**, so nobody chases it:

- `_computeDividend`'s `senderBalance == 0` guard — the one remaining branch. Both callers pre-check
  (`claimDividend` rejects a zero balance first, `claimDividendBatch` only calls it when the balance is
  positive), so it is unreachable defensive code. It must stay: reaching it would require widening
  visibility, which trades safety for a metric.
- The six abstract `_authorize*` declarations — they have no body and cannot be "entered"; the
  overrides in both deployment contracts are fully covered.
- `_msgData` in the three deployment contracts — an override required to resolve the ERC-2771/Context
  diamond, never called because nothing in the vault reads calldata. See B-5.

### B-5. The ERC-2771 gasless path has no end-to-end test — **suggestion**

`_msgSender()` is exercised on every claim, but only in the non-relayed case: no test ever routes a
call through a trusted forwarder, so the *unwrapping* behaviour the gasless support depends on is
unverified. This is also why `_msgData` shows as never entered.

The vault is deployed in every test with `forwarderIrrevocable = address(0)`. A test deploying an
`ERC2771Forwarder`, signing a request and checking that `claimDividend` credits the **signer** rather
than the relayer would cover the documented gasless feature. Worth more than the coverage percentage it
would move.

### B-3. No fuzz or invariant tests — ✅ **implemented**

The suite is entirely example-based. The accounting has properties worth stating as invariants:

- the sum of everything paid out for a `time` never exceeds `segregatedDividend[time]`;
- `claimedDividend[holder][time]` is monotonic — once true it never returns to false;
- a holder can never be paid twice for the same `time` by any combination of `claimDividend`,
  `claimDividendBatch` and `distributeDividend`;
- `withdraw` can never reduce `segregatedDividend[time]` below zero (currently guarded by a check that
  a fuzz run would confirm).

**Implemented.** `test/invariant/` — a bounded handler (three dividend times, three holders) driving
deposits, claims, batch claims, both distribution variants, withdrawals, freezes, pauses and time
warps, plus six invariants. 48 runs x 64 depth = **3,072 calls, 0 reverts** per invariant, pinned in
`foundry.toml` so CI runs the same budget.

| Invariant | Property |
| --- | --- |
| `neverPaysMoreThanWasDeposited` | total paid out never exceeds total deposited |
| `noHolderIsPaidTwiceForOneTime` | a holder is paid at most once per period, **across all three payout paths** |
| `claimedFlagIsMonotonic` | a paid holder is always marked claimed |
| `noUnexplainedPayment` | every batch payout is explained by a period becoming claimed |
| `balanceAccountsForEveryDeposit` | `balance == deposited - paid - withdrawn`; value cannot leak to a non-holder |
| `segregatedNeverExceedsDeposits` | the per-time accounting never exceeds what was deposited |

**The suite was validated by sabotage, and the first attempt failed that validation.** Removing the
double-claim guard from `claimDividend` initially left every invariant green: the ghost counted
payments by `claimedDividend` flag *transitions*, and a second payment for an already-claimed period
leaves the flag untouched. Counting actual balance increases instead makes the same sabotage fail with
`a holder was paid twice for the same dividend time: 2 > 1`. An invariant that cannot fail is worth
nothing, and this one could not until it was fixed.

### B-4. The Ownable2Step deployment is duplicated across three test files — ✅ **implemented**

By the time this was implemented the copy had spread to **five** files — `AccessControlHooks`,
`VersionModule`, `SnapshotSource`, `SetSnapshotEngine` and `Deactivate` — which is the argument for
hoisting it.

**Implemented.** `HelperContract` now owns `_deployOwnableVault()` (and an overload taking a
RuleEngine) beside `_deployContracts()`, along with the shared `ownableVault` and `OWNER` declarations.
Four call sites collapsed to one line each.

`EdgeCases.t.sol` deliberately keeps its own construction: it builds an implementation directly to test
the zero-owner initializer guard, and never wants a working proxy.

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

### C-4. No deployment script — ✅ **implemented**

There is no `script/` directory. `package.json` referenced one until recently. Both deployment variants
need a non-trivial sequence (deploy implementation, deploy proxy, initialize with five arguments, grant
roles), and the ordering constraints are currently documented only in the test helper.

**Implemented**, one per variant, using the same `Upgrades` plugin as the tests.

Two decisions worth recording:

- **`deploy(config)` is separated from `run()`.** `run()` reads the environment and broadcasts;
  `deploy` takes an explicit struct and does neither, so `test/script/Deploy.t.sol` drives the exact
  code an operator runs without needing any environment. The env path is covered too — a dry run with
  the variables set reaches the config check and reports the right failure.
- **The scripts validate what the contract cannot.** Zero addresses are already rejected by
  `initialize`, so the scripts add only the check the contract has no way to make: that
  `PAYMENT_TOKEN`, `SNAPSHOT_ENGINE` and any `RULE_ENGINE` are actually contracts. An EOA there
  initializes cleanly and reverts on the first claim, long after the deployment looked successful.

13 tests, the strongest being that a vault produced by the script pays a dividend end to end, rather
than merely returning an address.

Scripts are excluded from the style check (`check_order.py src/`) and from coverage, so their
`require(..., "message")` guards are deliberate: a readable console message is worth more than a custom
error to someone running a deployment.

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

### E-1. A holder cannot delegate their claim — ✅ **implemented**

`claimDividend` always pays `_msgSender()`. There is no `claimDividendFor(holder, time)` and no
operator concept, so a custodian cannot claim on behalf of the holders it serves, and a holder who has
lost gas access cannot have anyone claim for them. `distributeDividend` is the issuer's tool, not the
holder's.

ERC-7540's `setOperator` (with ERC-7741 signed authorisation) is the standard shape for this; the
comparison section in `doc/README.md` already notes the vault lacks it. Adding a holder-authorised
operator is the single largest usability gap.

**Implemented** with the ERC-7540 shape — `setOperator`, `isOperator`, `OperatorSet`, plus
`claimDividendFor` and `claimDividendBatchFor`. Payouts always go to the holder; the operator only
pays the gas and picks the moment. 13 tests, including that a revoked operator, a stranger, and an
operator authorised by a *different* holder are all refused, and that every other rule (window,
already-claimed, freeze) still applies. Removing the authorisation check fails three of them.

ERC-7741 signed authorisation is **also implemented** (`ERC7741Module`), so the holder can appoint a
custodian by signature alone, without ever transacting. 14 further tests, including replay, expiry,
forgery, field tampering, per-holder nonce invalidation and unordered nonces.

**Implementing this surfaced a pre-existing accounting defect**, via the invariant suite added in B-3
rather than via E-1 itself — see the note under E-3.

### E-2. No batch deposit — ✅ **implemented**

An issuer opening several periods calls `deposit` once per `time`. A `depositBatch(times[], amounts[])`
would cut the transaction count for the common "quarterly coupons for the year" setup. Small, and
symmetric with the existing batch claim.

**Implemented — and the stated rationale turned out to be wrong.** "One transfer instead of N" does
*not* make the call cheaper: measured over three periods the batch costs **136,546 gas against 116,812**
for three separate `deposit` calls, because decoding two dynamic `calldata` arrays outweighs the saved
transfers. The benefit is entirely the intrinsic per-transaction cost — 21,000 once instead of three
times — giving **157,546 against 179,812** for what a caller actually pays.

The first version of the gas test asserted the batch was cheaper and **failed**, which is what surfaced
this. It now measures the honest comparison and asserts *both* facts: more expensive in-call, cheaper
per transaction.

A follow-up worth noting: neither `deposit` nor `depositBatch` refuses a deposit into a period whose
claims are already open, although `doc/README.md` warns that doing so dilutes holders who have not
claimed yet. Enforcing it would be a behaviour change to both, so it is left as a separate decision.

### E-3. Dust is only recoverable by an untimed sweep — ✅ **implemented, and it uncovered a bug**

Rounding down leaves a residue per period, recovered with `withdraw(time, …)` after
`timeLimitToWithdraw`. Nothing computes what the residue *is*, so an issuer sweeping has to reconstruct
it off-chain from the deposit minus the sum of `DividendClaimed` events. A view returning the
unclaimed remainder for a `time` would make the sweep a one-step operation.

**Implemented — and building it exposed a real accounting bug.** Writing the view required tracking how
much each period had paid out, which is precisely the number `withdraw` was missing. Demonstrated
before the fix: with 1,000 deposited for `t1` and 1,000 for `t2`, the sole holder of `t1` claims all
1,000; `segregatedDividend[t1]` still reads 1,000 because the denominator is never reduced; and
`withdraw(t1, 1000)` **succeeds, draining `t2`'s money**. `t2` then reports 1,000 owed against a vault
balance of 0.

So E-3 delivered three things rather than one:

1. `paidDividend(time)` and `unclaimedDividend(time)` — the requested views.
2. `withdraw` bounded by `unclaimedDividend` instead of `segregatedDividend`, closing the cross-period
   drain. Reverting the bound makes the new invariant fail.
3. `invariant_everyPeriodResidueIsBacked` — sum of residues must never exceed the vault's balance. The
   original invariant suite compared against total *deposits* and was blind to this; the new one fails
   with an arithmetic underflow against the old code, which is itself proof the old bound could drive
   `segregated < paid`.

**A second defect, found later by the invariant suite.** With the residue now tracked, a fuzz run
failed on the sequence deposit -> claim -> withdraw: sweeping a period mid-window lowers
`segregatedDividend`, so a holder claiming afterwards is priced against the reduced denominator while
the period no longer holds that much, and the shortfall was **silently funded from another period's
deposit**. Two fixes followed — `unclaimedDividend` saturates at zero instead of underflowing (a view
must never revert), and `_transferDividend` refuses a payout larger than its own period's residue.

Note the fuzzer found this **once** and did not re-find it when the fix was removed, so it is not a
reliable regression test on its own; `testAClaimCannotBeFundedByAnotherPeriod` reproduces it
deterministically and does fail without the bound.

**Cost, measured:** +22,274 gas on the first claim of each period (66,687 -> 88,961), a cold `SSTORE`
for the new counter; warm afterwards. The alternative — document the hazard and leave `withdraw`
unbounded — was rejected because the failure is silent: no revert, no event, and the loss only surfaces
when a later period's holder tries to claim.

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
