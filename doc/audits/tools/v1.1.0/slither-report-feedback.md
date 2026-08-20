# Slither feedback — IncomeVault v1.1.0

Triage of every finding in [`slither-report.md`](./slither-report.md). Each dismissal was checked against the cited `file:line`, not assumed.

```bash
slither . --checklist --filter-paths "node_modules,lib,test" > doc/audits/tools/v1.1.0/slither-report.md
```

Scope: `src/` only, mocks and tests excluded, 90 contracts, 101 detectors. `grep -c 'lib/\|node_modules/'` on the report returns 0.

## Summary

| Detector | Severity | Instances | Disposition | Reason |
| --- | --- | --- | --- | --- |
| `uninitialized-local` | Medium | 2 | False positive | `distributeDividendBestEffort.skippedCount` and `depositBatch.total` are accumulators. Solidity zero-initialises locals, and both are written before any read — `skippedCount` only ever via `skippedBuffer[skippedCount++]`, `total` via `total += amounts[i]`. Slither flags the absence of an explicit `= 0`, which the language already guarantees. |
| `unused-return` | Medium | 3 | False positive | All three are in `IncomeVaultSnapshotModule`, and the body is `return dividendSnapshotSource().snapshotInfo(...)` — the value is returned straight to the caller, not discarded. Slither does not model a direct tail return of an external call's tuple. |
| `calls-loop` | Low | 4 | By design | `IRuleEngine.canTransfer` is consulted once per holder inside `claimDividendBatch` / `distributeDividend`. That is the point: a compliance decision is per payout and cannot be hoisted. The consequence — a batch large enough to exhaust gas — is real and bounded by the caller choosing the batch size, not by the contract. |
| `timestamp` | Low | 2 | By design | The claim window is *defined* in `block.timestamp`: a claim is refused before `time` and after `time + timeLimitToWithdraw`. Miner drift of a few seconds against a window measured in days is not a manipulation surface. |
| `assembly` | Informational | 4 | By design | The four ERC-7201 storage accessors. Assembly is the only way to assign `$.slot`, and it is the pattern OpenZeppelin Upgradeable and CMTAT v3 both use. |
| `dead-code` | Informational | 3 | False positive | `_msgData()` in `IncomeVault`, `IncomeVaultOwnable2Step` and `IncomeVaultBaseERC2771`. These are **required** overrides resolving the `ERC2771ContextUpgradeable` / `ContextUpgradeable` diamond; deleting any of them fails to compile. Slither sees no caller because the caller is the compiler's dispatch, not project code. |
| `naming-convention` | Informational | 16 | By design | Every instance is an upstream convention: `__X_init_unchained` (OpenZeppelin initializers), `ERC20TokenPayment_` (trailing underscore for a constructor/initializer argument), `XStorageLocation` (ERC-7201 slot constants, CapWords in OZ too), `DOMAIN_SEPARATOR` (fixed by EIP-712), `TIME_ERROR_CODE` (an ERC-1404-style code enum), and `newDeposit` — kept lowercase deliberately for v1 ABI compatibility. |

## Delta from v1.0.0

The v1.0.0 report predates the CMTAT v3 migration and the whole modularity rework, so a
finding-by-finding delta would compare two different architectures. What is worth recording:

- **The v1.0.0 findings are gone by construction.** They cite `__gap`, `ICMTATSnapshot` and
  `IAuthorizationEngine` — none of which exist now. Storage moved to ERC-7201 (no `__gap`), the
  snapshot source became `ISnapshotSource`, and the authorization engine was removed by CMTAT v3.
- **Contract count roughly doubled** (one deployable plus a base, to 21 source files across
  `deployment/`, `modules/`, `public/`, `interfaces/`, `storage/`), yet the total is 34 findings, all
  informational-to-medium and none real. The new `assembly` and `naming-convention` instances are the
  direct, expected cost of adopting ERC-7201.
- **The filter changed** from a name list to `lib`. See the report header: the old form works today but
  fails open if a dependency directory is added whose name is not enumerated.

## Executive triage

**Nothing to fix.** No finding is exploitable, and none indicates a defect. The two Medium findings are
both false positives verified against the source: locals that Solidity zero-initialises, and an external
call whose result is returned rather than dropped.

The one finding worth *remembering* rather than fixing is `calls-loop`: batch entry points are bounded by
gas, so an operator building a very large `distributeDividend` batch must size it themselves. That is
already the reason `distributeDividendBestEffort` exists.
