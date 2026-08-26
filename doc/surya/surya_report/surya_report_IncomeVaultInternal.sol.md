## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./modules/IncomeVaultInternal.sol | 2f78f7afe0e91d0052b8b2e64d4d9608ac253bf5 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IncomeVaultInternal** | Implementation | IncomeVaultInvariantStorage, IIncomeVault |||
| └ | ERC20TokenPayment | Public ❗️ |   |NO❗️ |
| └ | claimedDividend | Public ❗️ |   |NO❗️ |
| └ | segregatedDividend | Public ❗️ |   |NO❗️ |
| └ | segregatedClaim | Public ❗️ |   |NO❗️ |
| └ | paidDividend | Public ❗️ |   |NO❗️ |
| └ | unclaimedDividend | Public ❗️ |   |NO❗️ |
| └ | openClaimCount | Public ❗️ |   |NO❗️ |
| └ | timeLimitToWithdraw | Public ❗️ |   |NO❗️ |
| └ | _transferDividend | Internal 🔒 | 🛑  | |
| └ | _setERC20TokenPayment | Internal 🔒 | 🛑  | |
| └ | _setTimeLimitToWithdraw | Internal 🔒 | 🛑  | |
| └ | _deposit | Internal 🔒 | 🛑  | |
| └ | _setStatusClaim | Internal 🔒 | 🛑  | |
| └ | _unclaimed | Internal 🔒 |   | |
| └ | _computeDividendBatch | Internal 🔒 |   | |
| └ | _computeDividend | Internal 🔒 |   | |
| └ | _revertOnInvalidTime | Internal 🔒 |   | |
| └ | _timeCode | Internal 🔒 |   | |
| └ | _getIncomeVaultInternalStorage | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
