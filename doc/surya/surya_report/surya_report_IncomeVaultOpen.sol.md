## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./public/IncomeVaultOpen.sol | a9a9489512e617a87179a89b1c0eb4743ff68917 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IncomeVaultOpen** | Implementation | ReentrancyGuardUpgradeable, ValidationModule, IncomeVaultInternal |||
| └ | validateTimeCode | Public ❗️ |   |NO❗️ |
| └ | validateTime | Public ❗️ |   |NO❗️ |
| └ | validateTimeBatch | Public ❗️ |   |NO❗️ |
| └ | claimDividend | Public ❗️ | 🛑  | nonReentrant |
| └ | claimDividendBatch | Public ❗️ | 🛑  | nonReentrant |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
