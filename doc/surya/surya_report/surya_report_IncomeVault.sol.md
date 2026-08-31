## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./deployment/IncomeVault.sol | 13f4d611a5dac650aae2720df488e06e8bf1290c |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IncomeVault** | Implementation | IncomeVaultValidationModule, IncomeVaultBaseERC2771, AccessControlModule, IncomeVaultRolesStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  | IncomeVaultBaseERC2771 |
| └ | initialize | Public ❗️ | 🛑  | initializer |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |
| └ | _authorizeDeposit | Internal 🔒 |   | onlyRole |
| └ | _authorizeWithdraw | Internal 🔒 |   | onlyRole |
| └ | _authorizeDistribute | Internal 🔒 |   | onlyRole |
| └ | _authorizeOperator | Internal 🔒 |   | onlyRole |
| └ | _authorizeSnapshotSourceManagement | Internal 🔒 |   | onlyRole |
| └ | _authorizeRuleEngineManagement | Internal 🔒 |   | onlyRole |
| └ | _authorizePause | Internal 🔒 |   | onlyRole |
| └ | _authorizeDeactivate | Internal 🔒 |   | onlyRole |
| └ | _authorizeFreeze | Internal 🔒 |   | onlyRole |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
