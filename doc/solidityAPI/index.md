# Solidity API

## IncomeVault

### constructor

```solidity
constructor(address forwarderIrrevocable) public
```

### initialize

```solidity
function initialize(address admin, contract IERC20 ERC20TokenPayment_, contract ICMTATSnapshot cmtat_token, contract IRuleEngine ruleEngine_, contract IAuthorizationEngine authorizationEngineIrrevocable, uint256 timeLimitToWithdraw_) public
```

@notice
initialize the proxy contract
The calls to this function will revert if the contract was deployed without a proxy

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| admin | address | Address of the contract (Access Control) |
| ERC20TokenPayment_ | contract IERC20 | ERC20 token to perform the payment |
| cmtat_token | contract ICMTATSnapshot |  |
| ruleEngine_ | contract IRuleEngine |  |
| authorizationEngineIrrevocable | contract IAuthorizationEngine |  |
| timeLimitToWithdraw_ | uint256 |  |

### __IncomeVault_init

```solidity
function __IncomeVault_init(address admin, contract IERC20 ERC20TokenPayment_, contract ICMTATSnapshot cmtat_token, contract IRuleEngine ruleEngine_, contract IAuthorizationEngine authorizationEngineIrrevocable, uint256 timeLimitToWithdraw_) internal
```

_calls the different initialize functions from the different modules_

### _msgSender

```solidity
function _msgSender() internal view returns (address sender)
```

_This surcharge is not necessary if you do not use the MetaTxModule_

### _msgData

```solidity
function _msgData() internal view returns (bytes)
```

_This surcharge is not necessary if you do not use the MetaTxModule_

### _contextSuffixLength

```solidity
function _contextSuffixLength() internal view returns (uint256)
```

## IncomeVaultInternal

### CMTAT_TOKEN

```solidity
contract ICMTATSnapshot CMTAT_TOKEN
```

### ERC20TokenPayment

```solidity
contract IERC20 ERC20TokenPayment
```

### claimedDividend

```solidity
mapping(address => mapping(uint256 => bool)) claimedDividend
```

### segregatedDividend

```solidity
mapping(uint256 => uint256) segregatedDividend
```

### segregatedClaim

```solidity
mapping(uint256 => bool) segregatedClaim
```

### timeLimitToWithdraw

```solidity
uint256 timeLimitToWithdraw
```

### _computeDividendBatch

```solidity
function _computeDividendBatch(uint256 time, address[] tokenHolders, uint256[] tokenHoldersBalance, uint256 tokenTotalSupply) internal view returns (uint256[] tokenHolderDividend)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | dividend time |
| tokenHolders | address[] | addresses to compute dividend |
| tokenHoldersBalance | uint256[] | the sender balance |
| tokenTotalSupply | uint256 | the total supply |

### _computeDividend

```solidity
function _computeDividend(uint256 time, uint256 senderBalance, uint256 tokenTotalSupply) internal view returns (uint256 tokenHolderDividend)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | dividend time |
| senderBalance | uint256 | token holder balance |
| tokenTotalSupply | uint256 | the total supply |

### _transferDividend

```solidity
function _transferDividend(uint256 time, address tokenHolder, uint256 tokenHolderDividend) internal
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | dividend time |
| tokenHolder | address | addresses to send the dividends |
| tokenHolderDividend | uint256 | the computed dividends |

## IncomeVaultInvariantStorage

### INCOME_VAULT_OPERATOR_ROLE

```solidity
bytes32 INCOME_VAULT_OPERATOR_ROLE
```

### INCOME_VAULT_DEPOSIT_ROLE

```solidity
bytes32 INCOME_VAULT_DEPOSIT_ROLE
```

### INCOME_VAULT_DISTRIBUTE_ROLE

```solidity
bytes32 INCOME_VAULT_DISTRIBUTE_ROLE
```

### INCOME_VAULT_WITHDRAW_ROLE

```solidity
bytes32 INCOME_VAULT_WITHDRAW_ROLE
```

### IncomeVault_ClaimNotActivated

```solidity
error IncomeVault_ClaimNotActivated()
```

### IncomeVault_DividendAlreadyClaimed

```solidity
error IncomeVault_DividendAlreadyClaimed()
```

### IncomeVault_NoDividendToClaim

```solidity
error IncomeVault_NoDividendToClaim()
```

### IncomeVault_AdminWithAddressZeroNotAllowed

```solidity
error IncomeVault_AdminWithAddressZeroNotAllowed()
```

### IncomeVault_TokenPaymentWithAddressZeroNotAllowed

```solidity
error IncomeVault_TokenPaymentWithAddressZeroNotAllowed()
```

### IncomeVault_CMTATWithAddressZeroNotAllowed

```solidity
error IncomeVault_CMTATWithAddressZeroNotAllowed()
```

### IncomeVault_FailApproval

```solidity
error IncomeVault_FailApproval()
```

### IncomeVault_NoAmountSend

```solidity
error IncomeVault_NoAmountSend()
```

### IncomeVault_NotEnoughAmount

```solidity
error IncomeVault_NotEnoughAmount()
```

### IncomeVault_TokenBalanceIsZero

```solidity
error IncomeVault_TokenBalanceIsZero()
```

### IncomeVault_TooLateToWithdraw

```solidity
error IncomeVault_TooLateToWithdraw(uint256 currentTime)
```

### IncomeVault_TooEarlyToWithdraw

```solidity
error IncomeVault_TooEarlyToWithdraw(uint256 currentTime)
```

### newDeposit

```solidity
event newDeposit(uint256 time, address sender, uint256 dividend)
```

### DividendClaimed

```solidity
event DividendClaimed(uint256 time, address sender, uint256 dividend)
```

## IncomeVaultOpen

### TIME_ERROR_CODE

```solidity
enum TIME_ERROR_CODE {
  OK,
  CLAIM_NOT_ACTIVATED,
  TOO_LATE_TO_WITHDRAW,
  TOO_EARLY_TO_WITHDRAW
}
```

### validateTimeCode

```solidity
function validateTimeCode(uint256 time) public view returns (enum IncomeVaultOpen.TIME_ERROR_CODE code)
```

validate if a time is valid, return 0 if valid

### validateTime

```solidity
function validateTime(uint256 time) public view
```

validate if a time is valid, revert if invalid

### validateTimeBatch

```solidity
function validateTimeBatch(uint256[] times) public view
```

batch version of {validateTime}

### claimDividend

```solidity
function claimDividend(uint256 time) public
```

claim your payment

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | provide the date where you want to receive your payment |

### claimDividendBatch

```solidity
function claimDividendBatch(uint256[] times) public
```

batch version of {claimDividend}

_Don't check if the dividends have been already claimed before external call to CMTAT._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| times | uint256[] | provide the dates where you want to receive your payment |

## IncomeVaultRestricted

### __IncomeVaultRestricted_init_unchained

```solidity
function __IncomeVaultRestricted_init_unchained(uint256 timeLimitToWithdraw_) internal
```

_calls the different initialize functions from the different modules_

### deposit

```solidity
function deposit(uint256 time, uint256 amount) public
```

deposit an amount to pay the dividends.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | provide the date where you want to perform a deposit |
| amount | uint256 | the amount to deposit |

### withdraw

```solidity
function withdraw(uint256 time, uint256 amount, address withdrawAddress) public
```

withdraw a certain amount at a specified time.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | provide the date where you want to perform a deposit |
| amount | uint256 | the amount to withdraw |
| withdrawAddress | address | address to receive `amount`of tokens |

### withdrawAll

```solidity
function withdrawAll(uint256 amount, address withdrawAddress) public
```

withdraw all tokens from ERC20TokenPayment contracts deposited

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | the amount to withdraw |
| withdrawAddress | address | address to receive `amount`of tokens |

### distributeDividend

```solidity
function distributeDividend(address[] addresses, uint256 time) public
```

distribute the dividends

_The dividends are distributed only if they have not yet been claimed by the token holder_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| addresses | address[] | compute and transfer dividend for these holders |
| time | uint256 | dividend time |

### setStatusClaim

```solidity
function setStatusClaim(uint256 time, bool status) public
```

set the status to open or close the claims for a given time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | target time |
| status | bool | boolean (true or false) |

### setTimeLimitToWithdraw

```solidity
function setTimeLimitToWithdraw(uint256 timeLimitToWithdraw_) public
```

configure the time limit to withdraw

