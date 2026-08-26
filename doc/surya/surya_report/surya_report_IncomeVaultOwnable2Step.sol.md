## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./deployment/IncomeVaultOwnable2Step.sol | f3b2b1bd3aa3b3c493521a48a0089cd874355001 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IncomeVaultOwnable2Step** | Implementation | IncomeVaultValidationModule, IncomeVaultBaseERC2771, Ownable2StepUpgradeable, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | IncomeVaultBaseERC2771 |
| └ | initialize | Public ❗️ | 🛑  | initializer |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |
| └ | _authorizeDeposit | Internal 🔒 |   | onlyOwner |
| └ | _authorizeWithdraw | Internal 🔒 |   | onlyOwner |
| └ | _authorizeDistribute | Internal 🔒 |   | onlyOwner |
| └ | _authorizeOperator | Internal 🔒 |   | onlyOwner |
| └ | _authorizeSnapshotSourceManagement | Internal 🔒 |   | onlyOwner |
| └ | _authorizeRuleEngineManagement | Internal 🔒 |   | onlyOwner |
| └ | _authorizePause | Internal 🔒 |   | onlyOwner |
| └ | _authorizeDeactivate | Internal 🔒 |   | onlyOwner |
| └ | _authorizeFreeze | Internal 🔒 |   | onlyOwner |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
