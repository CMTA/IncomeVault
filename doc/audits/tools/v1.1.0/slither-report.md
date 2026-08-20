# Slither report — IncomeVault v1.1.0

> The contracts are **NOT audited**. Static analysis is not an audit; these are leads, not findings.

| | |
| --- | --- |
| Tool | Slither 0.11.5 |
| Date | 2026-08-20 |
| Scope | `src/` only — 90 contracts analysed, 101 detectors |
| Mocks | **excluded** (`test/` filtered, and Slither's Foundry driver skips `./test/**` and `./script/**`) |

```bash
slither . --checklist --filter-paths "node_modules,lib,test" \
  > doc/audits/tools/v1.1.0/slither-report.md
```

**Scope verified:** `grep -c 'lib/\|node_modules/'` on this report returns **0**, so no vendored
dependency is in scope. The `filter-paths` entry is `lib` because this is a Foundry project; the
name-based filter used for v1.0.0 (`openzeppelin-contracts|test|CMTAT|forge-std`) happens to match the
same paths but fails open if a dependency is added whose directory name is not listed.

## Result: 0 High · 5 Medium · 6 Low · 23 Informational — 34 total

| Detector | Severity | Instances | Assessment |
| --- | --- | --- | --- |
| `uninitialized-local` | Medium | 2 | False positive — counters, zero-initialised by the language and written before any read |
| `unused-return` | Medium | 3 | False positive — the value is `return`ed straight to the caller |
| `calls-loop` | Low | 4 | By design — the RuleEngine must be consulted per holder |
| `timestamp` | Low | 2 | By design — the claim window *is* defined in `block.timestamp` |
| `assembly` | Informational | 4 | By design — the four ERC-7201 storage accessors |
| `dead-code` | Informational | 3 | False positive — `_msgData()` overrides are required to resolve the ERC-2771 diamond |
| `naming-convention` | Informational | 16 | By design — OpenZeppelin and CMTAT naming conventions |

**Nothing in this report needs fixing.** Every finding is a false positive or a documented design
decision; each is verified against the source in
[`slither-report-feedback.md`](./slither-report-feedback.md). See also
[`doc/audits/AUDIT_OVERVIEW.md`](../../AUDIT_OVERVIEW.md).

---

**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [uninitialized-local](#uninitialized-local) (2 results) (Medium)
 - [unused-return](#unused-return) (3 results) (Medium)
 - [calls-loop](#calls-loop) (4 results) (Low)
 - [timestamp](#timestamp) (2 results) (Low)
 - [assembly](#assembly) (4 results) (Informational)
 - [dead-code](#dead-code) (3 results) (Informational)
 - [naming-convention](#naming-convention) (16 results) (Informational)
## uninitialized-local
Impact: Medium
Confidence: Medium
 - [ ] ID-0
[IncomeVaultRestricted.depositBatch(uint256[],uint256[]).total](src/public/IncomeVaultRestricted.sol#L104) is a local variable never initialized

src/public/IncomeVaultRestricted.sol#L104


 - [ ] ID-1
[IncomeVaultRestricted.distributeDividendBestEffort(address[],uint256).skippedCount](src/public/IncomeVaultRestricted.sol#L237) is a local variable never initialized

src/public/IncomeVaultRestricted.sol#L237


## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-2
[IncomeVaultSnapshotModule._snapshotInfoBatch(uint256,address[])](src/modules/IncomeVaultSnapshotModule.sol#L117-L125) ignores return value by [dividendSnapshotSource().snapshotInfoBatch(time,addresses)](src/modules/IncomeVaultSnapshotModule.sol#L124)

src/modules/IncomeVaultSnapshotModule.sol#L117-L125


 - [ ] ID-3
[IncomeVaultSnapshotModule._snapshotInfoBatch(uint256[],address[])](src/modules/IncomeVaultSnapshotModule.sol#L128-L136) ignores return value by [dividendSnapshotSource().snapshotInfoBatch(times,addresses)](src/modules/IncomeVaultSnapshotModule.sol#L135)

src/modules/IncomeVaultSnapshotModule.sol#L128-L136


 - [ ] ID-4
[IncomeVaultSnapshotModule._snapshotInfo(uint256,address)](src/modules/IncomeVaultSnapshotModule.sol#L106-L114) ignores return value by [dividendSnapshotSource().snapshotInfo(time,tokenHolder)](src/modules/IncomeVaultSnapshotModule.sol#L113)

src/modules/IncomeVaultSnapshotModule.sol#L106-L114


## calls-loop
Impact: Low
Confidence: Medium
 - [ ] ID-5
[IncomeVaultValidationModule.canTransfer(address,address,uint256)](src/modules/IncomeVaultValidationModule.sol#L87-L103) has external calls inside a loop: [ruleEngine_.canTransfer(from,to,value)](src/modules/IncomeVaultValidationModule.sol#L100)
	Calls stack containing the loop:
		IncomeVaultRestricted.distributeDividend(address[],uint256)
		IncomeVaultValidationModule._validateTransfer(address,address,uint256)

src/modules/IncomeVaultValidationModule.sol#L87-L103


 - [ ] ID-6
[IncomeVaultRestricted.distributeDividendBestEffort(address[],uint256)](src/public/IncomeVaultRestricted.sol#L223-L257) has external calls inside a loop: [this.transferDividendSelf(time,addresses[i],tokenHolderDividend[i])](src/public/IncomeVaultRestricted.sol#L244-L250)

src/public/IncomeVaultRestricted.sol#L223-L257


 - [ ] ID-7
[IncomeVaultValidationModule.canTransfer(address,address,uint256)](src/modules/IncomeVaultValidationModule.sol#L87-L103) has external calls inside a loop: [ruleEngine_.canTransfer(from,to,value)](src/modules/IncomeVaultValidationModule.sol#L100)
	Calls stack containing the loop:
		IncomeVaultOpen.claimDividendBatch(uint256[])
		IncomeVaultOpen._claimDividendBatch(address,uint256[])
		IncomeVaultValidationModule._validateTransfer(address,address,uint256)

src/modules/IncomeVaultValidationModule.sol#L87-L103


 - [ ] ID-8
[IncomeVaultValidationModule.canTransfer(address,address,uint256)](src/modules/IncomeVaultValidationModule.sol#L87-L103) has external calls inside a loop: [ruleEngine_.canTransfer(from,to,value)](src/modules/IncomeVaultValidationModule.sol#L100)
	Calls stack containing the loop:
		IncomeVaultOpen.claimDividendBatchFor(address,uint256[])
		IncomeVaultOpen._claimDividendBatch(address,uint256[])
		IncomeVaultValidationModule._validateTransfer(address,address,uint256)

src/modules/IncomeVaultValidationModule.sol#L87-L103


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-9
[ERC7741Module.authorizeOperator(address,address,bool,bytes32,uint256,bytes)](src/modules/ERC7741Module.sol#L73-L104) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp > deadline](src/modules/ERC7741Module.sol#L81)

src/modules/ERC7741Module.sol#L73-L104


 - [ ] ID-10
[IncomeVaultInternal._timeCode(IncomeVaultInternal.IncomeVaultInternalStorage,uint256,uint256)](src/modules/IncomeVaultInternal.sol#L322-L338) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp > timeLimit + time](src/modules/IncomeVaultInternal.sol#L331)
	- [block.timestamp < time](src/modules/IncomeVaultInternal.sol#L334)

src/modules/IncomeVaultInternal.sol#L322-L338


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-11
[IncomeVaultSnapshotModule._getSnapshotSourceStorage()](src/modules/IncomeVaultSnapshotModule.sol#L150-L154) uses assembly
	- [INLINE ASM](src/modules/IncomeVaultSnapshotModule.sol#L151-L153)

src/modules/IncomeVaultSnapshotModule.sol#L150-L154


 - [ ] ID-12
[IncomeVaultOperatorModule._getOperatorStorage()](src/modules/IncomeVaultOperatorModule.sol#L104-L108) uses assembly
	- [INLINE ASM](src/modules/IncomeVaultOperatorModule.sol#L105-L107)

src/modules/IncomeVaultOperatorModule.sol#L104-L108


 - [ ] ID-13
[ERC7741Module._getERC7741ModuleStorage()](src/modules/ERC7741Module.sol#L134-L138) uses assembly
	- [INLINE ASM](src/modules/ERC7741Module.sol#L135-L137)

src/modules/ERC7741Module.sol#L134-L138


 - [ ] ID-14
[IncomeVaultInternal._getIncomeVaultInternalStorage()](src/modules/IncomeVaultInternal.sol#L345-L349) uses assembly
	- [INLINE ASM](src/modules/IncomeVaultInternal.sol#L346-L348)

src/modules/IncomeVaultInternal.sol#L345-L349


## dead-code
Impact: Informational
Confidence: Medium
 - [ ] ID-15
[IncomeVaultBaseERC2771._msgData()](src/IncomeVaultBaseERC2771.sol#L61-L69) is never used and should be removed

src/IncomeVaultBaseERC2771.sol#L61-L69


 - [ ] ID-16
[IncomeVaultOwnable2Step._msgData()](src/deployment/IncomeVaultOwnable2Step.sol#L114-L116) is never used and should be removed

src/deployment/IncomeVaultOwnable2Step.sol#L114-L116


 - [ ] ID-17
[IncomeVault._msgData()](src/deployment/IncomeVault.sol#L110-L112) is never used and should be removed

src/deployment/IncomeVault.sol#L110-L112


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-18
Function [IncomeVaultInternal.ERC20TokenPayment()](src/modules/IncomeVaultInternal.sol#L67-L70) is not in mixedCase

src/modules/IncomeVaultInternal.sol#L67-L70


 - [ ] ID-19
Parameter [IncomeVaultBase.__IncomeVaultBase_init_unchained(IERC20,ISnapshotSource,uint256).ERC20TokenPayment_](src/IncomeVaultBase.sol#L54) is not in mixedCase

src/IncomeVaultBase.sol#L54


 - [ ] ID-20
Function [IERC7741.DOMAIN_SEPARATOR()](src/interfaces/IERC7741.sol#L61) is not in mixedCase

src/interfaces/IERC7741.sol#L61


 - [ ] ID-21
Parameter [IncomeVault.initialize(address,IERC20,ISnapshotSource,IRuleEngine,uint256).ERC20TokenPayment_](src/deployment/IncomeVault.sol#L60) is not in mixedCase

src/deployment/IncomeVault.sol#L60


 - [ ] ID-22
Event [IncomeVaultInvariantStorage.newDeposit(uint256,address,uint256)](src/storage/IncomeVaultInvariantStorage.sol#L20) is not in CapWords

src/storage/IncomeVaultInvariantStorage.sol#L20


 - [ ] ID-23
Function [IIncomeVault.ERC20TokenPayment()](src/interfaces/IIncomeVault.sol#L157) is not in mixedCase

src/interfaces/IIncomeVault.sol#L157


 - [ ] ID-24
Parameter [IncomeVaultOwnable2Step.initialize(address,IERC20,ISnapshotSource,IRuleEngine,uint256).ERC20TokenPayment_](src/deployment/IncomeVaultOwnable2Step.sol#L66) is not in mixedCase

src/deployment/IncomeVaultOwnable2Step.sol#L66


 - [ ] ID-25
Constant [IncomeVaultSnapshotModule.SnapshotSourceStorageLocation](src/modules/IncomeVaultSnapshotModule.sol#L37-L38) is not in UPPER_CASE_WITH_UNDERSCORES

src/modules/IncomeVaultSnapshotModule.sol#L37-L38


 - [ ] ID-26
Function [ERC7741Module.DOMAIN_SEPARATOR()](src/modules/ERC7741Module.sol#L122-L124) is not in mixedCase

src/modules/ERC7741Module.sol#L122-L124


 - [ ] ID-27
Constant [IncomeVaultInternal.IncomeVaultInternalStorageLocation](src/modules/IncomeVaultInternal.sol#L34-L35) is not in UPPER_CASE_WITH_UNDERSCORES

src/modules/IncomeVaultInternal.sol#L34-L35


 - [ ] ID-28
Function [IncomeVaultRestricted.__IncomeVaultRestricted_init_unchained(uint256)](src/public/IncomeVaultRestricted.sol#L58-L60) is not in mixedCase

src/public/IncomeVaultRestricted.sol#L58-L60


 - [ ] ID-29
Function [IncomeVaultBase.__IncomeVaultBase_init_unchained(IERC20,ISnapshotSource,uint256)](src/IncomeVaultBase.sol#L53-L65) is not in mixedCase

src/IncomeVaultBase.sol#L53-L65


 - [ ] ID-30
Enum [IIncomeVault.TIME_ERROR_CODE](src/interfaces/IIncomeVault.sol#L35-L40) is not in CapWords

src/interfaces/IIncomeVault.sol#L35-L40


 - [ ] ID-31
Constant [ERC7741Module.ERC7741ModuleStorageLocation](src/modules/ERC7741Module.sol#L48) is not in UPPER_CASE_WITH_UNDERSCORES

src/modules/ERC7741Module.sol#L48


 - [ ] ID-32
Constant [IncomeVaultOperatorModule.OperatorStorageLocation](src/modules/IncomeVaultOperatorModule.sol#L31-L32) is not in UPPER_CASE_WITH_UNDERSCORES

src/modules/IncomeVaultOperatorModule.sol#L31-L32


 - [ ] ID-33
Function [IncomeVaultValidationModule.__IncomeVaultValidation_init_unchained(IRuleEngine)](src/modules/IncomeVaultValidationModule.sol#L56-L60) is not in mixedCase

src/modules/IncomeVaultValidationModule.sol#L56-L60


