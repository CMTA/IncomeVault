## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./libraries/IncomeVaultInternal.sol | b831637aceba115b93cbe90d1152b1d05f2ea3da |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IncomeVaultInternal** | Implementation | IncomeVaultInvariantStorage |||
| └ | snapshotEngine | Public ❗️ |   |NO❗️ |
| └ | ERC20TokenPayment | Public ❗️ |   |NO❗️ |
| └ | claimedDividend | Public ❗️ |   |NO❗️ |
| └ | segregatedDividend | Public ❗️ |   |NO❗️ |
| └ | segregatedClaim | Public ❗️ |   |NO❗️ |
| └ | timeLimitToWithdraw | Public ❗️ |   |NO❗️ |
| └ | _transferDividend | Internal 🔒 | 🛑  | |
| └ | _setSnapshotEngine | Internal 🔒 | 🛑  | |
| └ | _setERC20TokenPayment | Internal 🔒 | 🛑  | |
| └ | _setTimeLimitToWithdraw | Internal 🔒 | 🛑  | |
| └ | _computeDividendBatch | Internal 🔒 |   | |
| └ | _computeDividend | Internal 🔒 |   | |
| └ | _getIncomeVaultInternalStorage | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
