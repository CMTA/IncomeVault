## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./modules/IncomeVaultSnapshotModule.sol | 852f2f2231a558e3b1eb004a92f5c6193f23e82d |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IncomeVaultSnapshotModule** | Implementation | IncomeVaultSnapshotCore, IncomeVaultInternal |||
| └ | setDividendSnapshotSource | Public ❗️ | 🛑  | onlySnapshotSourceManager |
| └ | dividendSnapshotSource | Public ❗️ |   |NO❗️ |
| └ | _setDividendSnapshotSource | Internal 🔒 | 🛑  | |
| └ | _snapshotInfo | Internal 🔒 |   | |
| └ | _snapshotInfoBatch | Internal 🔒 |   | |
| └ | _snapshotInfoBatch | Internal 🔒 |   | |
| └ | _authorizeSnapshotSourceManagement | Internal 🔒 |   | |
| └ | _getSnapshotSourceStorage | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
