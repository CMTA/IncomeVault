## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| src/DebtVault.sol | 929b5bd142558e73e27170b837e822bafe85a125 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **DebtVault** | Implementation | MetaTxModuleStandalone, ReentrancyGuard, DebtVaultInvariantStorage, AuthorizationModuleStandalone |||
| └ | <Constructor> | Public ❗️ | 🛑  | MetaTxModuleStandalone |
| └ | claimDividend | Public ❗️ | 🛑  | nonReentrant |
| └ | deposit | Public ❗️ | 🛑  | onlyRole |
| └ | withdraw | Public ❗️ | 🛑  | onlyRole |
| └ | withdrawAll | Public ❗️ | 🛑  | onlyRole |
| └ | setStatusClaim | Public ❗️ | 🛑  | onlyRole |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
