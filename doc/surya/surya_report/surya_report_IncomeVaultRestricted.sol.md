## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./public/IncomeVaultRestricted.sol | 2cd9f60df6c3914215089a4a7522b2b8ce9973a6 |


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
