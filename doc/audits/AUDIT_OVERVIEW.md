# Audit and analysis overview

> **The contracts are NOT audited.** No third party has reviewed this code. Everything below is
> self-assessment and tool output. Do not deploy to production without an audit.

## Scope

`src/` only — 21 Solidity files, 982 nSLOC. Tests, mocks and deployment scripts are out of scope for
static analysis; `script/` carries deliberate string `require` messages for operator diagnostics and is
excluded from the style check by project convention.

## Analyses

| Analysis | Version | Report | Triage |
| --- | --- | --- | --- |
| Slither | v1.1.0 | [`tools/v1.1.0/slither-report.md`](./tools/v1.1.0/slither-report.md) | [feedback](./tools/v1.1.0/slither-report-feedback.md) |
| Aderyn | v1.1.0 | [`tools/v1.1.0/aderyn-report.md`](./tools/v1.1.0/aderyn-report.md) | [feedback](./tools/v1.1.0/aderyn-report-feedback.md) |
| Code-quality review (AI, not a security audit) | v1.1.0 | [`tools/v1.1.0/CLAUDE_ANALYSIS.md`](./tools/v1.1.0/CLAUDE_ANALYSIS.md) | — |
| Slither | v1.0.0 | [`tools/v1.0.0/slither-report.md`](./tools/v1.0.0/slither-report.md) | — |

## Static-analysis results, v1.1.0

| Tool | High | Medium | Low | Informational | Anything to fix? |
| --- | --- | --- | --- | --- | --- |
| Slither 0.11.5 | 0 | 5 | 6 | 23 | **No** — all false positives or documented design decisions |
| Aderyn 0.6.5 | 0 | — | 10 | — | **No** — the two unused imports were removed; L-9's four remaining instances are `@inheritdoc` false positives |

Both runs were scope-checked: neither report cites `lib/` or `node_modules/`, so no vendored dependency
inflates the counts.

### The two real findings — fixed

| Location | Finding | Status |
| --- | --- | --- |
| `src/modules/Ownable2StepERC165Module.sol:7` | unused `IERC165` import | removed |
| `src/public/IncomeVaultRestricted.sol:11` | unused `ISnapshotSource` import, left over from finding M-2 | removed |

Aderyn was re-run after the removal: L-9 fell from 6 instances to 4. That drop is the evidence the fix
landed. Neither import contributed bytecode, so this is source hygiene rather than a behaviour change;
214 tests pass unchanged.

The four remaining L-9 instances are **false positives**: they are consumed by `@inheritdoc`, which
requires the base imported by name and which Aderyn does not parse. Deleting them fails the build.

### One open decision

`ERC7741Module.invalidateNonce` changes state without emitting an event (Aderyn L-10). ERC-7741 defines
no event for it, so the contract is conformant — but an indexer cannot observe a nonce burned outside a
signature use. Cheaper to decide before the ABI is frozen than after.

## Substantive findings that were fixed

These came from the code-quality review and the modularity review, not from the static analyzers.
Static analysis found none of them, which is the honest measure of what these tools do and do not cover.

| id | Finding | Where |
| --- | --- | --- |
| H-1 | `distributeDividend` ignored the claim window, so a push payout could be computed from **live** balances instead of the snapshot | `IncomeVaultRestricted` |
| H-2 | `distributeDividend` bypassed pause, freeze and the RuleEngine, so a push could pay a blocked holder | `IncomeVaultValidationModule` |
| E-3 | `withdraw` was bounded by `segregatedDividend`, letting a fully-claimed period drain another period's funds | `IncomeVaultInternal` |
| A-1 | A zero `timeLimitToWithdraw` produced a one-second claim window | `IncomeVaultInternal` |
| — | `INCOME_VAULT_DISTRIBUTE_ROLE` hashed the deposit role's string, so the two roles collided | `IncomeVaultRolesStorage` |
| — | A claim made after a mid-window sweep could be funded from another period's deposit (found by the invariant suite) | `IncomeVaultInternal` |
| M-1, M-2 | The payout logic could not be embedded in a CMTAT at all (`Error 5005`, then an irreconcilable `snapshotEngine()` return-type collision) | `modules/` |

## Reproducing

```bash
slither . --checklist --filter-paths "node_modules,lib,test" \
  > doc/audits/tools/v1.1.0/slither-report.md
aderyn -x mocks --output doc/audits/tools/v1.1.0/aderyn-report.md
```

Use `lib` rather than a list of dependency names: this is a Foundry project, and a name-based filter
fails open when a dependency is added whose directory is not enumerated. After any run, check
`grep -c 'lib/\|node_modules/' <report>` is 0 before trusting the counts.
