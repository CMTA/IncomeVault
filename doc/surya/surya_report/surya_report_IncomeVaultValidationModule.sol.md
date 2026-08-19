## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./modules/IncomeVaultValidationModule.sol | d02cedab3be325aa3620d6ddc1afcf93c677361c |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IncomeVaultValidationModule** | Implementation | AccessControlModule, PauseModule, EnforcementModule, ValidationModuleRuleEngineInternal, IncomeVaultInvariantStorage |||
| └ | __IncomeVaultValidation_init_unchained | Internal 🔒 | 🛑  | onlyInitializing |
| └ | setRuleEngine | Public ❗️ | 🛑  | onlyRole |
| └ | canTransfer | Public ❗️ |   |NO❗️ |
| └ | detectTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | _authorizePause | Internal 🔒 | 🛑  | onlyRole |
| └ | _authorizeDeactivate | Internal 🔒 | 🛑  | onlyRole |
| └ | _authorizeFreeze | Internal 🔒 | 🛑  | onlyRole |
| └ | _validateTransfer | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
