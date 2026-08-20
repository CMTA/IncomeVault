# IncomeVault — Modularity Assessment

Working document, produced with Claude Code on 2026-08-19 against branch `update`.

Modularity is judged here on the two things it is for:

1. **Legibility** — can you tell from a file's path and name what it is (interface, abstract mixin,
   deployable contract, library) and what it does?
2. **Reusability** — can someone build a *different* project on top of this one: a different access
   control, or one of the capabilities on its own?

The concrete test used throughout is the one that matters most for this codebase: **could the dividend
distribution be embedded directly inside a CMTAT that already has a snapshot engine**, instead of
sitting in a separate vault?

**The answer today is no, and not for a reason a determined integrator can work around.** That is the
headline finding; everything else is smaller.

---

## Summary

| ID | Finding | Severity for reuse |
| --- | --- | --- |
| M-1 | The distribution core hard-inherits CMTAT's `PauseModule` and `EnforcementModule` — C3 linearization becomes impossible against any CMTAT | ✅ **fixed** |
| M-2 | `snapshotEngine()` collides with CMTAT's, with a *different return type* — irreconcilable | ✅ **fixed** |
| M-3 | `version()` collides with CMTAT's `VersionModule` | ✅ **resolved by design** — host overrides |
| M-3b | SnapshotEngine vendors its **own** CMTAT at a different version than `lib/CMTAT` | medium — **proven to block**, see below |
| M-4 | `_authorizeRuleEngineManagement()` is declared by both this project and CMTAT | ❌ **not a defect** — one slot, one capability |
| M-5 | `libraries/` contains no libraries; `public/` groups by visibility rather than capability | medium (legibility) |
| M-6 | One monolithic storage namespace covering four unrelated concerns | ✅ **fixed** — operator split out; the rest is one concern |
| M-7 | No interface describes the vault's own API | ✅ **fixed** |
| M-8 | `IncomeVaultBase` bundles ERC-2771, which a host already has | low |
| M-9 | Split `IncomeVaultValidationModule` so an embedded copy reuses CMTAT's RuleEngine | ❌ **already the case** — shared constant slot |

## What is already good

A fair assessment has to start here, because several parts are done well and should not be disturbed
by the changes below.

- **The authorization-hook pattern is exemplary.** Eight `internal view virtual` hooks, no policy in
  the logic contracts, two deployable variants (`IncomeVault`, `IncomeVaultOwnable2Step`) that differ
  *only* in how they answer them. This is precisely the "different access control on top" case working,
  and it is proof the team already knows the technique the rest of this document asks for.
- **`ISnapshotSource`** narrows an eight-function dependency to the three actually called. That is
  textbook decoupling: a third-party snapshot provider implements three functions, not eight.
- **`ERC7741Module` owns its own ERC-7201 namespace.** It is the one module whose state travels with
  it, which is exactly what M-6 asks for everywhere else.
- **Interfaces are separated** into `interfaces/`, and the two standard ones are declared verbatim with
  their identifiers asserted against the specification.

---

## The test, run

Not reasoned about — attempted, with the compiler as the judge:

```solidity
contract CMTATWithDividend is CMTATStandaloneSnapshot, IncomeVaultOpen, IncomeVaultRestricted {}
```

```
Error (5005): Linearization of inheritance graph impossible
```

Reversing the order gives the same. Probing one layer at a time against `CMTATStandaloneSnapshot`:

| Mixed in | Compiler says |
| --- | --- |
| `IncomeVaultInternal` | `must override "snapshotEngine"` — two bases define it |
| `ERC7741Module` | `must override "_contextSuffixLength"` |
| `IncomeVaultValidationModule` | `must override "_authorizeRuleEngineManagement"` |
| `VersionModule` | `must override "version"` |
| `IncomeVaultOpen` | **linearization impossible** |
| `IncomeVaultRestricted` | **linearization impossible** |

The distinction matters. `Error (6480)` ("must override") is an inconvenience — the integrator writes
an override and moves on. `Error (5005)` is a wall: no override, no ordering, no amount of glue code
fixes an impossible linearization. The only remedies are to change *this* codebase or to fork it.

---

## M-1. The distribution core hard-inherits CMTAT's pause and enforcement — ✅ **fixed**

`IncomeVaultValidationModule` is declared:

```solidity
abstract contract IncomeVaultValidationModule is
    PauseModule,          // CMTAT
    EnforcementModule,    // CMTAT
    ValidationModuleRuleEngineInternal,
    IncomeVaultInvariantStorage
```

and both `IncomeVaultOpen` and `IncomeVaultRestricted` inherit it. A CMTAT inherits the same two
modules through its own chain, in a different order. C3 linearization requires one consistent ordering
of shared bases across the whole graph, and there is none — hence `Error (5005)` for *either*
`IncomeVaultOpen` or `IncomeVaultRestricted` on their own.

**The irony is that this project already solved this problem once, for access control.** The vault does
not inherit a role system and hard-code `onlyRole`; it declares `_authorizeDeposit()` and lets the
deployment answer. Validation is the same shape of question — *may this payout proceed?* — and was
given the opposite treatment.

### Proposed change

Make validation a hook rather than an inheritance:

```solidity
// core: declares WHAT it needs, inherits nothing
abstract contract IncomeVaultDistribution is IncomeVaultStorage {
    /// @dev reverts if the payout is not allowed. The host decides what "allowed" means.
    function _validateTransfer(address from, address to, uint256 value) internal view virtual;
}

// the standalone vault answers it with CMTAT modules — today's behaviour, unchanged
abstract contract IncomeVaultValidationModule is PauseModule, EnforcementModule, ... {
    function _validateTransfer(...) internal view virtual override { ...pause, freeze, RuleEngine... }
}

// a CMTAT host answers it from the modules it already has
contract CMTATWithDividend is CMTATStandaloneSnapshot, IncomeVaultDistribution {
    function _validateTransfer(address from, address to, uint256 value) internal view virtual override {
        require(canTransfer(from, to, value), ...);   // the token's own ValidationModule
    }
}
```

`_validateTransfer` **already exists** with exactly this signature; it is merely implemented in the
same file that inherits CMTAT. Splitting those two responsibilities into two files is most of the work.

**Implemented**, and the coupling turned out to be even thinner than described: grepping every member
the payout paths used from the validation module returned **exactly one**, `_validateTransfer`. The
whole CMTAT inheritance was being dragged in for a single hook.

What changed:

- New `src/modules/IncomeVaultValidationCore.sol` — the question alone, inheriting **nothing**.
- `IncomeVaultOpen` and `IncomeVaultRestricted` now inherit the core instead of the CMTAT-based module.
- `IncomeVaultValidationModule` inherits the core and `override`s `_validateTransfer`; it is now one
  *answer*, not a base of the payout paths.
- The answer moved out of `IncomeVaultBase` and into the two **deployment** contracts, beside the
  access-control base they already choose. `IncomeVaultBase` therefore no longer knows about pause,
  freeze or the RuleEngine at all — `ruleEngine_` left its initializer, which now takes three arguments
  instead of four.

**Fixing it exposed a second blocker of the same class, which the assessment had missed** because the
probe stopped at the first error. With the validation coupling gone, the mix still failed 5005 on
`ReentrancyGuardTransient`: `CMTATStandaloneSnapshot` lists it **last** (most derived) while
`IncomeVaultOpen`/`IncomeVaultRestricted` listed it **first** (most base), and C3 cannot hold both.
Reordering ours to match CMTAT's convention cleared it. Storage layout is unaffected — every contract
still declares zero sequential slots — because the guard uses transient storage at a fixed slot.

### Result

```
CMTATStandaloneSnapshot + IncomeVaultOpen + IncomeVaultRestricted
  before:  Error (5005) linearization impossible          <- a wall
  after:   Error (6480) must override _msgSender, _msgData,
                        _contextSuffixLength, snapshotEngine   <- ordinary overrides, plus M-2
```

Every remaining error was the kind an integrator resolves with an override, except `snapshotEngine`,
which was **M-2** — since fixed, so the mix now compiles outright.

`test/mocks/EmbeddedDividendHostMock.sol` is the regression guard: a host that is *not* a CMTAT,
embedding both payout paths and answering `_validateTransfer` and the four authorization hooks itself.
It only has to compile — re-couple the payout paths to a concrete validation stack and it stops.

Effort: moderate. Risk: low — the standalone vault keeps today's implementation verbatim, and all 202
existing tests pass unchanged.

## M-2. `snapshotEngine()` cannot coexist with CMTAT's — ✅ **fixed**

```solidity
// this project
function snapshotEngine() public view returns (ISnapshotSource);
// CMTAT ISnapshotEngineModule
function snapshotEngine() external view returns (ISnapshotEngine);
```

Same name, same (empty) parameters, **different return type**. Solidity requires an overriding function
to keep the return types, so these two cannot be reconciled by any override: a contract inheriting both
is simply not compilable.

This is the single most damaging collision for the scenario in question, because a CMTAT with a
snapshot engine is *precisely* the host that already has a function by that name.

### Proposed change

Two steps, and the second is the valuable one:

1. **Rename the getter** to something that cannot collide — `dividendSnapshotSource()`.
2. **Make the source a hook, not a stored address.** The vault reads three functions; declare them as
   internal hooks and let the host decide where the answer comes from:

   ```solidity
   function _snapshotInfo(uint256 time, address holder)
       internal view virtual returns (uint256 balance, uint256 totalSupply);
   ```

   The standalone vault implements it by calling the stored `ISnapshotSource`. A CMTAT-with-snapshots
   implements it by calling **itself**. The distribution logic stops caring whether the snapshot lives
   in another contract, which is the whole point of the exercise.

Note this subsumes the current `ISnapshotSource` indirection rather than replacing it: the interface
stays, as the type of the stored reference in the standalone deployment.

### What was implemented

Both steps, as proposed.

`src/modules/IncomeVaultSnapshotCore.sol` declares the three hooks and inherits nothing.
`src/modules/IncomeVaultSnapshotModule.sol` is the standalone answer: an `ISnapshotSource` held in its
own ERC-7201 namespace `IncomeVault.storage.SnapshotSource`, so a host answering the hooks from itself
never allocates the slot. The source therefore left `IncomeVault.storage.IncomeVaultInternal`, shifting
every remaining field of that struct down one slot — a pre-release storage break, and the reason this
had to happen before a deployment rather than after.

Renamed, all pre-release and all external:

| Before | After |
| --- | --- |
| `snapshotEngine()` | `dividendSnapshotSource()` |
| `setSnapshotEngine` | `setDividendSnapshotSource` |
| `_setSnapshotEngine` | `_setDividendSnapshotSource` |
| `_authorizeSnapshotEngineManagement` | `_authorizeSnapshotSourceManagement` |
| `event SnapshotEngineSet(ISnapshotSource)` | `event DividendSnapshotSourceSet(ISnapshotSource indexed)` |
| `IncomeVault_SnapshotEngineWithAddressZeroNotAllowed` | `IncomeVault_SnapshotSourceWithAddressZeroNotAllowed` |

`initialize` is unchanged, and the claim-period gate on the setter is unchanged.

**The regression guard is `test/mocks/CMTATDividendHostMock.sol`** — a `CMTATUpgradeableInternalSnapshot`
inheriting `IncomeVaultOpen` and `IncomeVaultRestricted`, answering `_validateTransfer` from the CMTAT's
own `canTransfer` and the three snapshot hooks from the CMTAT's own snapshot records. It compiles. That
is the scenario this whole document was written against, and it now works: before M-1 it failed with
`Error (5005)`, and after M-1 it still failed on the `snapshotEngine()` return-type collision.

204 tests pass.

## M-3. `version()` collides with CMTAT's — low, **resolved by design**

`src/modules/VersionModule.sol` and CMTAT's `VersionModule` both declare
`version() returns (string memory)` behind `IERC3643Version`. Any host that is a CMTAT already has one.

The original grade of *high* was wrong on two counts, both established by probe rather than by reading.

**It is not a wall, unlike M-2.** Forcing the collision gives:

```
Error (6480): Derived contract must override function "version".
              Two or more base classes define function with same name and parameter types.
```

The two declarations are byte-identical — same name, same (empty) parameters, **same return type** —
so an override is legal and resolves it. That is the whole difference from M-2, where the return types
differed and no override could reconcile them. `6480` is the ordinary integrator's chore; `5005` and a
return-type conflict are walls.

**It is not reachable today.** `VersionModule` is inherited only by `IncomeVaultBase`, which an embedded
host never inherits — `IncomeVaultOpen` and `IncomeVaultRestricted` do not mention it.
`test/mocks/CMTATDividendHostMock.sol` compiles with no `version()` work at all. The finding assumed the
module travelled with the payout paths; it does not.

### Decision: keep it, and let the host override

`VersionModule` stays where it is. A host that is already a CMTAT overrides `version()` and decides what
to report.

**The rationale is positive, not merely tolerant.** Keeping the module inherited means the *IncomeVault
library version is recorded in the host's own source*. A reader of a deployed
`CMTATWithDividend` can see which release of this library was embedded, which is exactly what they need
when a finding is filed against a particular version. Moving the module into the deployable contracts —
the original proposal — would erase that: an embedded host would carry the distribution logic with no
statement anywhere of which version of it.

A host wanting to report both can do so explicitly:

```solidity
function version() public view virtual override(...) returns (string memory) {
    return string.concat(CMTATVersionModule.version(), "+incomevault-", IVVersionModule.version());
}
```

### The one wart: both contracts are named `VersionModule`

The override list cannot name them, because the name is ambiguous in the host's scope:

```solidity
override(VersionModule, VersionModule)   // impossible
```

The host must alias **both** imports:

```solidity
import {VersionModule as CMTATVersionModule} from ".../CMTAT/.../wrapper/core/VersionModule.sol";
import {VersionModule as IVVersionModule}    from ".../src/modules/VersionModule.sol";

contract CMTATWithDividend is CMTATUpgradeableInternalSnapshot, IVVersionModule {
    function version()
        public view virtual override(CMTATVersionModule, IVVersionModule) returns (string memory)
    {
        return IVVersionModule.version();
    }
}
```

Verified: this compiles.

The footgun is the **diagnostic**, not the fix. Solc prints `Definition in "VersionModule":` twice and
names no path, so a host author has nothing to tell them what to alias. **Document this recipe in
`doc/README.md`** — that is the whole remaining cost of the decision. Renaming ours to
`IncomeVaultVersionModule` would also remove it, and remains available if the alias dance proves to
annoy integrators in practice.

### M-3b. SnapshotEngine vendors its own CMTAT, at a different version

Turned up while probing the above, and it matters more than M-3 itself.

| Path | Version |
| --- | --- |
| `lib/CMTAT` — used by this project's modules | `v3.3.0-rc3` |
| `lib/SnapshotEngine/CMTAT` — used by `CMTATUpgradeableInternalSnapshot` | `v3.3.0-**rc1**` |

SnapshotEngine's contracts import their CMTAT by **relative path** into a nested submodule, so a host
built on `CMTATUpgradeableInternalSnapshot` links a *different* CMTAT than the vault's own modules do.
The first alias attempt above failed for exactly this reason: `CMTAT/modules/wrapper/core/VersionModule.sol`
resolves to a contract that is not in the host's linearization at all.

It does not bite today **only because M-1 removed every CMTAT module from the payout paths**, so the two
copies never meet in one C3 linearization. Anything that re-couples them would produce duplicate-base
conflicts that look like M-3 but are not fixable by an override — the two `VersionModule`s would be
genuinely distinct contracts, not two names for one.

**It is not theoretical — upgraded to medium after probing M-4.** Composing
`CMTATUpgradeableInternalSnapshot` (SnapshotEngine's CMTAT) with `IncomeVaultValidationModule` (our
CMTAT) fails immediately with nine `Error (9097): Identifier already declared` plus a duplicate-event
error, every one of them pointing at a `lib/SnapshotEngine/CMTAT/...` path shadowing its `lib/CMTAT/...`
twin — `PauseModule`, `EnforcementModule`, `EnforcementModuleInternal`,
`ValidationModuleRuleEngineInternal`. No override resolves a duplicate *base contract*.

The practical blast radius stays small **only** because `IncomeVaultValidationModule` is the project's
sole CMTAT-derived module and M-1 removed it from the embeddable path. Any future module built on CMTAT
inherits this problem.

**Action:** before embedding for real, either align SnapshotEngine's nested CMTAT with `lib/CMTAT`, or
remap `SnapshotEngine/`'s CMTAT imports onto the top-level submodule so the build has exactly one CMTAT.
Until then, treat "our CMTAT-derived modules" and "SnapshotEngine's CMTAT contracts" as mutually
exclusive in one linearization.

## M-4. `_authorizeRuleEngineManagement()` is declared twice — ❌ **not a defect, closed**

This project declares it in `IncomeVaultValidationModule`; CMTAT declares it in
`ValidationModuleRuleEngine`. The original write-up called this a collision and proposed prefixing ours
to `_authorizeIncomeVaultRuleEngine()`.

**That was implemented, then reverted, because the premise is wrong.**

### The premise, checked

The finding assumed two hooks meant two capabilities. They do not. Both
`ValidationModuleRuleEngine` (CMTAT's wrapper) and `IncomeVaultValidationModule` (ours) inherit the
**same** `ValidationModuleRuleEngineInternal`, and that base holds the RuleEngine at a **hardcoded
ERC-7201 slot**:

```solidity
bytes32 private constant ValidationModuleRuleEngineStorageLocation =
    0x77c8cc897d160e7bf5b10921804e357da17ae27460d4a6b5d9b27ffddf159d00;
```

Our module declares no RuleEngine storage of its own and reads through the inherited `ruleEngine()`.
Because the slot is a constant rather than a derived offset, a contract inheriting both has exactly
**one** RuleEngine — this holds regardless of how C3 linearizes the bases.

So: **one piece of state, one capability, one hook.** The two declarations are two names for the same
question, and the single override the compiler demands is the *correct* answer, not a silent accident.

### Why the prefix was actively worse

Renaming ours produced two hooks over one slot. A composed contract would then have to answer both, and
could answer them **differently** — CMTAT's gated by one role, ours by another. Since either path writes
the same slot, that is two doors to one door's worth of state, and the weaker policy wins. The rename
converted a non-problem into a real one.

The earlier claim that "one `onlyRole(...)` gates two distinct capabilities" was the error: the
capabilities are not distinct. The mutability difference is likewise harmless — CMTAT declares the hook
non-`view` and ours `view`, so a single `view` override tightens CMTAT's, which is legal and safe.

### What actually remains, and why it is fine

Composing the two still reports:

```
Error (6480): ... "setRuleEngine".
Error (6480): ... "canTransfer".
```

Both are ordinary and correct. `IncomeVaultValidationModule` deliberately does **not** inherit CMTAT's
wrapper, because that wrapper also brings `ValidationModuleAllowance` and the stateful
`transferred` / `_callRuleEngineTransferred` path — and the vault must never call `transferred()`: it is
not a bound token, so the call would revert, and a payout must not mutate stateful rules. Ours is a
deliberately narrower, read-only wrapper over the shared base. Two wrappers over one slot means the
integrator picks one implementation with a **visible body**, which is exactly the decision they should
be making.

### Outcome

No code change. The reasoning is recorded at the hook's declaration in
`src/modules/IncomeVaultValidationModule.sol`, in `doc/README.md` under the capability table, and in
`CLAUDE.md`/`AGENTS.md`, in each case stating that the shared name is deliberate and must not be
"tidied" into a prefix. This entry exists so the proposal is not re-opened.

## M-9. Should `IncomeVaultValidationModule` be split so a CMTAT reuses its own RuleEngine? — ❌ **no, already the case**

Proposed during review: separate the module so that, when embedded in a CMTAT, it uses the RuleEngine
the token already has rather than configuring its own.

**The goal is already met, by construction.** `IncomeVaultValidationModule` declares no RuleEngine
storage; it inherits CMTAT's `ValidationModuleRuleEngineInternal`, whose slot is a hardcoded constant
(see M-4). An embedded copy therefore reads and writes *the token's* `_ruleEngine`. There is nothing to
wire.

**A split would not reduce the host's work.** A CMTAT inheriting the module needs four ceremonial
overrides — `_authorizeRuleEngineManagement`, `onlyRuleEngineManager`, `setRuleEngine`, `canTransfer` —
each resolving to CMTAT's own version. The supported route, established by M-1, is instead to answer
{IncomeVaultValidationCore} directly:

```solidity
function _validateTransfer(address from, address to, uint256 value) internal view override {
    require(canTransfer(from, to, value), ...);   // CMTATDividendHostMock, in full
}
```

One function, using the token's own pause, freeze and RuleEngine. Any extracted module would still leave
the host implementing one function, so the split adds a file and removes nothing.

### What the proposal did surface: an initializer hazard

`__IncomeVaultValidation_init_unchained` writes that shared slot via CMTAT's
`__ValidationRuleEngine_init_unchained`, which guards **only** the zero address:

```solidity
if (address(ruleEngine_) != address(0)) { _setRuleEngine(ruleEngine_); }
```

So a host that inherited the module and passed a non-zero engine would silently replace the *token's*
compliance engine from the *dividend* initializer — a payout-configuration call reaching into transfer
rules. Not reachable today: only `IncomeVault` and `IncomeVaultOwnable2Step` call it, and neither is a
CMTAT. Documented at the initializer in `src/modules/IncomeVaultValidationModule.sol` so it stays that
way, with the instruction that such a host must pass the zero address.

## M-5. The directory names misdescribe the contents — medium

| Path | Contains | Problem |
| --- | --- | --- |
| `libraries/` | 4 **abstract contracts**, no `library` | The name promises stateless helpers; it holds the storage layout, the role constants and an ERC-165 module |
| `public/` | 2 abstract contracts | Groups by *visibility*, not capability. "Where is the claiming logic?" is not answered by "public" |
| `modules/` | 3 abstract contracts | Correct, but `Ownable2StepERC165Module` — a module by name — sits in `libraries/` instead |
| root | 3 contracts, one abstract and two deployable | The deployable and the abstract sit side by side |

A reader opening `libraries/IncomeVaultInternal.sol` expecting a helper library finds the ERC-7201
storage struct and the core payout routine.

**Proposed change**, following the convention CMTAT itself uses (`contracts/deployment`,
`contracts/modules`, `contracts/interfaces`, `contracts/library`):

```
src/
├── deployment/        IncomeVault.sol, IncomeVaultOwnable2Step.sol      (deployable)
├── modules/           the abstract mixins, one per capability
│   ├── IncomeVaultDistributionModule.sol    deposit / claim / distribute
│   ├── IncomeVaultValidationModule.sol      the CMTAT-based validation answer
│   ├── ERC7741Module.sol
│   └── Ownable2StepERC165Module.sol         (moved from libraries/)
├── interfaces/        unchanged
└── libraries/         actual libraries only — or removed if none
```

Nothing about this is cosmetic: the current `public/` split is what makes "can I take just the claiming
logic?" hard to answer, because claiming and its restricted counterpart are separated by *who may call
them* rather than by what they do.

## M-6. One storage namespace for four concerns — ✅ **fixed, partially and deliberately**

`IncomeVaultInternalStorage` held the snapshot source, the payment token, the claim bookkeeping, the
withdraw limit, the open-period counter, the paid-per-period totals **and** the operator mapping.

### What was implemented, and what was declined

The finding proposed splitting into `Distribution` and `Operator`. Re-read against the current code, it
was two-thirds already done and one-third not worth doing:

| Concern | Outcome |
| --- | --- |
| Snapshot source | Already moved to `IncomeVault.storage.SnapshotSource` by **M-2** |
| Signature nonces | Already in `ERC7741Module`'s own namespace before this review |
| Claim delegation | **Moved** to `IncomeVault.storage.Operator`, in a new `IncomeVaultOperatorModule` |
| Payment token, deposits, claim flags, paid totals, open count, claim window | **Left together** — see below |

**The remaining struct was not split further, on purpose.** Those six fields are not four concerns;
they are one. `_paidDividend` is meaningless without `_segregatedDividend`, `_openClaimCount` is
bookkeeping derived from `_segregatedClaim`, and `_ERC20TokenPayment` and `_timeLimitToWithdraw` are the
configuration of that same distribution. Splitting them would be a namespace per variable — more
constants, more accessors, more indirection, and no capability boundary to show for it. That is worse
code, not better modularity, so the finding is closed with the split it justified rather than the split
it named.

### Why the operator half was worth doing

Not for the reason the finding gave. Claim delegation is **not** separable in practice —
`claimDividendFor` needs it, so a host embedding the payout paths gets it regardless. The real
justifications are different and stronger:

- **It was the codebase's only incoherence of its kind.** Every other capability already owned one
  module and one namespace (`IncomeVaultSnapshotModule`, `IncomeVaultValidationModule`,
  `ERC7741Module`). Claim delegation had its behaviour spread across three files — the mapping and
  `isOperator`/`_setOperator` in `IncomeVaultInternal`, the public `setOperator` and
  `_requireHolderOrOperator` in `IncomeVaultOpen`, the signed variant in `ERC7741Module` — and its state
  in **two** namespaces, one of them the catch-all.
- **It is the last chance.** ERC-7201 slots are fixed at deployment; this is impossible afterwards.

`IncomeVaultOperatorModule` now holds the mapping, `setOperator`, `isOperator`, `_setOperator` and
`_requireHolderOrOperator`. `ERC7741Module` builds the signed variant on top of it. The external ABI is
unchanged, and `_isOperator` was the **last** struct field, so no other field's offset moved.

`test/IncomeVaultStorage.t.sol` re-derives all three hardcoded slots from their namespace strings,
asserts they are pairwise disjoint, and reads the mapping's derived slot to prove the authorisation
really lands in the operator namespace and **not** at the offset it used to occupy. 211 tests pass.

## M-7. No interface for the vault's own API — ✅ **fixed**

There was no `IIncomeVault`. An integrator wanting to call `deposit`/`claimDividend`/`distributeDividend`
had to import the concrete contract and inherit its whole dependency graph.

### What was implemented

`src/interfaces/IIncomeVault.sol` — 23 functions covering claiming, the claim window, funding, pushed
payouts, claim administration and the state getters, plus the `TIME_ERROR_CODE` enum.

**It is inherited by `IncomeVaultInternal`, not merely declared beside the code.** That was the design
decision worth making. A standalone interface can drift silently from the implementation, which defeats
the stated purpose of making the ABI a contract rather than a by-product. Attaching it to the common
base of both payout paths means the compiler proves conformance — for both deployment variants *and* for
any host embedding the distribution logic, since both reach `IncomeVaultInternal`.

Two consequences worth recording:

- **The enum moved.** `TIME_ERROR_CODE` was declared on `IncomeVaultInternal`; having the interface
  reference it there created an import cycle (`IIncomeVault` → `IncomeVaultInternal` → `IIncomeVault`),
  which compiles until a second file imports both and then fails with `Error (2449)`. Moving it to the
  interface breaks the cycle and is the better home anyway: `validateTimeCode` returns it, so a caller
  holding only the interface must be able to read it. ABI encoding (`uint8`) is unchanged.
- **ERC-165.** Both variants now advertise `type(IIncomeVault).interfaceId`, so the interface is
  discoverable and not merely documented. `IIncomeVault` inherits nothing, so the id covers all 23
  selectors — keep it that way. ERC-7540's operator id remains deliberately unadvertised, and a test
  asserts that, because adding one id is exactly the edit that invites adding the other.

### Deliberately out of scope

`setOperator`/`isOperator` (they are `IERC7540Operator`'s), `transferDividendSelf` (a self-call helper
that rejects every other caller), and the standalone-only surface — pause, freeze, `setRuleEngine`,
`setDividendSnapshotSource` — which an embedded host does not have and must not be forced to implement.

`test/IncomeVaultInterface.t.sol` drives a real proxy through the interface alone, checks the id on both
variants, and asserts both host mocks present the same interface. 210 tests pass.

## M-8. `IncomeVaultBase` bundles ERC-2771 — low

The base inherits `ERC2771Module`, so any host embedding the vault inherits a second ERC-2771 context —
resolvable with overrides, but it is a dependency the distribution logic does not need.

**Proposed change:** move `ERC2771Module` from `IncomeVaultBase` into the two deployable contracts,
beside the access-control base they already choose. Meta-transaction support is a deployment decision,
exactly like the access-control model.

---

## Suggested order

1. ~~**M-1**~~ ✅ done — and it also cleared a second, unreported 5005 on `ReentrancyGuardTransient`.
2. ~~**M-2**~~ ✅ done — `CMTATWithDividend` now compiles; see `test/mocks/CMTATDividendHostMock.sol`.
3. **M-5** — the directory move. No behaviour change.
4. ~~**M-4**~~ ❌ closed as not-a-defect — both hooks gate one hardcoded ERC-7201 slot, so one override
   is the correct answer; prefixing ours was implemented and reverted. **M-8** remains. M-3 is closed: the host overrides
   `version()`, which is also how the embedded IncomeVault release stays visible in the host's source.
5. ~~**M-6**~~ ✅ done — claim delegation has its own namespace; the distribution fields stay together.
6. ~~**M-7**~~ ✅ done — `IIncomeVault`, inherited by `IncomeVaultInternal` so solc enforces it.

## What "done" looks like — ✅ reached

The test at the top compiles. It is now a committed fixture,
`test/mocks/CMTATDividendHostMock.sol`, so the property cannot silently regress:

```solidity
contract CMTATDividendHostMock is
    CMTATUpgradeableInternalSnapshot, IncomeVaultOpen, IncomeVaultRestricted
{
    function _snapshotInfo(uint256 time, address holder)
        internal view override returns (uint256, uint256)
    {
        return snapshotInfo(time, holder);          // the token is its own snapshot source
    }

    function _validateTransfer(address from, address to, uint256 value) internal view override {
        require(canTransfer(from, to, value), ...); // the token's own validation stack
    }

    function _authorizeDeposit() internal view override {}
    // ... the other authorization hooks
}
```

Four hook groups and no forking, no linearization fight. `test/mocks/EmbeddedDividendHostMock.sol` is
the same guard for a host that is *not* a CMTAT.

What made it possible, in order: M-1 removed the inherited validation policy (and a second, unreported
`5005` on `ReentrancyGuardTransient`); M-2 removed the `snapshotEngine()` return-type collision and
moved the source into its own namespace. What remains is cosmetic or organisational — M-4 through M-8,
plus the two records M-3/M-3b — none of which blocks a host.

Both mocks exist only to **compile**. Re-couple either dependency and they stop, which is the point.
