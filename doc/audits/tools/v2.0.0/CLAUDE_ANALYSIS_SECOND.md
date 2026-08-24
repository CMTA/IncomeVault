# IncomeVault — Code Quality Review (second pass)

Produced with Claude Code. Scope: `src/` at commit `265bac1`, solc 0.8.36, EVM `prague`, 21 files / 982 nSLOC. Tests, mocks and `script/` are out of scope.

**This is a code-quality review, not a security audit. Nothing here is a vulnerability.** No finding lets an unauthorized party move value, bypass a restriction or brick a contract. The two static analyzers were run separately and independently report nothing to fix — see [`slither-report.md`](./slither-report.md) and [`aderyn-report.md`](./aderyn-report.md).

This is the **second** pass. The first is [`CLAUDE_ANALYSIS.md`](./CLAUDE_ANALYSIS.md) in this directory; its findings are not repeated here, and its two outstanding items (G-1, F-2) remain outstanding. Everything below is either new code since that review, or something the first pass missed.

## Disposition summary

| ID | Finding | Outcome |
| --- | --- | --- |
| A-1 | Loops and iteration | ⬜ nothing to change — verified, see below |
| B-1 | `_transferDividend` re-reads `_paidDividend[time]` — **209 gas** measured | ✅ **fixed**, in a better shape than proposed — **167 gas** |
| C-1 | The deposit write, its zero-check and its event are duplicated across two paths | ✅ **fixed** |
| E-1 | Three core internal functions are not `virtual` while five siblings in the same file are | ✅ **fixed** |
| G-1 | Three production comments point at `doc/` paths that have already moved twice | ✅ **fixed**, and the rule was tightened past what this finding proposed |
| G-2 | NatSpec block length | ⬜ **no change needed** — measured; corrects a worry raised during development |
| H-1 | `detectTransferRestriction` answers 0 for a payout that `canTransfer` rejects | ✅ **fixed** |
| I-1 | The vault demands `IRuleEngine`, whose `transferred` it must never call | ⬜ **keep as is** — the reason is recorded so it is not re-opened |
| J-1 | Modularity | ⬜ already covered exhaustively elsewhere; not duplicated here |

Nine rows: two are explicit "do not change" verdicts, one is "nothing found", six were recommendations. **All six recommendations — B-1, C-1, E-1, G-1, H-1 and the carried-forward version bump — have since been implemented.** What remains are the two deliberate "keep as is" verdicts (I-1, G-2), the "nothing found" row (A-1), and the modularity pointer (J-1).

## Outstanding, carried from the first pass

| ID | Item | Why it is still open |
| --- | --- | --- |
| F-2 (first pass) | `IERC3643Version` not advertised through ERC-165 | Cosmetic; no consumer known to filter on it |

The first pass's own G-1 — `VERSION = "1.1.0"` against a `## 2.0.0` changelog heading — is **closed**. `VERSION` is now `2.0.0`, with its four mirrors updated and a sabotage confirming a lone bump fails three suites. The audit directory was renamed `v1.1.0` to `v2.0.0` to match, which was a correction rather than a follow-on: the changelog has only `2.0.0` and `1.0.0` headings, so no `1.1.0` release ever existed.

---

## A. Loops and iteration

### A-1. Nothing to change — and specifically not `unchecked`

Checked and found clean: no `i++` anywhere (`grep -rn 'i++' src/` returns nothing), every loop uses `++i`, and every external array parameter is `calldata`.

There are **no `unchecked` blocks in `src/`, and none should be added.** Since Solidity 0.8.22 the compiler elides the overflow check on a bounded loop counter, so `unchecked { ++i }` on `for (uint256 i = 0; i < n; ++i)` buys nothing at 0.8.36. The first pass recorded this as A-2, "deliberately not applied"; re-confirming it here so the next reviewer does not propose it a third time.

The two `address[] memory` parameters (`IncomeVaultSnapshotCore._snapshotInfoBatch`, and its implementation) are **internal hooks, not external entry points**, so `calldata` is not available: the caller in `IncomeVaultOpen` builds a one-element array in memory. This is documented at the declaration.

**Verdict: leave.** Unbounded iteration over caller-supplied arrays remains by design (first pass, A-3) — the caller chooses the batch size and pays for it.

## B. Storage reads

### B-1. `_transferDividend` reads `_paidDividend[time]` twice — 209 gas, measured

`IncomeVaultInternal._transferDividend`:

```solidity
if (tokenHolderDividend > unclaimedDividend(time)) {   // reads _segregatedDividend + _paidDividend
    revert IncomeVault_NotEnoughAmount();
}
$._paidDividend[time] += tokenHolderDividend;           // reads _paidDividend AGAIN, then writes
```

`unclaimedDividend` is a **public** view called internally, and the optimizer does not forward its `_paidDividend` load into the `+=` on the next line. This is the read-modify-write shape the guidance says reliably pays off, as opposed to two plain adjacent loads where hand-caching is a pessimisation.

**Measured, not estimated.** Baseline `claimDividend`, toggled in place on the real contract and re-run against the same test (`testHolderCanClaimWithDepositAndOneHolder`, `forge test --gas-report`):

| Variant | `claimDividend` gas | Delta |
| --- | --- | --- |
| Current | 118,924 | — |
| Cache `paid` inline, duplicating the saturating expression | 118,715 | **−209** |
| Shared `_unclaimedDividend($, time)` helper returning `(unclaimed, paid)` | 118,782 | **−142** |

**This came out higher than predicted.** I expected roughly one warm SLOAD (~100 gas); the measurement says 209. The extra is the second `_getIncomeVaultInternalStorage()` and the call frame of the public view, neither of which the optimizer collapsed. Recording the discrepancy because it is the reason to measure rather than reason from opcode costs.

**Recommended: the helper, not the inline version**, giving up 67 gas to keep one source of truth. The saturating rule (`segregated > paid ? segregated - paid : 0`) exists for a documented reason — a mid-window sweep can push `paid` above `segregated` — and duplicating it means the next person to change it must find both copies.

The shape already has house precedent: `_timeCode(IncomeVaultInternalStorage storage $, ...)` takes the storage pointer for exactly this reason, so a batch reads the limit once instead of once per element.

```solidity
function _unclaimedDividend(IncomeVaultInternalStorage storage $, uint256 time)
    internal view virtual returns (uint256 unclaimed, uint256 paid)
{
    uint256 segregated = $._segregatedDividend[time];
    paid = $._paidDividend[time];
    unclaimed = segregated > paid ? segregated - paid : 0;
}
```

`unclaimedDividend(time)` then returns the first value, `_transferDividend` uses both. **Verified: implemented, all 214 tests pass, then reverted** — this pass reports rather than applies.

**Verdict: implement the helper variant**, on the hottest path in the contract. 142 gas on every single claim.

## C. Events

### C-1. The deposit write, its validation and its event are duplicated across two paths

`grep -rn 'emit newDeposit' src/` returns **two** sites, and each carries its own copy of the zero-check and the storage write:

| | `deposit` (L73-81) | `depositBatch` (L100-116) |
| --- | --- | --- |
| zero-amount check | `if (amount == 0) revert` | `if (amounts[i] == 0) revert` |
| storage write | `$._segregatedDividend[time] += amount` | `$._segregatedDividend[times[i]] += amounts[i]` |
| event | `emit newDeposit(...)` | `emit newDeposit(...)` |

The invariant *"every deposit validates the amount, writes the period, and emits"* is held **by convention**, not structurally. A third funding path — and this codebase has grown one already — has nothing forcing it to do all three.

This is the mirror image of the first pass's C-1/C-2/C-3, which fixed silent writes by routing them through `_setX` helpers. `depositBatch` was added *after* that review, and reintroduced the pattern those findings removed. The first pass's C-5 recorded "one emit site per event, all inside a helper" as already correct; that is no longer true.

**Proposed:**

```solidity
function _deposit(IncomeVaultInternalStorage storage $, address sender, uint256 time, uint256 amount)
    internal virtual
{
    if (amount == 0) {
        revert IncomeVault_NoAmountSend();
    }
    $._segregatedDividend[time] += amount;
    emit newDeposit(time, sender, amount);
}
```

**The validation moving into the helper is the part that changes behaviour**, and it is a feature: the zero-check then guards every path that can write a period, including any added later.

**The single ERC-20 transfer must stay outside the helper.** `depositBatch` deliberately does one `safeTransferFrom` for the whole batch — that is the documented reason it exists, and folding the transfer into `_deposit` would undo it. The helper owns validate-write-emit and nothing else.

**Verdict: implement.** ✅ **Done.** `_deposit($, sender, time, amount)` lives in `IncomeVaultInternal` beside the other state-writing internals, and takes the storage pointer as {_timeCode} does so a batch acquires it once. `grep -rn 'emit newDeposit' src/` now returns **one** site, and one `+=` writer of `_segregatedDividend`.

**In the event, the widened validation turned out to change nothing**, because both existing paths already carried the zero-check. The report presented it as the behaviour-changing part; it is not, and the value is entirely structural — a third funding path now inherits all three behaviours instead of having to remember them.

**Both sabotages fail tests on *both* paths, which is the property being bought:**

| Sabotage | Failures |
| --- | --- |
| drop `emit newDeposit` from the helper | `testDepositRoleCanPerformDeposit` **and** `testDepositBatchPullsTheTokenOnceAndEventsEachEntry` |
| drop the zero-amount check | `testCannotDepositZeroAmount` **and** `testCannotDepositBatchWithAZeroAmount` |

One change to the shared helper breaks the single path and the batch path together — before, each had its own copy and its own tests, and a change to one would have left the other silently intact.

The batch path measured **136,263** gas in-call afterwards against 136,546 before, so the extraction is 283 gas cheaper rather than a cost. `doc/README.md` and `CHANGELOG.md` are updated to the new figure.

## D. Duplication

Nothing beyond C-1, which is the only new instance. The first pass's D-1 — the context-disambiguation block repeated in both deployment contracts — is unchanged and still correctly left alone: `override(IncomeVaultBaseERC2771, ContextUpgradeable)` names contract types that differ per variant, so the block cannot be hoisted.

## E. `virtual` convention

### E-1. Three core internal functions are not `virtual` while five siblings in the same file are

Within `IncomeVaultInternal`:

| `virtual` | not `virtual` |
| --- | --- |
| `_setERC20TokenPayment`, `_setTimeLimitToWithdraw`, `_setStatusClaim`, `_revertOnInvalidTime`, `_timeCode` | **`_transferDividend`, `_computeDividend`, `_computeDividendBatch`** |

**The inconsistency inside one file is the evidence** — whichever is right, five-against-three in the same contract is a defect. This is the same argument the first pass used for E-1 on `IncomeVaultOpen`, and the same conclusion.

Prioritised by consequence, `_transferDividend` is the one that matters. It is the payout routine, and `CLAUDE.md` states that the way to extend it is explicitly **not** to add another public entry point:

> `transferDividendSelf` is a self-call helper with no role check … never add another public entry point to `_transferDividend`.

If the sanctioned extension route is not a new entry point, it is an override — and the function cannot be overridden. A variant wanting a withholding deduction, a payout fee or a different transfer strategy has nowhere to put it.

The four `_getXStorage` accessors are **also** non-virtual, and that is correct: all four are consistent, and OpenZeppelin declares the equivalent `private`. Not a finding.

**`virtual` on an internal function is free — measured, not asserted.** Two single-function contracts, identical bodies, identical warm-up, `gasleft()` deltas:

| Variant | gas |
| --- | --- |
| `internal` | 23,032 |
| `internal virtual` | 23,021 |

An 11-gas difference *favouring* virtual, i.e. layout noise. Internal calls are resolved statically, so there is no dispatch to pay for.

**Verdict: add `virtual` to all three.** ✅ **Done.** All nine internal functions in the file are now `virtual` except `_getIncomeVaultInternalStorage`, which stays non-virtual with its three sibling accessors — OpenZeppelin declares the equivalent `private`, and a slot accessor is not an extension point.

`IncomeVaultOverrideMock` now overrides all three, and **`test/OverrideMock.t.sol` drives a real deposit-and-claim through it**, which the mock previously lacked: it was compile-only, while its own NatSpec claimed `claimCount` proved the override was reached. Nothing called it, so that claim was false. It is true now.

**Both failure modes verified, because they are different:**

| Sabotage | Caught by | Result |
| --- | --- | --- |
| remove `virtual` from `_transferDividend` | the compiler | `Error (4334): Trying to override non-virtual function` |
| override present but not observably reached | the counter | `internal _transferDividend override was not reached: 0 != 1` |

The second is the one a compile-only guard misses, and it is why the counters exist rather than a bare override.

**An honest limit of the technique**, now stated in the mock: a `view` override cannot increment a counter, so `_computeDividend` and `_computeDividendBatch` stay compile-guarded only. Their `virtual` is pinned by `Error (4334)`, not by an assertion that they ran.

## F. ERC / specification conformance

No new conformance finding. The interface ids are unchanged and still asserted by tests; `IIncomeVault` was added since the first pass and is advertised by both deployment variants, while ERC-7540's operator id remains deliberately unadvertised with a test pinning that. First-pass F-2 stays outstanding.

The behaviour worth raising is a semantics question rather than an id question, so it is under H.

## G. Code / documentation mismatch

### G-1. Three production comments point at documentation paths that have already moved

```
src/interfaces/IERC7540Operator.sol:10   "Comparison with ERC-4626 / ERC-7540 vaults" in `doc/README.md`
src/interfaces/IIncomeVault.sol:22       See the capability table in `doc/README.md`.
src/modules/VersionModule.sol:13         Bump `VERSION` together with the `CHANGELOG.md`
```

**The evidence this matters is in this repository's own recent history**: documentation has been reorganised twice — a new `doc/cmtat-standard/` directory, and the audit reports moved from `doc/audits/` into `doc/audits/tools/vX.Y.Z/`. A path baked into a contract is a stale link waiting to happen, and unlike a link in a markdown file it **cannot be fixed after deployment**: the comment lives in the verified source forever.

The second problem is the one that bites. Someone reading the verified source on a block explorer has the contract and nothing else. A pointer to `doc/README.md` is a reference they cannot follow.

**The fix is not to delete the sentences.** Both `doc/README.md` pointers trail a complete thought — `IIncomeVault:22` already says *"chosen by the deployment contract, not by this interface"* before pointing at the table — so the pointer comes out cleanly and the substance stays.

**`VersionModule.sol:13` is different and should be left alone.** It cites `CHANGELOG.md` by **bare filename**, which survives any reorganisation, and the instruction it gives ("bump these together") is actionable without opening the file.

**Verdict: drop the two `doc/README.md` path pointers, keep the sentences, keep the `CHANGELOG.md` reference.** ✅ **Done — and then taken further, on the maintainer's instruction.**

### What was actually applied

The rule adopted is stricter than this finding proposed: **`CHANGELOG.md` is the only file reference permitted in a contract comment.** `src/` now contains exactly one, in `VersionModule`.

Nine references were removed, in four groups. This finding had spotted three of them and had explicitly *exempted* two of the groups, so the correction is worth recording rather than glossing:

| Group | Count | This finding said | What was done |
| --- | --- | --- | --- |
| `doc/README.md` path pointers | 2 | remove | removed |
| `CHANGELOG.md` | 1 | keep | kept |
| Audit findings cited by id (`finding H-1 of CLAUDE_ANALYSIS_SECOND.md`) | 2 | **exempt** — an immutable record, and the bare filename survives a move | **removed** |
| Test-file pointers (`asserted in test/Operator.t.sol`, four ERC-7201 slot comments) | 6 | not raised at all | **removed** |

**The exemption I argued for does not survive contact with the actual reader.** A finding id means nothing to someone reading verified source on a block explorer, and it was ambiguous even internally — both this file and `CLAUDE_ANALYSIS.md` have an `H-1`. The same applies to a test pointer: *"asserted in `test/Operator.t.sol`"* tells a reader that a guarantee exists somewhere they cannot look.

In each case the pointer was replaced by the thing it was standing in for:

| Was | Now |
| --- | --- |
| "finding H-1 of `CLAUDE_ANALYSIS_SECOND.md`" | "consulting only the RuleEngine here would report a paused vault or a frozen holder as unrestricted, and the claim would then revert" |
| "asserted in `test/Operator.t.sol`" | "change either one and the id no longer matches what ERC-7540 assigns" |
| "The derivation is re-checked in `test/IncomeVaultStorage.t.sol`" | "Recompute it with `SlotDerivation.erc7201Slot()` before trusting a change to it" |
| "Finding C-1 of `CLAUDE_ANALYSIS_SECOND.md`" | "Each path carrying its own copy is what lets them diverge, so a new funding path must call this rather than repeat it" |

Every replacement is actionable without leaving the file, which is the property the original finding was reaching for and only half-applied. `CLAUDE.md`/`AGENTS.md` carry the tightened rule, including the instruction not to cite the test that asserts a property — give the property and the consequence of breaking it.

### G-2. NatSpec block length — no change needed

Raised during development as a worry that the contracts were accumulating essay-length comment blocks. **Measured across `src/`, the worry is unfounded:**

| | |
| --- | --- |
| blocks | 164 |
| median | **5 lines** |
| p90 | 13 lines |
| max | 26 lines |
| blocks ≥ 20 lines | **3** |

The three outliers are `distributeDividendBestEffort` (26), and the `ISnapshotSource` (21) and `IIncomeVault` (20) interface headers — all three carrying a design constraint or a safety precondition rather than restating the code.

For contrast, the pattern this check exists to catch looks like a median of 4 with a dozen blocks between 24 and 44. This codebase is nowhere near it.

**Verdict: leave. Explicitly recorded so the worry is not re-raised** — it was mine, and the data does not support it.

## H. Weird behaviour — correct but at odds with the purpose

### H-1. `detectTransferRestriction` returns "no restriction" for a payout that will revert

`IncomeVaultValidationModule.detectTransferRestriction` consults **only** the RuleEngine:

```solidity
IRuleEngine ruleEngine_ = ruleEngine();
if (address(ruleEngine_) == address(0)) {
    return 0;                                    // "no restriction"
}
return IRuleEngineERC1404(address(ruleEngine_)).detectTransferRestriction(from, to, value);
```

`canTransfer`, on the same contract, checks **three** things: pause, freeze of either party, then the RuleEngine.

So for a **paused** vault, or a **frozen** holder, `detectTransferRestriction` answers `0` while `canTransfer` answers `false` and the claim reverts with `IncomeVault_InvalidTransfer`. Two views on one contract disagree about the same payout, and the one with the ERC-1404 name is the one that is wrong.

An integrator pre-flighting a claim reaches for the function whose entire purpose is "tell me why this would fail". It tells them nothing is wrong.

**The NatSpec already documents the gap** — *"The pause and freeze states are not reflected here, only the rules: use `canTransfer` for the complete answer"* — which is honest, and is why this is a quality finding rather than a security one. But documenting a misleading return value is weaker than not returning one.

**The fix is well-specified, because CMTAT already defines the codes.** `REJECTED_CODE_BASE` in `draft-IERC1404.sol`:

```
TRANSFER_OK = 0
TRANSFER_REJECTED_DEACTIVATED = 1
TRANSFER_REJECTED_PAUSED = 2
TRANSFER_REJECTED_FROM_FROZEN = 3
TRANSFER_REJECTED_TO_FROZEN = 4
```

Returning `TRANSFER_REJECTED_PAUSED` when paused and `TRANSFER_REJECTED_FROM_FROZEN` / `TO_FROZEN` when either party is frozen, before falling through to the RuleEngine, makes the two views agree and uses the ecosystem's own numbering rather than inventing any.

**One honest limit:** the vault does **not** advertise `IERC1404` through `supportsInterface` and does not inherit it, so it is not claiming ERC-1404 conformance today. That lowers the severity — but the function carries the ERC-1404 name and signature, and no integrator reads a `supportsInterface` result before trusting a function that is right there.

**Verdict: implement.** ✅ **Done.**

`detectTransferRestriction` now evaluates deactivation, pause, either party frozen, then the RuleEngine — the same order and the same conditions as `canTransfer` — returning CMTAT's `REJECTED_CODE_BASE` codes. Deactivation is tested before pause because deactivating requires the pause state, so the more specific code wins.

`messageForTransferRestriction` was fixed in the same change, and it needed it: it answered `"No restriction"` for **every** code when no RuleEngine was set, including codes that mean something. It now answers for each code the vault can issue, delegates anything else to the RuleEngine, and returns `"UnknownCode"` when there is no RuleEngine to ask. The strings are CMTAT's `ValidationModuleERC1404` verbatim (`EnforcedPause`, `AddrFromIsFrozen`, …), so an operator console written against a CMTAT reads a payout refusal exactly as it reads a transfer refusal.

**`canTransfer` was deliberately left calling `ruleEngine_.canTransfer` rather than being rewritten as `detectTransferRestriction(...) == 0`.** The latter would make agreement structural instead of tested, which is tempting — but it changes *which* RuleEngine entry point the payout path calls on every claim. A third-party engine is free to implement the two differently, so that is a behaviour change against an external contract in exchange for tidiness. Agreement is pinned by a test instead.

`test/TransferRestrictionCode.t.sol`, 6 tests. **Verified the guards guard:** reverting `detectTransferRestriction` to the RuleEngine-only body fails three of them with `0 != 2`, `0 != 4` and `0 != 1` — the exact defect; reverting the message half fails the other two with `No restriction != EnforcedPause`. One existing test, `EdgeCases.testErc1404ViewsWithoutARuleEngine`, was asserting the old strings and was updated: it had been pinning the defect.

## I. Interface granularity

### I-1. The vault requires `IRuleEngine` but calls three read-only functions — keep it anyway

The vault calls exactly three members, all views:

```
IncomeVaultValidationModule.sol:100   ruleEngine_.canTransfer(...)
IncomeVaultValidationModule.sol:123   IRuleEngineERC1404(...).detectTransferRestriction(...)
IncomeVaultValidationModule.sol:138   IRuleEngineERC1404(...).messageForTransferRestriction(...)
```

`IRuleEngine` declares `transferred` directly and inherits the ERC-3643 compliance and ERC-1404 surfaces. So the required interface **mandates `transferred`** — which `CLAUDE.md` states the vault must never call, because it is not a bound token and the call would revert.

That is the check-I smell in an unusually pure form: the demanded interface requires the one function whose invocation is forbidden. Read narrowly, it rejects a read-only compliance oracle, which would have to expose a `transferred` that reverts purely to satisfy the type — a stub advertising a capability the contract does not have.

**Do not fix it, and here is why the obvious precedent does not apply.** The first pass's I-1 narrowed the snapshot dependency to `ISnapshotSource`, and it is tempting to do the same here. The two cases are not alike:

- The snapshot source was a **project-owned** reference. The vault declared its own storage and its own getter, so narrowing the type cost nothing.
- The RuleEngine reference is **not the project's**. It lives in CMTAT's `ValidationModuleRuleEngineInternal`, at a hardcoded ERC-7201 slot, typed `IRuleEngine` by `ruleEngine()`. Narrowing means leaving that base — which would give up the property that a CMTAT host and the embedded vault logic share **one** RuleEngine, the whole substance of modularity finding M-4.

The cost of the current design is that an implementer must satisfy a wider interface than the vault uses. The cost of narrowing it is two RuleEngines in a composed contract. The second is worse.

**Verdict: keep. Recorded here specifically so the `ISnapshotSource` precedent is not applied to it by a future reviewer** — including me, since I proposed exactly that reasoning for the snapshot side.

## J. Modularity

Assessed exhaustively in `IMPROVEMENT_MODULARITY.md` (M-1 to M-9) and not repeated here. Current state, as compile results rather than opinion:

- `test/mocks/CMTATDividendHostMock.sol` — a `CMTATUpgradeableInternalSnapshot` embedding the distribution logic — **compiles**. Before M-1 it failed `Error (5005)`; after M-1 it still failed on a `snapshotEngine()` return-type collision, which M-2 removed.
- `test/mocks/EmbeddedDividendHostMock.sol` and `test/mocks/NoForwarderVaultMock.sol` compile, covering the non-CMTAT host and the deployment without ERC-2771.

The one open item there is **M-3b**: SnapshotEngine vendors its own CMTAT at `v3.3.0-rc1` while this project pins `v3.3.0-rc3`, so mixing the project's CMTAT-derived modules with SnapshotEngine's CMTAT contracts fails with nine duplicate-identifier errors. It is contained only because `IncomeVaultValidationModule` is the sole CMTAT-derived module and M-1 removed it from the embeddable path.

**Since tested, and the recorded fix was wrong.** Aligning the nested CMTAT to `v3.3.0-rc3` so both trees hold identical source leaves the same nine errors: Solidity keys a contract by its source unit, not its contents, so two paths are two contracts even byte-identical. Remapping cannot help either, because SnapshotEngine imports CMTAT by *relative* path and remappings only rewrite non-relative prefixes. There is no fix available inside this repository; the correction is recorded in `IMPROVEMENT_MODULARITY.md`.

---

## What the static analyzers did not find

Worth recording, because it calibrates what the tools are for. Slither (34 results) and Aderyn (10) each report **nothing to fix** on this codebase. Every finding above came from reading the code against the project's own conventions and from measuring; none of them appears in either tool's output — and neither tool found any of the substantive defects listed in `doc/audits/AUDIT_OVERVIEW.md` either.
