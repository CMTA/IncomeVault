**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [dead-code](#dead-code) (1 results) (Informational)
 - [solc-version](#solc-version) (3 results) (Informational)
 - [naming-convention](#naming-convention) (5 results) (Informational)
 - [unused-state](#unused-state) (1 results) (Informational)
## dead-code
Impact: Informational
Confidence: Medium
 - [ ] ID-0
[debtVault._msgData()](src/distributionModule.sol#L162-L169) is never used and should be removed

src/distributionModule.sol#L162-L169


## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-1
solc-0.8.20 is not recommended for deployment

 - [ ] ID-2
Pragma version[^0.8.20](src/modules/MetaTxModuleStandalone.sol#L3) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/modules/MetaTxModuleStandalone.sol#L3


 - [ ] ID-3
Pragma version[^0.8.20](src/distributionModule.sol#L3) necessitates a version too recent to be trusted. Consider deploying with 0.8.18.

src/distributionModule.sol#L3


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-4
Parameter [debtVault.setTokenCMTAT(CMTAT_BASE).cmtat_token](src/distributionModule.sol#L141) is not in mixedCase

src/distributionModule.sol#L141


 - [ ] ID-5
Variable [debtVault.CMTAT_TOKEN](src/distributionModule.sol#L34) is not in mixedCase

src/distributionModule.sol#L34


 - [ ] ID-6
Variable [debtVault.ERC20TokenPayment](src/distributionModule.sol#L37) is not in mixedCase

src/distributionModule.sol#L37


 - [ ] ID-7
Contract [debtVault](src/distributionModule.sol#L17-L176) is not in CapWords

src/distributionModule.sol#L17-L176


 - [ ] ID-8
Parameter [debtVault.setTokenPayment(IERC20).ERC20TokenPayment_](src/distributionModule.sol#L135) is not in mixedCase

src/distributionModule.sol#L135


## unused-state
Impact: Informational
Confidence: High
 - [ ] ID-9
[debtVault.POINTS_MULTIPLIER](src/distributionModule.sol#L36) is never used in [debtVault](src/distributionModule.sol#L17-L176)

src/distributionModule.sol#L36


