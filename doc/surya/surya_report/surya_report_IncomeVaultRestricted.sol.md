## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./public/IncomeVaultRestricted.sol | 93d0d2ecfc87313ca8f8dd1bbd125d333a06e15d |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IncomeVaultRestricted** | Implementation | IncomeVaultValidationCore, IncomeVaultSnapshotCore, ContextUpgradeable, IncomeVaultInternal, ReentrancyGuardTransient |||
| └ | __IncomeVaultRestricted_init_unchained | Internal 🔒 | 🛑  | onlyInitializing |
| └ | deposit | Public ❗️ | 🛑  | onlyDepositManager |
| └ | depositBatch | Public ❗️ | 🛑  | onlyDepositManager |
| └ | withdraw | Public ❗️ | 🛑  | onlyWithdrawManager |
| └ | withdrawAll | Public ❗️ | 🛑  | onlyWithdrawManager |
| └ | distributeDividend | Public ❗️ | 🛑  | onlyDistributeManager |
| └ | distributeDividendBestEffort | Public ❗️ | 🛑  | nonReentrant onlyDistributeManager |
| └ | transferDividendSelf | Public ❗️ | 🛑  |NO❗️ |
| └ | setStatusClaim | Public ❗️ | 🛑  | onlyVaultOperator |
| └ | setTimeLimitToWithdraw | Public ❗️ | 🛑  | onlyVaultOperator |
| └ | _authorizeDeposit | Internal 🔒 |   | |
| └ | _authorizeWithdraw | Internal 🔒 |   | |
| └ | _authorizeDistribute | Internal 🔒 |   | |
| └ | _authorizeOperator | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
