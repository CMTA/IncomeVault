## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./modules/IncomeVaultValidationModule.sol | 21fe5f150b450330f495152879c605f96f6e7a8c |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IncomeVaultValidationModule** | Implementation | IncomeVaultValidationCore, PauseModule, EnforcementModule, ValidationModuleRuleEngineInternal, IncomeVaultInvariantStorage |||
| └ | __IncomeVaultValidation_init_unchained | Internal 🔒 | 🛑  | onlyInitializing |
| └ | setRuleEngine | Public ❗️ | 🛑  | onlyRuleEngineManager |
| └ | canTransfer | Public ❗️ |   |NO❗️ |
| └ | detectTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | _authorizeRuleEngineManagement | Internal 🔒 |   | |
| └ | _validateTransfer | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
