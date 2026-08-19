## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./public/IncomeVaultRestricted.sol | 56748e23d3fd1d849f9db9e5264937b62c4c389c |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IncomeVaultRestricted** | Implementation | IncomeVaultValidationModule, IncomeVaultInternal |||
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
