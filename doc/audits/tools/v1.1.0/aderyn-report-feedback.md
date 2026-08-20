# Aderyn feedback — IncomeVault v1.1.0

Triage of every finding in [`aderyn-report.md`](./aderyn-report.md). Each dismissal was checked against the cited `file:line`, not assumed.

```bash
aderyn -x mocks --output doc/audits/tools/v1.1.0/aderyn-report.md
```

Scope: `src/` — 21 files, 982 nSLOC, 87 detectors, mocks excluded. 0 citations of `lib/` or `node_modules/`.

## Summary

| ID | Finding | Instances | Disposition | Reason |
| --- | --- | --- | --- | --- |
| L-1 | Centralization Risk | 18 | By design | Deposit, withdraw, distribute, claim administration, pause, freeze and the two setters are issuer operations and are meant to be privileged. Who holds each is chosen at deployment and documented in the capability table of `doc/README.md`. The pattern organises this power; it does not claim to reduce it. |
| L-2 | Unspecific Solidity Pragma | 21 | By design | `^0.8.24` is required: these contracts are meant to be **inherited** by a host that pins its own version. The deployed artefact is pinned — `foundry.toml` compiles with 0.8.36. A caret pragma on a library is correct; on a final deployable it would not be. |
| L-3 | Public Function Not Used Internally | 2 | By design | Both are `initialize`. It is invoked through the proxy with `abi.encodeCall`, and `public` is the OpenZeppelin upgradeable convention for initializers. |
| L-4 | PUSH0 Opcode | 21 | Environment | `foundry.toml` sets `evm_version = "prague"`, where PUSH0 has existed since Shanghai. Relevant only if deploying to a chain that has not forked past Paris — a deployment decision, not a code defect. |
| L-5 | Modifier Invoked Only Once | 2 | Cosmetic | `onlyRuleEngineManager` and `onlySnapshotSourceManager` each guard exactly one setter. That is the authorization-hook pattern: one capability, one hook, one modifier. Inlining them would save a line and lose the symmetry that makes the capability table readable. |
| L-6 | Empty Block | 18 | By design | Every instance is an `_authorize*` override. **The empty body is the pattern** — the check rides on the modifier (`onlyRole(...)` / `onlyOwner`), and a body would be dead code. Documented in `CLAUDE.md` under the authorization-hook convention. |
| L-7 | Loop Contains `require`/`revert` | 4 | By design | In `claimDividendBatch` and `distributeDividend`, one blocked holder **must** revert the whole call, so a compliance failure cannot be silently dropped. `distributeDividendBestEffort` is the deliberate opposite and skips instead. |
| L-8 | Costly operations inside loop | 3 | Accepted | The storage writes are the per-period accounting (`_segregatedDividend`, `_paidDividend`, `_claimedDividend`). They cannot be hoisted because each iteration targets a different key. |
| L-9 | Unused Import | 4 | False positive | All four are consumed by `@inheritdoc`. Was 6 — the two genuinely unused imports have been removed; see below. |
| L-10 | State Change Without Event | 1 | Consider | `ERC7741Module.invalidateNonce` writes `$._authorizations[...] = true` and emits nothing. ERC-7741 defines no event for it, so the contract is conformant, but an indexer cannot see a nonce burned outside a signature use. Worth adding if the ABI is not yet frozen. |

## L-9 in detail — the two real instances, now fixed

| Location | Verdict |
| --- | --- |
| `src/deployment/IncomeVault.sol` L21 `IncomeVaultRestricted`, L22 `IncomeVaultSnapshotModule` | **False positive.** Used by `@inheritdoc IncomeVaultRestricted` / `@inheritdoc IncomeVaultSnapshotModule` on the hook overrides. Solidity requires the base to be imported **by name** for `@inheritdoc` even when it is already in scope through inheritance; removing the import fails the build with *"references inexistent contract"*. Aderyn parses code references, not NatSpec. |
| `src/deployment/IncomeVaultOwnable2Step.sol` L19, L20 | **False positive**, same reason. |
| `src/modules/Ownable2StepERC165Module.sol` L7 `IERC165` | **Was real — removed.** `IERC165` appeared on the import line and nowhere else. |
| `src/public/IncomeVaultRestricted.sol` L11 `ISnapshotSource` | **Was real — removed.** Its only other occurrence is inside a comment, which creates no compile dependency. Left over from finding M-2, when the snapshot source moved into its own module. |

Both were deleted; `forge build` compiles and all 214 tests pass. Re-running Aderyn afterwards took L-9
from 6 instances to 4, which is the check that the fix landed and that the remaining four really are the
`@inheritdoc` ones. Neither removal changes bytecode — an unused import contributes no code.

## Delta from v1.0.0

v1.0.0 has no Aderyn report; this is the first. No delta is possible, and none is implied by the counts.

## Executive triage

**Nothing exploitable, and nothing left to fix.** The two real findings — unused `IERC165` and
`ISnapshotSource` imports — have been removed, and Aderyn re-run to confirm: L-9 went from 6 instances
to 4, all of them `@inheritdoc` false positives.

One item worth a decision rather than a fix: **L-10**, an event on `invalidateNonce`. ERC-7741 does not
require one, so adding it is a choice about off-chain observability, and it is easier to make before the
ABI is frozen than after.
