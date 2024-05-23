**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [reentrancy-benign](#reentrancy-benign) (1 results) (Low)
 - [pragma](#pragma) (1 results) (Informational)
 - [dead-code](#dead-code) (1 results) (Informational)
 - [solc-version](#solc-version) (2 results) (Informational)
 - [naming-convention](#naming-convention) (11 results) (Informational)
 - [unused-import](#unused-import) (6 results) (Informational)
 - [unused-state](#unused-state) (1 results) (Informational)
## reentrancy-benign

> Withdraw is protected by access control, reentrancy can not be used by an attacker

Impact: Low
Confidence: Medium
 - [ ] ID-0
	Reentrancy in [IncomeVaultRestricted.withdraw(uint256,uint256,address)](src/public/IncomeVaultRestricted.sol#L40-L51):
	External calls:
	- [result = ERC20TokenPayment.approve(address(this),amount)](src/public/IncomeVaultRestricted.sol#L41)
	State variables written after the call(s):
	- [segragatedDividend[time] -= amount](src/public/IncomeVaultRestricted.sol#L48)

src/public/IncomeVaultRestricted.sol#L40-L51

## pragma

> Concerns the CMTAT lib, will be fixed in the CMTAT lib.

Impact: Informational
Confidence: High
 - [ ] ID-1
	2 different versions of Solidity are used:
	- Version constraint ^0.8.0 is used by:
 		- lib/CMTAT/contracts/interfaces/ICMTATSnapshot.sol#3
		- lib/CMTAT/contracts/interfaces/draft-IERC1404/draft-IERC1404.sol#3
		- lib/CMTAT/contracts/interfaces/draft-IERC1404/draft-IERC1404Wrapper.sol#3
		- lib/CMTAT/contracts/interfaces/engine/IAuthorizationEngine.sol#3
		- lib/CMTAT/contracts/interfaces/engine/IRuleEngine.sol#3
	- Version constraint ^0.8.20 is used by:
 		- lib/CMTAT/contracts/libraries/Errors.sol#3
		- lib/CMTAT/contracts/modules/internal/EnforcementModuleInternal.sol#3
		- lib/CMTAT/contracts/modules/internal/ValidationModuleInternal.sol#3
		- lib/CMTAT/contracts/modules/security/AuthorizationModule.sol#3
		- lib/CMTAT/contracts/modules/wrapper/controllers/ValidationModule.sol#3
		- lib/CMTAT/contracts/modules/wrapper/core/EnforcementModule.sol#3
		- lib/CMTAT/contracts/modules/wrapper/core/PauseModule.sol#3
		- lib/CMTAT/contracts/modules/wrapper/extensions/MetaTxModule.sol#3
		- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol#4
		- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/metatx/ERC2771ContextUpgradeable.sol#4
		- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol#4
		- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#4
		- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol#4
		- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol#4
		- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol#4
		- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/utils/introspection/ERC165Upgradeable.sol#4
		- lib/openzeppelin-contracts/contracts/access/IAccessControl.sol#4
		- lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol#3
		- lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#4
		- lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol#4
		- lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol#4
		- lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#4
		- lib/openzeppelin-contracts/contracts/utils/Address.sol#4
		- lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol#4
		- src/IncomeVault.sol#3
		- src/lib/IncomeVaultInternal.sol#3
		- src/lib/IncomeVaultInvariantStorage.sol#3
		- src/public/IncomeVaultOpen.sol#3
		- src/public/IncomeVaultRestricted.sol#3

## dead-code

> - Implemented to be gasless compatible (see MetaTxModule)
>
> - If we remove this function, we will have the following error:
>
>   "Derived contract must override function "_msgData". Two or more base classes define function with same name and parameter types."

Impact: Informational
Confidence: Medium
 - [ ] ID-2
[IncomeVault._msgData()](src/IncomeVault.sol#L96-L103) is never used and should be removed

src/IncomeVault.sol#L96-L103

## solc-version

> The version set in the config file is 0.8.22

Impact: Informational
Confidence: High
 - [ ] ID-3
Version constraint ^0.8.0 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess
	- AbiReencodingHeadOverflowWithStaticArrayCleanup
	- DirtyBytesArrayToStorage
	- DataLocationChangeInInternalOverride
	- NestedCalldataArrayAbiReencodingSizeValidation
	- SignedImmutables
	- ABIDecodeTwoDimensionalArrayMemory
	- KeccakCaching.
 It is used by:
	- lib/CMTAT/contracts/interfaces/ICMTATSnapshot.sol#3
	- lib/CMTAT/contracts/interfaces/draft-IERC1404/draft-IERC1404.sol#3
	- lib/CMTAT/contracts/interfaces/draft-IERC1404/draft-IERC1404Wrapper.sol#3
	- lib/CMTAT/contracts/interfaces/engine/IAuthorizationEngine.sol#3
	- lib/CMTAT/contracts/interfaces/engine/IRuleEngine.sol#3

 - [ ] ID-4
	Version constraint ^0.8.20 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess.
	 It is used by:
	- lib/CMTAT/contracts/libraries/Errors.sol#3
	- lib/CMTAT/contracts/modules/internal/EnforcementModuleInternal.sol#3
	- lib/CMTAT/contracts/modules/internal/ValidationModuleInternal.sol#3
	- lib/CMTAT/contracts/modules/security/AuthorizationModule.sol#3
	- lib/CMTAT/contracts/modules/wrapper/controllers/ValidationModule.sol#3
	- lib/CMTAT/contracts/modules/wrapper/core/EnforcementModule.sol#3
	- lib/CMTAT/contracts/modules/wrapper/core/PauseModule.sol#3
	- lib/CMTAT/contracts/modules/wrapper/extensions/MetaTxModule.sol#3
	- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol#4
	- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/metatx/ERC2771ContextUpgradeable.sol#4
	- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol#4
	- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol#4
	- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol#4
	- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol#4
	- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol#4
	- lib/CMTAT/openzeppelin-contracts-upgradeable/contracts/utils/introspection/ERC165Upgradeable.sol#4
	- lib/openzeppelin-contracts/contracts/access/IAccessControl.sol#4
	- lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol#3
	- lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#4
	- lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol#4
	- lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol#4
	- lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#4
	- lib/openzeppelin-contracts/contracts/utils/Address.sol#4
	- lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol#4
	- src/IncomeVault.sol#3
	- src/lib/IncomeVaultInternal.sol#3
	- src/lib/IncomeVaultInvariantStorage.sol#3
	- src/public/IncomeVaultOpen.sol#3
	- src/public/IncomeVaultRestricted.sol#3

## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-5
Variable [IncomeVaultInternal.CMTAT_TOKEN](src/lib/IncomeVaultInternal.sol#L13) is not in mixedCase

src/lib/IncomeVaultInternal.sol#L13


 - [ ] ID-6
Event [IncomeVaultInvariantStorage.newDeposit(uint256,address,uint256)](src/lib/IncomeVaultInvariantStorage.sol#L24) is not in CapWords

src/lib/IncomeVaultInvariantStorage.sol#L24


 - [ ] ID-7
Variable [IncomeVaultRestricted.__gap](src/public/IncomeVaultRestricted.sol#L102) is not in mixedCase

src/public/IncomeVaultRestricted.sol#L102


 - [ ] ID-8
Parameter [IncomeVault.__IncomeVault_init(address,IERC20,ICMTATSnapshot,IRuleEngine,IAuthorizationEngine).cmtat_token](src/IncomeVault.sol#L55) is not in mixedCase

src/IncomeVault.sol#L55


 - [ ] ID-9
Variable [IncomeVaultInternal.ERC20TokenPayment](src/lib/IncomeVaultInternal.sol#L14) is not in mixedCase

src/lib/IncomeVaultInternal.sol#L14


 - [ ] ID-10
Parameter [IncomeVault.initialize(address,IERC20,ICMTATSnapshot,IRuleEngine,IAuthorizationEngine).cmtat_token](src/IncomeVault.sol#L36) is not in mixedCase

src/IncomeVault.sol#L36


 - [ ] ID-11
Variable [IncomeVault.__gap](src/IncomeVault.sol#L112) is not in mixedCase

src/IncomeVault.sol#L112


 - [ ] ID-12
Parameter [IncomeVault.initialize(address,IERC20,ICMTATSnapshot,IRuleEngine,IAuthorizationEngine).ERC20TokenPayment_](src/IncomeVault.sol#L35) is not in mixedCase

src/IncomeVault.sol#L35


 - [ ] ID-13
Function [IncomeVault.__IncomeVault_init(address,IERC20,ICMTATSnapshot,IRuleEngine,IAuthorizationEngine)](src/IncomeVault.sol#L52-L79) is not in mixedCase

src/IncomeVault.sol#L52-L79


 - [ ] ID-14
Variable [IncomeVaultOpen.__gap](src/public/IncomeVaultOpen.sol#L73) is not in mixedCase

src/public/IncomeVaultOpen.sol#L73


 - [ ] ID-15
Parameter [IncomeVault.__IncomeVault_init(address,IERC20,ICMTATSnapshot,IRuleEngine,IAuthorizationEngine).ERC20TokenPayment_](src/IncomeVault.sol#L54) is not in mixedCase

src/IncomeVault.sol#L54

## unused-import

>  Concerns the CMTAT lib, will be fixed in the CMTAT lib.

Impact: Informational
Confidence: High

 - [ ] ID-16
The following unused import(s) in lib/CMTAT/contracts/modules/security/AuthorizationModule.sol should be removed: 
	-import "../../../openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol"; (lib/CMTAT/contracts/modules/security/AuthorizationModule.sol#6)

 - [ ] ID-17
The following unused import(s) in lib/CMTAT/contracts/modules/internal/ValidationModuleInternal.sol should be removed: 
	-import "../../interfaces/draft-IERC1404/draft-IERC1404Wrapper.sol"; (lib/CMTAT/contracts/modules/internal/ValidationModuleInternal.sol#7)

 - [ ] ID-18
The following unused import(s) in lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol should be removed: 
	-import {IERC20Permit} from "../extensions/IERC20Permit.sol"; (lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#7)

 - [ ] ID-19
The following unused import(s) in lib/CMTAT/contracts/modules/wrapper/core/PauseModule.sol should be removed: 
	-import "../../../../openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol"; (lib/CMTAT/contracts/modules/wrapper/core/PauseModule.sol#6)

 - [ ] ID-20
The following unused import(s) in lib/CMTAT/contracts/modules/wrapper/extensions/MetaTxModule.sol should be removed: 
	-import "../../../../openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol"; (lib/CMTAT/contracts/modules/wrapper/extensions/MetaTxModule.sol#6)

 - [ ] ID-21
	The following unused import(s) in lib/CMTAT/contracts/modules/wrapper/controllers/ValidationModule.sol should be removed: 
	-import "../../../../openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol"; (lib/CMTAT/contracts/modules/wrapper/controllers/ValidationModule.sol#5)

## unused-state

> Keep in case of inheritance

Impact: Informational
Confidence: High
 - [ ] ID-22
[IncomeVault.__gap](src/IncomeVault.sol#L112) is never used in [IncomeVault](src/IncomeVault.sol#L13-L113)

src/IncomeVault.sol#L112

