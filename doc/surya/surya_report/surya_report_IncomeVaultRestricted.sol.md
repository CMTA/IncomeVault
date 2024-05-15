## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./public/IncomeVaultRestricted.sol | d5d6fe92e3da58e30c320c01b0529cf1ccea09ff |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IncomeVaultRestricted** | Implementation | ValidationModule, IncomeVaultInternal |||
| └ | __IncomeVaultRestricted_init_unchained | Internal 🔒 | 🛑  | onlyInitializing |
| └ | deposit | Public ❗️ | 🛑  | onlyRole |
| └ | withdraw | Public ❗️ | 🛑  | onlyRole |
| └ | withdrawAll | Public ❗️ | 🛑  | onlyRole |
| └ | distributeDividend | Public ❗️ | 🛑  | onlyRole |
| └ | setStatusClaim | Public ❗️ | 🛑  | onlyRole |
| └ | setTimeLimitToWithdraw | Public ❗️ | 🛑  | onlyRole |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
