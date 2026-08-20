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
| M-3 | `version()` collides with CMTAT's `VersionModule` | high |
| M-4 | `_authorizeRuleEngineManagement()` is declared by both this project and CMTAT | medium |
| M-5 | `libraries/` contains no libraries; `public/` groups by visibility rather than capability | medium (legibility) |
| M-6 | One monolithic storage namespace covering four unrelated concerns | medium |
| M-7 | No interface describes the vault's own API | low |
| M-8 | `IncomeVaultBase` bundles ERC-2771, which a host already has | low |

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

## M-3. `version()` collides with CMTAT's — high

`src/modules/VersionModule.sol` and CMTAT's `VersionModule` both declare
`version() returns (string memory)` behind `IERC3643Version`. Any host that is a CMTAT already has one.

**Proposed change:** move `VersionModule` out of the reusable core and into the two deployable
contracts. A mixin whose only job is to report *this project's* release number does not belong in a
layer meant to be embedded in someone else's contract — the host reports its own version.

## M-4. `_authorizeRuleEngineManagement()` is declared twice — medium

This project declares it in `IncomeVaultValidationModule`; CMTAT declares it in
`ValidationModuleRuleEngine` and implements it in `3_CMTATBaseRuleEngine`. Mixing produces two hooks
with one name, and an integrator overriding "the" hook has no way to tell which they satisfied.

**Proposed change:** prefix this project's hooks so they cannot collide with a host's —
`_authorizeIncomeVaultRuleEngine()` — or, if M-1 is done, drop the RuleEngine handling from the core
entirely and let the host's validation answer through `_validateTransfer`. The second is better: it
removes the hook rather than renaming it.

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

## M-6. One storage namespace for four concerns — medium

`IncomeVaultInternalStorage` holds the snapshot source, the payment token, the claim bookkeeping, the
withdraw limit, the open-period counter, the paid-per-period totals **and** the operator mapping. A host
that wants only the distribution still inherits the operator state, and vice versa.

**Proposed change:** one namespace per capability, as `ERC7741Module` already does —
`IncomeVault.storage.Distribution` and `IncomeVault.storage.Operator`. ERC-7201 makes this free: the
namespaces are hash-derived and cannot collide, so splitting costs nothing but is impossible to do
later without breaking deployed storage.

## M-7. No interface for the vault's own API — low

There is no `IIncomeVault`. An integrator wanting to call `deposit`/`claimDividend`/`distributeDividend`
must import the concrete contract and inherit its whole dependency graph.

**Proposed change:** declare `IIncomeVault` alongside the two standard interfaces, and have the
deployable contracts implement it. Cheap, and it makes the ABI a stated contract rather than a
by-product.

## M-8. `IncomeVaultBase` bundles ERC-2771 — low

The base inherits `ERC2771Module`, so any host embedding the vault inherits a second ERC-2771 context —
resolvable with overrides, but it is a dependency the distribution logic does not need.

**Proposed change:** move `ERC2771Module` from `IncomeVaultBase` into the two deployable contracts,
beside the access-control base they already choose. Meta-transaction support is a deployment decision,
exactly like the access-control model.

---

## Suggested order

1. ~~**M-1**~~ ✅ done — and it also cleared a second, unreported 5005 on `ReentrancyGuardTransient`.
2. **M-2** — the remaining blocker, and now the only thing between the codebase and a compiling
   `CMTATWithDividend`.
3. **M-5** — the directory move. No behaviour change.
4. **M-3, M-4, M-8** — M-1 already moved the RuleEngine hook out of the shared layer, so M-4 is
   largely defused; M-3 and M-8 remain.
5. **M-6** — do it before the first deployment carrying real value; it cannot be done afterwards.
6. **M-7** — any time.

## What "done" looks like

The test at the top compiles:

```solidity
contract CMTATWithDividend is CMTATStandaloneSnapshot, IncomeVaultDistributionModule {
    function _snapshotInfo(uint256 time, address holder) internal view override returns (uint256, uint256) {
        return snapshotInfo(time, holder);          // the token is its own snapshot source
    }
    function _validateTransfer(address from, address to, uint256 value) internal view override {
        require(canTransfer(from, to, value), ...); // the token's own ValidationModule
    }
    function _authorizeDeposit() internal view override onlyRole(DEBT_ROLE) {}
    // ... the other authorization hooks
}
```

Three overrides and the existing hooks — no forking, no linearization fight. Worth adding as a
compiling test fixture once M-1 and M-2 land, so the property cannot silently regress.
