# IncomeVault — Code Quality Review

| | |
| --- | --- |
| Scope | `src/` (11 contracts, 547 code lines excluding NatSpec) |
| Commit | working tree on branch `update`, after the ERC-7201 and access-control-hook refactors |
| Compiler | Solidity 0.8.36, EVM target `prague`, optimizer 200 runs |
| Date | 2026-08-19 |
| Produced with | Claude Code |

**This is a code-quality review, not a security audit.** Nothing in this report is a vulnerability.
No finding here lets an unauthorized party move value, bypass a restriction, or brick a contract.
The findings with real behavioural weight (H-1 and H-2, both since fixed) required a **privileged role** to reach,
so they are compliance and consistency defects rather than exploitable ones — but they are the two
worth a maintainer decision, and they are described in full.

The contracts remain **unaudited**; this review does not change that.

---

## Disposition summary

| ID | Finding | Outcome | Where |
| --- | --- | --- | --- |
| A-1 | Batch time validation re-read one slot per element and copied `calldata` to `memory` | ✅ fixed | `IncomeVaultOpen.sol` |
| A-2 | `unchecked { ++i }` on the loop counters | ⬜ deliberately not applied | — |
| A-3 | Unbounded iteration over caller-supplied arrays | ⬜ left as is | — |
| B-1 | Repeated storage reads across an external call | ⬜ none found | — |
| C-1 | `setStatusClaim` wrote the claim switch with no event | ✅ fixed | `IncomeVaultInternal.sol` |
| C-2 | `_setERC20TokenPayment` silent while its sibling `_setSnapshotEngine` emitted | ✅ fixed | `IncomeVaultInternal.sol` |
| C-3 | `_setTimeLimitToWithdraw` silent | ✅ fixed | `IncomeVaultInternal.sol` |
| C-4 | `withdraw` / `withdrawAll` moved funds out with no event | ✅ fixed | `IncomeVaultRestricted.sol` |
| C-5 | One emit site per event, all inside a `_setX` helper | ⬜ already correct | — |
| D-1 | Context disambiguation block byte-identical in both deployments | ⬜ left as is, constraint explained | — |
| E-1 | Five `public` functions missing `virtual` against project convention | ✅ fixed + compile guard | `IncomeVaultOpen.sol` |
| F-1 | ERC-173 / Ownable2Step interface ids | ⬜ recomputed, both correct | — |
| F-2 | Neither variant advertises `IERC3643Version` via ERC-165 | ⬜ decide | — |
| G-1 | `VERSION = "1.1.0"` contradicts the CHANGELOG heading and the project's own MAJOR rule | ⚠️ **outstanding** | — |
| G-2 | CHANGELOG release checklist points at two directories that do not exist | ✅ fixed | `CHANGELOG.md` |
| G-3 | NatSpec block length | ⬜ measured, healthy, no action | — |
| G-4 | One production comment referencing a `.md` file | ⬜ left as is, reasoning below | — |
| H-1 | `distributeDividend` ignored the claim window, so it could pay on **live** balances | ✅ fixed | `IncomeVaultRestricted.sol`, `IncomeVaultInternal.sol` |
| H-2 | `distributeDividend` bypassed pause / freeze / RuleEngine | ✅ fixed | `IncomeVaultRestricted.sol` |
| H-3 | The vault checks whether it has frozen *itself* | ⬜ keep, reasoning below | — |
| H-4 | `withdrawAll` leaves the per-time accounting stale | ⬜ already documented | — |
| I-1 | The vault required 8 interface functions and called 3 | ✅ fixed | `interfaces/ISnapshotSource.sol` |

Counted from the rows above: **10 fixed**, **12 deliberately left as is**, **1 needing a decision**.

## Outstanding

| ID | Item | Why it is still open |
| --- | --- | --- |
| G-1 | Version string vs release heading | Semver call belongs to the maintainer; the CHANGELOG's own rule says this release is MAJOR |
| F-2 | ERC-165 for `IERC3643Version` | Cosmetic; no consumer known to filter on it |

---

## A. Loops and iteration

### A-1. Batch time validation re-read one storage slot per element — ✅ fixed

`validateTimeBatch` looped over `validateTime(times[i])` → `validateTimeCode(times[i])`, and every
iteration re-read `timeLimitToWithdraw` — the **same slot** each time — plus paid a `public` → `public`
dispatch. Both batch entrypoints also declared `uint256[] memory` where `calldata` works.

The fix keeps the public surface identical and adds two internal helpers, `_timeCode(...)` taking the
storage pointer and the already-read limit, and `_revertOnInvalidTime(code)`:

```solidity
function validateTimeBatch(uint256[] calldata times) public view virtual {
    IncomeVaultInternalStorage storage $ = _getIncomeVaultInternalStorage();
    // `_timeLimitToWithdraw` is the same slot for every element: read it once
    uint256 timeLimit = $._timeLimitToWithdraw;
    for(uint256 i = 0; i < times.length; ++i){
       _revertOnInvalidTime(_timeCode($, times[i], timeLimit));
    }
}
```

**Measured**, same harness toggled in place, warm-up call before each measurement, `gasleft()` deltas:

| | before | after | delta |
| --- | --- | --- | --- |
| `validateTimeBatch(1)` | 15,626 | 15,364 | −262 (−1.7%) |
| `validateTimeBatch(8)` | 35,654 | 33,705 | **−1,949 (−5.5%)** |
| marginal cost per element | 2,861 | 2,620 | −241 |

**This is why the rule is measure, not estimate.** The prediction from opcode arithmetic was ~100 gas
per element (one warm `SLOAD`). The real figure is 241 — 2.4× larger — because the refactor also
removes an internal dispatch per element and the `calldata` → `memory` copy. Reporting the predicted
figure would have understated the win by more than half.

Guarded by `testValidateTimeBatchStillRejectsEachCode` and `testValidateTimeBatchMatchesValidateTime`,
which pin all three error codes and the agreement between the batch and single paths.

### A-2. `unchecked { ++i }` — ⬜ deliberately not applied

All four loops already use `++i`. Adding `unchecked` would buy **nothing**: this project compiles with
**0.8.36**, and since **0.8.22** the compiler elides the overflow check on a loop counter it can prove
bounded. Recommending it here would be cargo-cult. Recorded so the next reviewer does not raise it.

### A-3. Unbounded iteration over caller input — ⬜ left as is

`claimDividendBatch(times)` and `distributeDividend(addresses)` both iterate a caller-supplied array
with no cap. For `claimDividendBatch` the caller pays their own gas and the only victim of an oversized
array is the caller. For `distributeDividend` the caller holds `INCOME_VAULT_DISTRIBUTE_ROLE`. Neither
is a griefing vector against a third party. A cap would add a configuration knob and a failure mode for
no benefit.

## B. Storage reads

### B-1. Reads across an external call — ⬜ none found

Checked every path that crosses an external call (`snapshotInfo`, the RuleEngine view call,
`safeTransfer`/`safeTransferFrom`) for a slot read on both sides. There are none. Note the ERC-7201
`$` pointer is *not* a storage read — `_getIncomeVaultInternalStorage()` only assigns a compile-time
constant slot — so the repeated `$` loads across the codebase cost nothing and must not be "optimised".
The one genuine repeated read was A-1, and it is inside a loop rather than across a call.

No hand-caching is recommended anywhere else: the optimizer already forwards a stored value to a later
load when nothing intervenes, so adding a local there would be a pessimisation.

## C. Events

Four writes changed state with no event. The claim switch (C-1) is the significant one: `setStatusClaim`
is the operational control that opens a distribution, and an indexer had no way to observe it.

### C-1 to C-4 — ✅ fixed

| Write | Was | Now |
| --- | --- | --- |
| `setStatusClaim` | silent | `ClaimStatusSet(time, status)` |
| `_setERC20TokenPayment` | silent | `ERC20TokenPaymentSet(token)` |
| `_setTimeLimitToWithdraw` | silent | `TimeLimitToWithdrawSet(delay)` |
| `withdraw` | silent | `Withdraw(time, withdrawAddress, amount)` |
| `withdrawAll` | silent | `WithdrawAll(withdrawAddress, amount)` |

C-2 is the sibling-inconsistency case worth naming: `_setSnapshotEngine` and `_setERC20TokenPayment` sit
on adjacent lines of the same initializer, set the two external dependencies of the vault, and only the
first emitted.

Every one of these is written through an internal `_setX` helper that owns the write **and** the event,
rather than an inline `emit` at the call site. The consequence is that they now also fire during
`initialize`, so a vault configured once at deployment has a complete on-chain trail —
`testInitializeEmitsBothEngineEvents` asserts exactly that.

### C-5. Emit sites per event — ⬜ already correct

```
newDeposit 1   DividendClaimed 1   SnapshotEngineSet 1   ERC20TokenPaymentSet 1
ClaimStatusSet 1   TimeLimitToWithdrawSet 1   Withdraw 1   WithdrawAll 1
```

One emit site each, and each inside the helper that performs the write. "Every write emits" is held
**structurally**, not by convention, so a future write path cannot silently skip the event. No action.

## D. Duplication

### D-1. Identical Context disambiguation in both deployments — ⬜ left as is

`IncomeVault` and `IncomeVaultOwnable2Step` contain a **byte-identical** 24-line block overriding
`_msgSender`, `_msgData` and `_contextSuffixLength` (verified with `diff`; ~12 code lines each).

**The reason it is not shared, which makes extraction non-actionable:** the ambiguity only exists in the
concrete contract. Each deployment inherits `ContextUpgradeable` twice — once through `IncomeVaultBase`
and once through its access-control base (`AccessControlModule` or `Ownable2StepUpgradeable`) — and
Solidity requires the override in the contract where the C3 linearization is ambiguous. A shared parent
cannot resolve a diamond that does not exist until its own child adds the second path. Moving the block
up would not compile.

## E. `virtual` convention

### E-1. Five `public` functions were not overridable — ✅ fixed

`CLAUDE.md` requires hooks to be `internal view virtual` and the codebase marks essentially every
public function `virtual`. `IncomeVaultOpen` was the exception — `claimDividend`, `claimDividendBatch`,
`validateTimeCode`, `validateTime` and `validateTimeBatch` all lacked it, while the sibling
`IncomeVaultRestricted` marked all six of its public functions `virtual`. **The inconsistency is the
evidence**: whichever is right, the two files disagreeing is a defect.

Consequence: a deployment variant could not specialise the claim entrypoint — the single most likely
place to want it (an extra restriction, a different reentrancy strategy).

Guarded by `test/mocks/IncomeVaultOverrideMock.sol`, which overrides `claimDividend` and
`validateTimeCode`. **Verified the guard guards:** removing `virtual` from `claimDividend` fails the
build with `Error (4334): Trying to override non-virtual function`. The mock also increments a counter
and calls `super`, so a silently shadowed override would be caught rather than merely compiling.

`virtual` on an internal function is resolved statically and is free; the A-1 measurements were taken
with the new `virtual` helpers in place and still show a net saving, which is the practical confirmation.

## F. ERC / specification conformance

### F-1. Interface identifiers — ⬜ recomputed, both correct

`Ownable2StepERC165Module` hardcodes two ids. Both were recomputed from the selectors rather than
trusted:

| Constant | Declared | Recomputed | |
| --- | --- | --- | --- |
| `IERC173_INTERFACE_ID` | `0x7f5828d0` | `owner()` ^ `transferOwnership(address)` = `0x7f5828d0` | ✔ |
| `IOWNABLE2STEP_INTERFACE_ID` | `0x9ab669ef` | `acceptOwnership()` ^ `pendingOwner()` = `0x9ab669ef` | ✔ |

The `type(I).interfaceId` inheritance trap does not apply: these are literals, and the comment above
each states the derivation. Hardcoding is correct here because OpenZeppelin ships no `IERC173`.

### F-2. `IERC3643Version` is not advertised — ⬜ decide

Both variants now implement `IERC3643Version` but neither answers `true` for its id in
`supportsInterface`. Purely cosmetic — no consumer is known to filter on it, and `version()` is callable
regardless. Listed rather than fixed because adding it is a public-surface change for no known consumer.

## G. Code / documentation mismatch

### G-1. The version string contradicts the changelog — ⚠️ outstanding

`src/modules/VersionModule.sol` sets `VERSION = "1.1.0"`. `CHANGELOG.md`'s release heading is `## 2.0.0`,
and the file's own policy section states:

> MAJOR version when the new version makes: incompatible proxy **storage** change […] a significant
> change in external APIs (public/external functions) or in the internal architecture

This release does all three — the ERC-7201 migration is an incompatible storage change, `initialize`
changed signature, and the architecture was split into a base plus two deployment variants. By the
project's own written rule the next version is MAJOR.

`1.1.0` was set on explicit instruction, so it is left in place; the conflict is recorded here and in
the changelog entry rather than silently resolved. One line settles it either way: change `VERSION` to
`"2.0.0"` (and `EXPECTED_VERSION` in `test/VersionModule.t.sol`), or change the heading to `## 1.1.0`.

### G-2. The release checklist points at directories that do not exist — ✅ fixed

The checklist named `./doc/coverage` and `./doc/security/audits/tools`. The actual paths are
`doc/test/coverage` and `doc/audits/tools`. Anyone following the checklist would have written output
into new empty directories beside the real ones.

### G-3. NatSpec block length — ⬜ measured, healthy

| blocks | median | p90 | max |
| --- | --- | --- | --- |
| 78 | 4 lines | 9 lines | 15 lines |

Exactly one block reaches 15 lines (the `IncomeVaultValidationModule` header, which carries a genuine
design constraint: why the vault uses the RuleEngine view path). There is no long tail and no header
that has become a document. **No action** — reported because "the comments are fine" is only credible
with the distribution attached.

### G-4. Production comment referencing a `.md` file — ⬜ left as is

One occurrence: `VersionModule.sol` says to bump `VERSION` together with the `CHANGELOG.md` entry. It
is cited by **bare filename** at the repository root, it is a maintenance instruction rather than a
warning whose substance lives elsewhere, and a reader on a block explorer loses nothing by not having
the file. Removing it would delete the one thing that ties the constant to the release process. Keep.

## H. Weird behaviour — correct but at odds with the purpose

Both findings here concern `distributeDividend`, the issuer-driven push path. Both are reachable only
with `INCOME_VAULT_DISTRIBUTE_ROLE` (or the owner, in the single-owner variant), so neither is
exploitable by an outsider — but both make the push path behave differently from the pull path in ways
that undercut the vault's stated purpose. **Both have since been fixed.**

### H-1. `distributeDividend` ignored the claim window — ✅ fixed

`claimDividend` calls `validateTime(time)`, which rejects a claim that is too early or too late.
`distributeDividend` checked **only** `segregatedClaim[time]`:

```solidity
if(!$._segregatedClaim[time]){ revert IncomeVault_ClaimNotActivated(); }
(uint256[] memory tokenHolderBalance, uint256 totalSupply) = $._snapshotEngine.snapshotInfoBatch(time, addresses);
```

**Why the missing "too early" check mattered, verified against the upstream source.**
`SnapshotBase._snapshotBalanceOf` is:

```solidity
return snapshotted ? value : ownerBalance;
```

When no snapshot value exists at `time` it falls back to the **live** balance. So a distribution before
`time` computed every payout from current balances instead of the recorded ones, and set
`claimedDividend[holder][time] = true`, permanently consuming the holder's claim for that period at the
wrong amount.

**Fix.** `distributeDividend` now applies the same three checks as the pull path:

```solidity
// Same window as a holder-driven claim: the claims must be open, `time` must have passed so the
// snapshot is recorded, and the withdraw limit must not have expired.
_revertOnInvalidTime(_timeCode($, time, $._timeLimitToWithdraw));
```

> **⚠️ Correction to this report.** The original text said *"the fix is one line — call
> `validateTime(time)` instead of the bare `segregatedClaim` check"*. **That was wrong.**
> `validateTime` is declared in `IncomeVaultOpen`, which is a **sibling** of `IncomeVaultRestricted`
> (both inherit `IncomeVaultValidationModule` and `IncomeVaultInternal`; neither inherits the other), so
> `distributeDividend` cannot call it. The real fix moved the enum `TIME_ERROR_CODE` and the internal
> helpers `_timeCode` / `_revertOnInvalidTime` down into the shared parent `IncomeVaultInternal`, where
> both paths can reach them. The public surface of `IncomeVaultOpen` is unchanged — `validateTime`,
> `validateTimeCode` and `validateTimeBatch` stay exactly where they were — and no logic was duplicated,
> which inlining the three checks into `IncomeVaultRestricted` would have done.

**Tests, written before the fix and confirmed to fail against the old code**
(`next call did not revert as expected`, 3 failures):

| Test | Asserts |
| --- | --- |
| `testCannotDistributeBeforeTheDividendTime` | reverts `TooEarlyToWithdraw`; nothing paid, claim still available |
| `testCannotDistributeAfterTheWithdrawLimit` | reverts `TooLateToWithdraw` |
| `testCannotDistributeWhenTheClaimIsNotActivated` | still reverts `ClaimNotActivated` |
| `testDistributeInsideTheWindowStillWorks` | inside the window the payout is unchanged |
| `testPushAndPullAgreeOnTheWindow` | push and pull reject with the **same** error at the same instant |

The "too late" bound came along with the fix. That is coherent: after the withdraw limit the funds are
meant to return to the issuer through `withdraw`, so a push at that point would contradict the limit.
An issuer who wants to pay later extends `timeLimitToWithdraw` rather than bypassing it.

### H-2. `distributeDividend` bypassed the ValidationModule — ✅ fixed

`claimDividend` and `claimDividendBatch` both called `_validateTransfer(...)` — pause, address freeze,
and the RuleEngine. `distributeDividend` called `_transferDividend` directly and performed none of them.

The vault failed **closed** on the pull path and **open** on the push path. A holder who was frozen, or
whom the RuleEngine's allow-list rejected, could not claim — but could be paid. Pausing the vault did
not stop a distribution either. Since the RuleEngine integration exists precisely to enforce transfer
compliance on payouts, a privileged path that skipped it removed the property the module is there to
provide.

**Fix.** The same check the claim paths use, inside the loop, before the transfer:

```solidity
// Same transfer restriction as a holder-driven claim: pause, freeze and RuleEngine.
_validateTransfer(address(this), addresses[i], tokenHolderDividend[i]);
_transferDividend(time, addresses[i], tokenHolderDividend[i]);
```

**The design decision worth recording: one blocked holder reverts the whole distribution**, rather than
being skipped. Skipping was the alternative and it is worse — `distributeDividend` would return
successfully having quietly not paid part of the list, and the operator would have no signal. Reverting
matches `claimDividendBatch`, and `IncomeVault_InvalidTransfer(from, to, value)` names the offending
address so it can be removed from the list and the call retried. The cost is that a single
non-compliant address in a large batch blocks the batch, which is the correct trade for a compliance
control.

**Tests, written before the fix and confirmed to fail against the old code** (four failures, all
`next call did not revert as expected`):

| Test | Asserts |
| --- | --- |
| `testCannotDistributeToAFrozenHolder` | reverts; nothing paid, claim not consumed |
| `testCannotDistributeWhilePaused` | pause now stops the push path |
| `testOneBlockedHolderRevertsTheWholeDistribution` | the allowed holder is rolled back too, error names the blocked one |
| `testDistributeStillWorksWhenEveryHolderIsAllowed` | the normal payout is unchanged |
| `testCannotDistributeToANonWhitelistedHolder` (RuleEngine suite) | the compliance case that motivated the finding |
| `testCanDistributeWhenBothAddressesWhitelisted` | still works once whitelisted |

Note the pause and freeze slots are now read once per holder rather than once per call. That is
consistent with `claimDividendBatch`, which does the same, and was not optimised: correctness of the
control comes first, and a per-holder read is what makes a mid-batch state change impossible to miss.

### H-3. The vault checks whether it has frozen itself — ⬜ keep, with a correction

`_validateTransfer(address(this), holder, amount)` reaches, inside `canTransfer`:

```solidity
if(EnforcementModule.isFrozen(from) || EnforcementModule.isFrozen(to)){
    return false;
}
```

`from` is **always the vault** — every call site passes `address(this)` — so the `from` half asks
whether the vault has frozen *itself*. `EnforcementModule.setAddressFrozen` (inherited from CMTAT)
accepts any address with no exclusion for `address(this)`, so `ENFORCER_ROLE` can freeze the vault.

> **⚠️ Correction to this report.** The original entry said removing the check would cost "no gas worth
> measuring". **That was an estimate and it was wrong.** Toggled in place and measured on
> `claimDividend`: **70,688 gas with the check, 68,426 without — 2,262 gas, 3.2% of a claim.** It is a
> *cold* `SLOAD`: the vault's own frozen slot is touched nowhere else in a payout, so it never gets
> warmed. The verdict below is unchanged, but it is now a trade with a real price rather than a free one.

#### What it does today, verified

Each of these was confirmed with a temporary test, not reasoned about:

| Behaviour | Result |
| --- | --- |
| Freeze the vault, then `claimDividend` | reverts `IncomeVault_InvalidTransfer` |
| Freeze the vault, then `distributeDividend` | reverts (since the H-2 fix, the push path checks too) |
| `paused()` while the vault is frozen | **`false`** |
| `deposit` while the vault is frozen | **succeeds** |
| `withdrawAll` while the vault is frozen | **succeeds — the vault can be fully drained** |

#### The risk as it stands

Three consequences follow, and the second is the one that would surprise an operator:

1. **A second global kill-switch, held by a different role.** `ENFORCER_ROLE` — intended for freezing
   *holders* — can halt every payout by freezing one address, without holding `PAUSER_ROLE`. Whether
   that is separation of duties or an unintended capability depends on how the roles are staffed. It is
   not documented anywhere as a way to stop the vault.
2. **It is invisible to anything watching the pause flag.** `paused()` stays `false`, so a monitor
   polling the pause state sees a healthy vault while every claim reverts. And the revert is the generic
   `IncomeVault_InvalidTransfer(vault, holder, amount)` — **identical to the error a blocked holder
   gets**. A support desk cannot tell "you are on a sanction list" from "the vault itself is halted"
   without reading the `AddressFrozen` logs and noticing the address is the vault. This is the concrete
   operational cost of leaving it as is.
3. **It protects nobody's funds.** Freezing the vault stops holders being paid; it does **not** stop
   `deposit`, and it does **not** stop `INCOME_VAULT_WITHDRAW_ROLE` draining the contract with
   `withdrawAll`. It is a payout switch, not a safe mode. Anyone reaching for it as an emergency
   measure should know that.

#### Why it is kept

**The decisive argument is what removal would do, not what the check buys.** `setAddressFrozen` comes
from the inherited CMTAT `EnforcementModule` and cannot be un-inherited. Drop the `from` half and
freezing the vault becomes a **silent no-op that looks like it worked**: the call succeeds, an
`AddressFrozen` event is emitted, `isFrozen(vault)` returns `true` — and payouts continue. An enforcer
would believe they had stopped the vault. A check that is redundant is a much smaller problem than a
control that reports success and does nothing.

Two secondary reasons:

- **Symmetry with `to`, and with CMTAT semantics.** In the CMTAT a frozen address is blocked as sender
  *and* receiver. Checking only `to` would make the vault's rule differ from the token's for no stated
  reason.
- **It composes with the RuleEngine.** `canTransfer(vault, holder, value)` is also handed to the engine
  with the vault as `from`, so a rule that allow-lists senders already treats the vault as a
  participant. Removing the local `from` check while the engine still sees `from` would leave the two
  layers disagreeing about whether the vault is a party to the transfer.

#### What could be implemented instead

| Option | Effect | Verdict |
| --- | --- | --- |
| **A. Keep, and document it** | The capability is stated in the spec so an operator knows the lever exists and what it does not cover | **recommended, and done** — `doc/README.md` now describes it |
| **B. Distinguishable error** | Revert `IncomeVault_VaultFrozen()` when `from` is the vault, instead of the generic `IncomeVault_InvalidTransfer`. Closes risk 2 at the cost of one comparison on the failure path only | **worth doing if operators will run a support desk**; not done, no runtime behaviour depends on it |
| **C. Reject freezing the vault** | Override `setAddressFrozen` to revert on `address(this)`. Removes the ambiguity entirely — but also removes the enforcer's lever, and overriding an inherited control to forbid something is a bigger statement than it looks | not recommended |
| **D. Remove the `from` check** | Saves the measured 2,262 gas per claim, and creates the silent no-op described above | **do not** |

The 2,262 gas is the price of option A over option D. That is the trade to weigh: ~3% of a claim, paid
by every holder, to keep an enforcement control honest.

### H-4. `withdrawAll` leaves the per-time accounting stale — ⬜ already documented

`withdrawAll` moves tokens without decrementing any `segregatedDividend[time]`, so after it the
per-time buckets no longer sum to the vault balance. This is already stated in `doc/README.md` ("can
lead to an 'unstable' state […] to be used only in case of emergency or if the vault is closed").
Behaviour and documentation agree; no finding. The new `WithdrawAll` event (C-4) makes it observable.

## I. Interface granularity

### I-1. The vault required 8 interface functions and called 3 — ✅ fixed

`ISnapshotState` declares **8** functions. The vault calls **3**:

| Declared | Used by the vault |
| --- | --- |
| `snapshotInfo(uint256,address)` | ✔ `claimDividend` |
| `snapshotInfoBatch(uint256[],address[])` | ✔ `claimDividendBatch` |
| `snapshotInfoBatch(uint256,address[])` | ✔ `distributeDividend` |
| `snapshotExists`, `snapshotBalanceOf`, `snapshotBalanceOfExact`, `snapshotTotalSupply`, `snapshotTotalSupplyExact` | ✘ |

**Fix.** `src/interfaces/ISnapshotSource.sol` declares exactly the three, with signatures copied
verbatim from `ISnapshotState`, and the vault is typed against it throughout.

**Be precise about what moved**, because "nothing changed" would be sloppy:

| | |
| --- | --- |
| Storage layout | **identical** — both variants, verified from `--extra-output storageLayout` (`[]`, all state is ERC-7201) |
| ABI | **identical** — 194 entries for `IncomeVault`, 184 for `IncomeVaultOwnable2Step`, diffed before/after |
| `SnapshotEngineSet` topic | **unchanged** — the event is `SnapshotEngineSet(address)` either way |
| Solidity types | **changed** — `initialize`, `snapshotEngine()` and `_setSnapshotEngine` now name `ISnapshotSource` |
| Callers | must cast: `ISnapshotSource(address(engine))`, since Solidity has no implicit conversion between unrelated interfaces |

**No ERC-165 guard was added, deliberately.** This is the step most often got wrong: every existing
implementer would have to advertise the new id, and the canonical `SnapshotEngine` declares no
`supportsInterface` of its own — a guard would reject the implementation the vault is built for, which
is a self-inflicted outage rather than a fix. The report's own warning applied to the report's own
recommendation.

**And the limit, restated so the change is not read as more than it is.** ERC-165 expresses shape,
never semantics, and this change adds no runtime check at all. A snapshot source returning
attacker-chosen balances satisfies `ISnapshotSource` exactly as an honest one does. What was bought is
documentation and least-privilege value: a third-party provider now writes three functions instead of
five stubs it will never see called. Trusting the source remains configuration discipline.

**Tests.**

| Test | Asserts |
| --- | --- |
| `testAThreeFunctionSourceIsAccepted` | `MinimalSnapshotSourceMock` implements *only* the three; the vault initializes against it and a claim pays 100/400 of the deposit |
| `testTheRealSnapshotEngineStillSatisfiesIt` | the real `ISnapshotState` engine still works through the narrower type — the compatibility half |

The mock is the evidence: it compiles and the vault works against it, so the other five were never
required.

---

## Notes on this review

- Every gas figure was measured with a temporary harness (own contract, warm-up call, `gasleft()`
  deltas, same harness toggled in place), which has been **deleted**. Test count went 79 → 85: the six
  additions are the `CodeQuality.t.sol` regressions plus the override mock, and no benchmark is left
  behind.
- Each event fix was validated by removing the `emit` and confirming the matching test fails
  (`ClaimStatusSet`, `ERC20TokenPaymentSet` and `Withdraw` were each sabotaged in turn; each failed only
  its own test). The `virtual` fix was validated by removing the keyword and confirming the build breaks.
- The style checker reports two `[missing-param]` / `[missing-return]` hits for the parameter named `$`.
  Both are **false positives** in the checker, which parses return variables with a pattern including
  `$` but extracts tag names with `(\w+)`, which excludes it. `$` is the OpenZeppelin/CMTAT convention
  for the ERC-7201 accessor and is kept.
- What was reasoned about rather than executed: nothing load-bearing. H-1's fallback behaviour was
  confirmed by reading `SnapshotBase._snapshotBalanceOf` in the vendored dependency **and** by the
  characterisation test; D-1's "cannot be hoisted" claim follows from C3 linearization and was not
  attempted as a build.
