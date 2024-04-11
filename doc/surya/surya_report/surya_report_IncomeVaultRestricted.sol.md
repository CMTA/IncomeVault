## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./public/IncomeVaultRestricted.sol | 045808f76caaa6faec4a42805df928607c6845bd |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IncomeVaultRestricted** | Implementation | ValidationModule, IncomeVaultInternal |||
| └ | deposit | Public ❗️ | 🛑  | onlyRole |
| └ | withdraw | Public ❗️ | 🛑  | onlyRole |
| └ | withdrawAll | Public ❗️ | 🛑  | onlyRole |
| └ | distributeDividend | Public ❗️ | 🛑  | onlyRole |
| └ | setStatusClaim | Public ❗️ | 🛑  | onlyRole |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
