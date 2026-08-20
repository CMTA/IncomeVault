# Solidity API

## IncomeVaultBase

### __IncomeVaultBase_init_unchained

```solidity
function __IncomeVaultBase_init_unchained(contract IERC20 ERC20TokenPayment_, contract ISnapshotSource snapshotSource_, uint256 timeLimitToWithdraw_) internal
```

_calls the initialize functions of the policy-agnostic modules_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ERC20TokenPayment_ | contract IERC20 | ERC20 token used to perform the payment |
| snapshotSource_ | contract ISnapshotSource | contract implementing {ISnapshotSource}, source of the holder balances |
| timeLimitToWithdraw_ | uint256 | delay, after the dividend time, during which a claim is accepted |

## IncomeVaultBaseERC2771

### constructor

```solidity
constructor(address forwarderIrrevocable) internal
```

### _msgSender

```solidity
function _msgSender() internal view virtual returns (address sender)
```

_Resolves the {ERC2771ContextUpgradeable} / {ContextUpgradeable} diamond in favour of the
ERC-2771 answer, so a forwarded call is attributed to the original sender._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | the forwarded sender when the call came through the trusted forwarder |

### _msgData

```solidity
function _msgData() internal view virtual returns (bytes)
```

_Resolves the same diamond for the calldata, stripping the appended sender suffix._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes | The calldata with the ERC-2771 suffix removed |

### _contextSuffixLength

```solidity
function _contextSuffixLength() internal view virtual returns (uint256)
```

_Resolves the same diamond for the length of that suffix._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The number of trailing calldata bytes carrying the forwarded sender |

## IncomeVault

### constructor

```solidity
constructor(address forwarderIrrevocable) public
```

### initialize

```solidity
function initialize(address admin, contract IERC20 ERC20TokenPayment_, contract ISnapshotSource snapshotSource_, contract IRuleEngine ruleEngine_, uint256 timeLimitToWithdraw_) public
```

@notice
initialize the proxy contract
The calls to this function will revert if the contract was deployed without a proxy

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| admin | address | Address of the contract (Access Control) |
| ERC20TokenPayment_ | contract IERC20 | ERC20 token used to perform the payment |
| snapshotSource_ | contract ISnapshotSource | contract implementing {ISnapshotSource}, source of the holder balances |
| ruleEngine_ | contract IRuleEngine | optional RuleEngine applied to the payouts, or the zero address |
| timeLimitToWithdraw_ | uint256 | delay, after the dividend time, during which a claim is accepted |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool)
```

ERC-165 interface detection

_Adds ERC-7741, whose specification requires a contract implementing it to answer `true`
for `0xa9e50872`. The ERC-7540 operator id is deliberately **not** advertised — this is not an
asynchronous vault; see {IERC7540Operator}._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| interfaceId | bytes4 | The interface identifier to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True if the interface is supported, false otherwise |

### _msgSender

```solidity
function _msgSender() internal view virtual returns (address sender)
```

_Resolves the {ERC2771ContextUpgradeable} / {ContextUpgradeable} diamond in favour of the
ERC-2771 answer, so a forwarded call is attributed to the original sender._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | the forwarded sender when the call came through the trusted forwarder |

### _msgData

```solidity
function _msgData() internal view virtual returns (bytes)
```

_Resolves the same diamond for the calldata, stripping the appended sender suffix._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes | The calldata with the ERC-2771 suffix removed |

### _contextSuffixLength

```solidity
function _contextSuffixLength() internal view virtual returns (uint256)
```

_Resolves the same diamond for the length of that suffix._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The number of trailing calldata bytes carrying the forwarded sender |

### _authorizeDeposit

```solidity
function _authorizeDeposit() internal view virtual
```

_Authorization hook invoked before a deposit.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeWithdraw

```solidity
function _authorizeWithdraw() internal view virtual
```

_Authorization hook invoked before {withdraw} and {withdrawAll}.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeDistribute

```solidity
function _authorizeDistribute() internal view virtual
```

_Authorization hook invoked before {distributeDividend}.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeOperator

```solidity
function _authorizeOperator() internal view virtual
```

_Authorization hook invoked before {setStatusClaim} and {setTimeLimitToWithdraw}.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeSnapshotSourceManagement

```solidity
function _authorizeSnapshotSourceManagement() internal view virtual
```

_Authorization hook invoked before {setDividendSnapshotSource}.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeRuleEngineManagement

```solidity
function _authorizeRuleEngineManagement() internal view virtual
```

_Authorization hook invoked before {setRuleEngine}.
Implemented by the deployment contract with the desired access-control policy.

CMTAT's {ValidationModuleRuleEngine} declares a hook with this same name and parameters.
That is **not** a collision to be renamed away: both this module and CMTAT's wrapper sit on the
same {ValidationModuleRuleEngineInternal}, whose ERC-7201 slot is a hardcoded constant, so a
contract inheriting both has exactly **one** RuleEngine. One capability, therefore one hook — and
a single override answering both declarations is the correct resolution, not an accident. Giving
the two hooks different names would create two doors to one slot, each able to carry a different
policy, and the weaker one would win. See finding M-4._

### _authorizePause

```solidity
function _authorizePause() internal view virtual
```

### _authorizeDeactivate

```solidity
function _authorizeDeactivate() internal view virtual
```

### _authorizeFreeze

```solidity
function _authorizeFreeze() internal view virtual
```

## IncomeVaultOwnable2Step

### constructor

```solidity
constructor(address forwarderIrrevocable) public
```

### initialize

```solidity
function initialize(address owner_, contract IERC20 ERC20TokenPayment_, contract ISnapshotSource snapshotSource_, contract IRuleEngine ruleEngine_, uint256 timeLimitToWithdraw_) public
```

@notice
initialize the proxy contract
The calls to this function will revert if the contract was deployed without a proxy

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| owner_ | address | Address of the initial contract owner (ERC-173) |
| ERC20TokenPayment_ | contract IERC20 | ERC20 token used to perform the payment |
| snapshotSource_ | contract ISnapshotSource | contract implementing {ISnapshotSource}, source of the holder balances |
| ruleEngine_ | contract IRuleEngine | optional RuleEngine applied to the payouts, or the zero address |
| timeLimitToWithdraw_ | uint256 | delay, after the dividend time, during which a claim is accepted |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool)
```

ERC-165 interface detection

_Adds ERC-7741, whose specification requires a contract implementing it to answer `true`
for `0xa9e50872`._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| interfaceId | bytes4 | The interface identifier to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True if the interface is supported, false otherwise |

### _msgSender

```solidity
function _msgSender() internal view virtual returns (address sender)
```

_Resolves the {ERC2771ContextUpgradeable} / {ContextUpgradeable} diamond in favour of the
ERC-2771 answer, so a forwarded call is attributed to the original sender._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | the forwarded sender when the call came through the trusted forwarder |

### _msgData

```solidity
function _msgData() internal view virtual returns (bytes)
```

_Resolves the same diamond for the calldata, stripping the appended sender suffix._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes | The calldata with the ERC-2771 suffix removed |

### _contextSuffixLength

```solidity
function _contextSuffixLength() internal view virtual returns (uint256)
```

_Resolves the same diamond for the length of that suffix._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The number of trailing calldata bytes carrying the forwarded sender |

### _authorizeDeposit

```solidity
function _authorizeDeposit() internal view virtual
```

_Authorization hook invoked before a deposit.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeWithdraw

```solidity
function _authorizeWithdraw() internal view virtual
```

_Authorization hook invoked before {withdraw} and {withdrawAll}.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeDistribute

```solidity
function _authorizeDistribute() internal view virtual
```

_Authorization hook invoked before {distributeDividend}.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeOperator

```solidity
function _authorizeOperator() internal view virtual
```

_Authorization hook invoked before {setStatusClaim} and {setTimeLimitToWithdraw}.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeSnapshotSourceManagement

```solidity
function _authorizeSnapshotSourceManagement() internal view virtual
```

_Authorization hook invoked before {setDividendSnapshotSource}.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeRuleEngineManagement

```solidity
function _authorizeRuleEngineManagement() internal view virtual
```

_Authorization hook invoked before {setRuleEngine}.
Implemented by the deployment contract with the desired access-control policy.

CMTAT's {ValidationModuleRuleEngine} declares a hook with this same name and parameters.
That is **not** a collision to be renamed away: both this module and CMTAT's wrapper sit on the
same {ValidationModuleRuleEngineInternal}, whose ERC-7201 slot is a hardcoded constant, so a
contract inheriting both has exactly **one** RuleEngine. One capability, therefore one hook — and
a single override answering both declarations is the correct resolution, not an accident. Giving
the two hooks different names would create two doors to one slot, each able to carry a different
policy, and the weaker one would win. See finding M-4._

### _authorizePause

```solidity
function _authorizePause() internal view virtual
```

### _authorizeDeactivate

```solidity
function _authorizeDeactivate() internal view virtual
```

### _authorizeFreeze

```solidity
function _authorizeFreeze() internal view virtual
```

## IERC7540Operator

The operator subset of [ERC-7540](https://eips.ethereum.org/EIPS/eip-7540), verbatim.
@dev
ERC-7540 defines asynchronous ERC-4626 vaults. The {IncomeVault} is **not** one — see
"Comparison with ERC-4626 / ERC-7540 vaults" in `doc/README.md` — but its claim delegation is
exactly the operator mechanism that standard specifies, so the signatures are reused rather than
invented. A custodian or wallet already written against ERC-7540 operators works here unchanged.

ERC-7540 assigns this subset the ERC-165 identifier **`0xe3bc4e65`**, described there as
"the operator methods that all ERC-7540 Vaults implement". Because this interface inherits nothing,
`type(IERC7540Operator).interfaceId` is exactly the XOR of the two selectors below and equals that
value — asserted in `test/Operator.t.sol`, which is what pins these signatures to the standard.

### OperatorSet

```solidity
event OperatorSet(address controller, address operator, bool approved)
```

The `controller` has set the `approved` status to an `operator`.

_MUST be logged when the operator status is set._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| controller | address | the account granting or revoking |
| operator | address | the account being granted or revoked |
| approved | bool | the status that was set |

### setOperator

```solidity
function setOperator(address operator, bool approved) external returns (bool success)
```

Grants or revokes permissions for `operator` to manage Requests on behalf of the `msg.sender`.

_MUST set the operator status to the `approved` value, MUST log the {OperatorSet} event and
MUST return true._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| operator | address | the account to grant or revoke |
| approved | bool | true to grant, false to revoke |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| success | bool | MUST be true |

### isOperator

```solidity
function isOperator(address controller, address operator) external view returns (bool status)
```

Returns `true` if the `operator` is approved as an operator for a `controller`.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| controller | address | the account that may have granted |
| operator | address | the account that may have been granted |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| status | bool | true when `operator` is approved for `controller` |

## IERC7741

[ERC-7741](https://eips.ethereum.org/EIPS/eip-7741) — signed operator authorisation.
@dev
Lets a holder grant or revoke an operator with an EIP-712 signature instead of a transaction, so a
custodian or relayer can submit the authorisation and pay the gas. It complements
{IERC7540Operator}, whose `setOperator` requires the holder to transact.

The standard assigns this interface the ERC-165 identifier **`0xa9e50872`**. It inherits nothing,
so `type(IERC7741).interfaceId` is the XOR of the four selectors below and equals that value —
asserted in `test/OperatorAuthorization.t.sol`.

### authorizeOperator

```solidity
function authorizeOperator(address controller, address operator, bool approved, bytes32 nonce, uint256 deadline, bytes signature) external returns (bool success)
```

Grants or revokes permissions for `operator`, authorised by an EIP-712 signature.

_MUST revert if `deadline` has passed, if the nonce was already used, or if the signature
is invalid. MUST invalidate the nonce, MUST log `OperatorSet` and MUST return true._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| controller | address | the holder whose signature authorises the change |
| operator | address | the account being granted or revoked |
| approved | bool | true to grant, false to revoke |
| nonce | bytes32 | an unordered, single-use value chosen by the signer |
| deadline | uint256 | the timestamp after which the signature is no longer valid |
| signature | bytes | the EIP-712 signature, ECDSA or ERC-1271 |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| success | bool | MUST be true |

### invalidateNonce

```solidity
function invalidateNonce(bytes32 nonce) external
```

Revokes the given `nonce` for `msg.sender`, so a signature using it can never be used.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nonce | bytes32 | the nonce to burn |

### authorizations

```solidity
function authorizations(address controller, bytes32 nonce) external view returns (bool used)
```

Returns whether the given `nonce` has been used for the `controller`.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| controller | address | the holder the nonce belongs to |
| nonce | bytes32 | the nonce to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| used | bool | true when the nonce has been spent or invalidated |

### DOMAIN_SEPARATOR

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32)
```

The EIP-712 domain separator of this contract.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | The domain separator, unique to this contract and chain |

## IIncomeVault

### TIME_ERROR_CODE

Why a dividend time is not claimable, or `OK`

_Declared here rather than in the implementation because it is part of the stated API:
{validateTimeCode} returns it. Both the holder-driven claims ({IncomeVaultOpen}) and the
issuer-driven distribution ({IncomeVaultRestricted}) apply the same window through it._

```solidity
enum TIME_ERROR_CODE {
  OK,
  CLAIM_NOT_ACTIVATED,
  TOO_LATE_TO_WITHDRAW,
  TOO_EARLY_TO_WITHDRAW
}
```

### claimDividend

```solidity
function claimDividend(uint256 time) external
```

Claim the caller's dividends for one distribution date

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time identifying the distribution |

### claimDividendFor

```solidity
function claimDividendFor(address holder, uint256 time) external
```

Claim `holder`'s dividends for one distribution date, as the holder or their operator

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | address | the token holder the dividends are paid to |
| time | uint256 | the dividend time identifying the distribution |

### claimDividendBatch

```solidity
function claimDividendBatch(uint256[] times) external
```

Claim the caller's dividends for several distribution dates

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| times | uint256[] | the dividend times to claim |

### claimDividendBatchFor

```solidity
function claimDividendBatchFor(address holder, uint256[] times) external
```

Claim `holder`'s dividends for several dates, as the holder or their operator

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | address | the token holder the dividends are paid to |
| times | uint256[] | the dividend times to claim |

### deposit

```solidity
function deposit(uint256 time, uint256 amount) external
```

Deposit the payment token for one distribution date

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time the deposit is segregated under |
| amount | uint256 | the amount of payment token to deposit |

### depositBatch

```solidity
function depositBatch(uint256[] times, uint256[] amounts) external
```

Deposit the payment token for several distribution dates in one call

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| times | uint256[] | the dividend times to deposit for |
| amounts | uint256[] | the amount to deposit for each time, index for index |

### withdraw

```solidity
function withdraw(uint256 time, uint256 amount, address withdrawAddress) external
```

Recover unclaimed payment token from one distribution date

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time to withdraw from |
| amount | uint256 | the amount of payment token to withdraw |
| withdrawAddress | address | the recipient of the withdrawn funds |

### withdrawAll

```solidity
function withdrawAll(uint256 amount, address withdrawAddress) external
```

Recover payment token held by the contract without naming a distribution date

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | the amount of payment token to withdraw |
| withdrawAddress | address | the recipient of the withdrawn funds |

### distributeDividend

```solidity
function distributeDividend(address[] addresses, uint256 time) external
```

Pay several holders their dividends for one date, reverting if any payout is refused

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| addresses | address[] | the token holders to pay |
| time | uint256 | the dividend time identifying the distribution |

### distributeDividendBestEffort

```solidity
function distributeDividendBestEffort(address[] addresses, uint256 time) external returns (uint256 paidCount, address[] skipped)
```

Pay several holders for one date, skipping the refused payouts instead of reverting

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| addresses | address[] | the token holders to pay |
| time | uint256 | the dividend time identifying the distribution |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| paidCount | uint256 | how many holders were actually paid |
| skipped | address[] | the holders whose payout was refused |

### setStatusClaim

```solidity
function setStatusClaim(uint256 time, bool status) external
```

Open or close claiming for one distribution date

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |
| status | bool | true to let holders claim, false to close the period |

### setTimeLimitToWithdraw

```solidity
function setTimeLimitToWithdraw(uint256 timeLimitToWithdraw_) external
```

Set how long after a dividend time a claim is still accepted

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| timeLimitToWithdraw_ | uint256 | the length of the claim window, in seconds |

### validateTime

```solidity
function validateTime(uint256 time) external view
```

Reverts unless a claim for `time` would be accepted right now

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time to check |

### validateTimeBatch

```solidity
function validateTimeBatch(uint256[] times) external view
```

Reverts unless a claim for every one of `times` would be accepted right now

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| times | uint256[] | the dividend times to check |

### validateTimeCode

```solidity
function validateTimeCode(uint256 time) external view returns (enum IIncomeVault.TIME_ERROR_CODE code)
```

Why a claim for `time` would be refused, without reverting

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| code | enum IIncomeVault.TIME_ERROR_CODE | the reason, or the no-error member when the claim would be accepted |

### ERC20TokenPayment

```solidity
function ERC20TokenPayment() external view returns (contract IERC20)
```

The ERC-20 the dividends are paid in

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | contract IERC20 | The payment token |

### claimedDividend

```solidity
function claimedDividend(address tokenHolder, uint256 time) external view returns (bool)
```

Whether a holder has already claimed a given distribution

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenHolder | address | the holder to look up |
| time | uint256 | the dividend time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True once the holder has been paid for `time` |

### segregatedDividend

```solidity
function segregatedDividend(uint256 time) external view returns (uint256)
```

The total deposited for a distribution date. This is the pro-rata denominator and is
never reduced by a payout — see {unclaimedDividend} for what the period still holds.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The amount deposited for `time` |

### segregatedClaim

```solidity
function segregatedClaim(uint256 time) external view returns (bool)
```

Whether claiming is open for a distribution date

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True when holders may claim for `time` |

### paidDividend

```solidity
function paidDividend(uint256 time) external view returns (uint256)
```

How much of a date's deposit has already been paid out

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The amount already paid for `time` |

### unclaimedDividend

```solidity
function unclaimedDividend(uint256 time) external view returns (uint256)
```

How much of a date's deposit the contract still holds

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | `segregatedDividend(time) - paidDividend(time)`, saturating at zero |

### openClaimCount

```solidity
function openClaimCount() external view returns (uint256)
```

How many distribution dates currently have claiming open

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The number of open claim periods |

### timeLimitToWithdraw

```solidity
function timeLimitToWithdraw() external view returns (uint256)
```

How long after a dividend time a claim is still accepted

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The claim window length, in seconds |

## ISnapshotSource

The read surface the {IncomeVault} needs from a snapshot provider — nothing more.
@dev
This is the **minimum** a contract must expose to be usable as the vault's snapshot source. It is a
strict subset of `ISnapshotState` (defined by the CMTA
[SnapshotEngine](https://github.com/CMTA/SnapshotEngine)), which declares eight functions where the
vault calls three; the five it does not call describe balances and supplies the vault never reads.

The signatures are copied verbatim from `ISnapshotState`, so **every `ISnapshotState`
implementation already satisfies this interface** — the `SnapshotEngine`, a token embedding the
snapshot modules, or a custom provider. Solidity has no implicit conversion between unrelated
interfaces, so pass one with an explicit cast: `ISnapshotSource(address(engine))`.

### snapshotInfo

```solidity
function snapshotInfo(uint256 time, address tokenHolder) external view returns (uint256 tokenHolderBalance, uint256 totalSupply)
```

Retrieve both an account's balance and the total supply at the snapshot for a given timestamp in a single call.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | The timestamp identifying the snapshot to query. |
| tokenHolder | address | The address whose balance is being requested. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenHolderBalance | uint256 | The recorded balance of the tokenHolder at the snapshot (or current balance if no snapshot). |
| totalSupply | uint256 | The recorded total supply at the snapshot (or current total supply if no snapshot). |

### snapshotInfoBatch

```solidity
function snapshotInfoBatch(uint256 time, address[] addresses) external view returns (uint256[] tokenHolderBalances, uint256 totalSupply)
```

Retrieve the balances of multiple accounts and the total supply at the snapshot for a given timestamp in a single call.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | The timestamp identifying the snapshot to query. |
| addresses | address[] | The array of addresses to query balances for. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenHolderBalances | uint256[] | An array containing each address's balance at the snapshot (or current balance if no snapshot). |
| totalSupply | uint256 | The recorded total supply at the snapshot (or current total supply if no snapshot). |

### snapshotInfoBatch

```solidity
function snapshotInfoBatch(uint256[] times, address[] addresses) external view returns (uint256[][] tokenHolderBalances, uint256[] totalSupplies)
```

Retrieve balances of multiple accounts at multiple snapshots, as well as the total supply at each snapshot.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| times | uint256[] | An array of timestamps identifying each snapshot to query. |
| addresses | address[] | The array of addresses to query balances for at each snapshot. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenHolderBalances | uint256[][] | A 2D array where each row corresponds to the balances of all provided addresses at a given snapshot time. |
| totalSupplies | uint256[] | An array containing the total supply at each snapshot time (or current supply if no snapshot). |

## ERC7741Module

### AUTHORIZE_OPERATOR_TYPEHASH

```solidity
bytes32 AUTHORIZE_OPERATOR_TYPEHASH
```

EIP-712 type hash of the authorisation message, exactly as ERC-7741 defines it

### ERC7741ModuleStorage

```solidity
struct ERC7741ModuleStorage {
  mapping(address => mapping(bytes32 => bool)) _authorizations;
}
```

### IncomeVault_AuthorizationExpired

```solidity
error IncomeVault_AuthorizationExpired(uint256 deadline)
```

Thrown when the signature's deadline has passed.

### IncomeVault_AuthorizationUsed

```solidity
error IncomeVault_AuthorizationUsed(address controller, bytes32 nonce)
```

Thrown when the nonce was already spent or invalidated.

### IncomeVault_InvalidAuthorization

```solidity
error IncomeVault_InvalidAuthorization(address controller)
```

Thrown when the signature does not recover to `controller`.

### IncomeVault_ControllerWithAddressZeroNotAllowed

```solidity
error IncomeVault_ControllerWithAddressZeroNotAllowed()
```

Thrown when the controller is the zero address.

### authorizeOperator

```solidity
function authorizeOperator(address controller, address operator, bool approved, bytes32 nonce, uint256 deadline, bytes signature) public virtual returns (bool success)
```

Grants or revokes permissions for `operator`, authorised by an EIP-712 signature.

_MUST revert if `deadline` has passed, if the nonce was already used, or if the signature
is invalid. MUST invalidate the nonce, MUST log `OperatorSet` and MUST return true._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| controller | address | the holder whose signature authorises the change |
| operator | address | the account being granted or revoked |
| approved | bool | true to grant, false to revoke |
| nonce | bytes32 | an unordered, single-use value chosen by the signer |
| deadline | uint256 | the timestamp after which the signature is no longer valid |
| signature | bytes | the EIP-712 signature, ECDSA or ERC-1271 |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| success | bool | MUST be true |

### invalidateNonce

```solidity
function invalidateNonce(bytes32 nonce) public virtual
```

Revokes the given `nonce` for `msg.sender`, so a signature using it can never be used.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nonce | bytes32 | the nonce to burn |

### authorizations

```solidity
function authorizations(address controller, bytes32 nonce) public view virtual returns (bool used)
```

Returns whether the given `nonce` has been used for the `controller`.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| controller | address | the holder the nonce belongs to |
| nonce | bytes32 | the nonce to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| used | bool | true when the nonce has been spent or invalidated |

### DOMAIN_SEPARATOR

```solidity
function DOMAIN_SEPARATOR() public view virtual returns (bytes32)
```

The EIP-712 domain separator of this contract.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | The domain separator, unique to this contract and chain |

### _getERC7741ModuleStorage

```solidity
function _getERC7741ModuleStorage() internal pure returns (struct ERC7741Module.ERC7741ModuleStorage $)
```

_Returns the ERC-7201 namespaced storage of this module_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| $ | struct ERC7741Module.ERC7741ModuleStorage | the storage struct |

## IncomeVaultInternal

### IncomeVaultInternalStorage

```solidity
struct IncomeVaultInternalStorage {
  contract IERC20 _ERC20TokenPayment;
  mapping(address => mapping(uint256 => bool)) _claimedDividend;
  mapping(uint256 => uint256) _segregatedDividend;
  mapping(uint256 => bool) _segregatedClaim;
  uint256 _timeLimitToWithdraw;
  uint256 _openClaimCount;
  mapping(uint256 => uint256) _paidDividend;
}
```

### ERC20TokenPayment

```solidity
function ERC20TokenPayment() public view virtual returns (contract IERC20)
```

ERC-20 token used to pay the dividends

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | contract IERC20 | The payment token |

### claimedDividend

```solidity
function claimedDividend(address tokenHolder, uint256 time) public view virtual returns (bool)
```

Tells whether a token holder already claimed the dividends of a given time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenHolder | address | the address to check |
| time | uint256 | the dividend time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True if the dividends were already claimed or distributed |

### segregatedDividend

```solidity
function segregatedDividend(uint256 time) public view virtual returns (uint256)
```

Total amount of payment token deposited for a given dividend time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The amount deposited, minus what was already withdrawn |

### segregatedClaim

```solidity
function segregatedClaim(uint256 time) public view virtual returns (bool)
```

Claim status of a given dividend time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True when the token holders can claim their dividends |

### paidDividend

```solidity
function paidDividend(uint256 time) public view virtual returns (uint256)
```

Total already paid out for a dividend time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The amount of payment token already transferred to holders for `time` |

### unclaimedDividend

```solidity
function unclaimedDividend(uint256 time) public view virtual returns (uint256)
```

What is still held for a dividend time — the deposit minus what has been paid out
@dev
This is the amount an issuer can sweep with {IncomeVaultRestricted-withdraw}, and it is the bound
that function enforces. `segregatedDividend` alone is **not** that amount: it is the pro-rata
denominator and stays fixed at the deposit even after holders are paid.

After the claim window closes it is exactly the rounding dust plus anything unclaimed. Before it
closes it still includes what the remaining holders are entitled to, so sweeping early takes
money they can no longer be paid — see the note on {IncomeVaultRestricted-withdraw}.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The amount of payment token still attributable to `time` |

### openClaimCount

```solidity
function openClaimCount() public view virtual returns (uint256)
```

How many dividend times currently have their claims open

_Maintained exactly by {_setStatusClaim}, the only writer of the claim status. Used by
{IncomeVaultSnapshotModule-setDividendSnapshotSource}, which refuses to change the snapshot source while any
period is open._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The number of open claim periods |

### timeLimitToWithdraw

```solidity
function timeLimitToWithdraw() public view virtual returns (uint256)
```

Delay, after the dividend time, during which a claim is still accepted

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The delay in seconds |

### _transferDividend

```solidity
function _transferDividend(uint256 time, address tokenHolder, uint256 tokenHolderDividend) internal
```

Records the claim then sends the dividends to the token holder

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | dividend time |
| tokenHolder | address | addresses to send the dividends |
| tokenHolderDividend | uint256 | the computed dividends |

### _setERC20TokenPayment

```solidity
function _setERC20TokenPayment(contract IERC20 ERC20TokenPayment_) internal virtual
```

Sets the ERC-20 token used to pay the dividends

_reverts if `ERC20TokenPayment_` is the zero address_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ERC20TokenPayment_ | contract IERC20 | the payment token |

### _setTimeLimitToWithdraw

```solidity
function _setTimeLimitToWithdraw(uint256 timeLimitToWithdraw_) internal virtual
```

Sets the delay, after the dividend time, during which a claim is still accepted

_reverts if `timeLimitToWithdraw_` is zero — see {IncomeVault_TimeLimitToWithdrawZeroNotAllowed}_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| timeLimitToWithdraw_ | uint256 | the delay in seconds, must be greater than zero |

### _setStatusClaim

```solidity
function _setStatusClaim(uint256 time, bool status) internal virtual
```

Opens or closes the claims for a dividend time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |
| status | bool | true when the token holders can claim |

### _computeDividendBatch

```solidity
function _computeDividendBatch(uint256 time, address[] tokenHolders, uint256[] tokenHoldersBalance, uint256 tokenTotalSupply) internal view returns (uint256[] tokenHolderDividend)
```

Computes the dividends owed to several token holders for a given time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | dividend time |
| tokenHolders | address[] | addresses to compute dividend |
| tokenHoldersBalance | uint256[] | the sender balance |
| tokenTotalSupply | uint256 | the total supply |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenHolderDividend | uint256[] | the dividends owed to each address of `tokenHolders` |

### _computeDividend

```solidity
function _computeDividend(uint256 time, uint256 senderBalance, uint256 tokenTotalSupply) internal view returns (uint256 tokenHolderDividend)
```

Computes the dividends owed to a single token holder for a given time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | dividend time |
| senderBalance | uint256 | token holder balance |
| tokenTotalSupply | uint256 | the total supply |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenHolderDividend | uint256 | the dividends owed to the token holder, rounded down |

### _revertOnInvalidTime

```solidity
function _revertOnInvalidTime(enum IIncomeVault.TIME_ERROR_CODE code) internal view virtual
```

_reverts with the error matching a non-OK {TIME_ERROR_CODE}. Exhaustive over the enum, and
fails closed on an unhandled value — see the comment on the final branch._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| code | enum IIncomeVault.TIME_ERROR_CODE | the code returned by {_timeCode} |

### _timeCode

```solidity
function _timeCode(struct IncomeVaultInternal.IncomeVaultInternalStorage $, uint256 time, uint256 timeLimit) internal view virtual returns (enum IIncomeVault.TIME_ERROR_CODE code)
```

_{validateTimeCode} with the caller supplying the storage pointer and the withdraw limit,
so a batch can read the limit once instead of once per element._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| $ | struct IncomeVaultInternal.IncomeVaultInternalStorage | the ERC-7201 storage of the vault |
| time | uint256 | the dividend time to check |
| timeLimit | uint256 | the value of `timeLimitToWithdraw` |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| code | enum IIncomeVault.TIME_ERROR_CODE | the reason the time is invalid, or `TIME_ERROR_CODE.OK` |

### _getIncomeVaultInternalStorage

```solidity
function _getIncomeVaultInternalStorage() internal pure returns (struct IncomeVaultInternal.IncomeVaultInternalStorage $)
```

_Returns the ERC-7201 namespaced storage of the IncomeVault_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| $ | struct IncomeVaultInternal.IncomeVaultInternalStorage | the storage struct |

## IncomeVaultOperatorModule

### OperatorStorage

```solidity
struct OperatorStorage {
  mapping(address => mapping(address => bool)) _isOperator;
}
```

### setOperator

```solidity
function setOperator(address operator, bool approved) public virtual returns (bool)
```

Grants or revokes permissions for `operator` to manage Requests on behalf of the `msg.sender`.

_Permissionless on purpose: a holder authorises their own operator, so there is no role to
check. The authorisation only lets the operator trigger a claim; the payout still goes to the
holder. {ERC7741Module-authorizeOperator} is the signed equivalent for a holder who cannot send
the transaction themselves._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| operator | address | the account to grant or revoke |
| approved | bool | true to grant, false to revoke |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool |  |

### isOperator

```solidity
function isOperator(address controller, address operator) public view virtual returns (bool)
```

Returns `true` if the `operator` is approved as an operator for a `controller`.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| controller | address | the account that may have granted |
| operator | address | the account that may have been granted |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool |  |

### _setOperator

```solidity
function _setOperator(address controller, address operator, bool approved) internal virtual
```

_Records an authorisation and emits the ERC-7540 event. The only writer of the mapping._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| controller | address | the holder granting or revoking the authorisation |
| operator | address | the address being authorised |
| approved | bool | true to authorise, false to revoke |

### _requireHolderOrOperator

```solidity
function _requireHolderOrOperator(address holder) internal view virtual
```

_Reverts unless the caller is `holder` or an operator `holder` authorised_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | address | the token holder being claimed for |

### _getOperatorStorage

```solidity
function _getOperatorStorage() internal pure returns (struct IncomeVaultOperatorModule.OperatorStorage $)
```

_Returns the ERC-7201 namespaced storage of this module_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| $ | struct IncomeVaultOperatorModule.OperatorStorage | the storage struct |

## IncomeVaultSnapshotCore

### _snapshotInfo

```solidity
function _snapshotInfo(uint256 time, address tokenHolder) internal view virtual returns (uint256 tokenHolderBalance, uint256 totalSupply)
```

_Balance of one holder and the total supply, at `time`_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |
| tokenHolder | address | the holder to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenHolderBalance | uint256 | the holder's recorded balance |
| totalSupply | uint256 | the recorded total supply |

### _snapshotInfoBatch

```solidity
function _snapshotInfoBatch(uint256 time, address[] addresses) internal view virtual returns (uint256[] tokenHolderBalances, uint256 totalSupply)
```

_Balances of many holders and the total supply, at one `time`_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |
| addresses | address[] | the holders to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenHolderBalances | uint256[] | one balance per address |
| totalSupply | uint256 | the recorded total supply |

### _snapshotInfoBatch

```solidity
function _snapshotInfoBatch(uint256[] times, address[] addresses) internal view virtual returns (uint256[][] tokenHolderBalances, uint256[] totalSupplies)
```

_Balances of holders across many `time`s_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| times | uint256[] | the dividend times |
| addresses | address[] | the holders to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenHolderBalances | uint256[][] | one row per time |
| totalSupplies | uint256[] | one total supply per time |

## IncomeVaultSnapshotModule

### onlySnapshotSourceManager

```solidity
modifier onlySnapshotSourceManager()
```

_Restricts the replacement of the snapshot source_

### SnapshotSourceStorage

```solidity
struct SnapshotSourceStorage {
  contract ISnapshotSource _source;
}
```

### setDividendSnapshotSource

```solidity
function setDividendSnapshotSource(contract ISnapshotSource source) public virtual
```

Replace the contract the vault reads the holder balances from
@dev
Only accepted while **no claim period is open** — `openClaimCount()` must be zero. Changing the
source under an open period would silently re-price every unclaimed dividend of that period,
because the amounts are computed from the source at claim time, not fixed at deposit.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| source | contract ISnapshotSource | the new snapshot source, must implement {ISnapshotSource} and be non-zero |

### dividendSnapshotSource

```solidity
function dividendSnapshotSource() public view virtual returns (contract ISnapshotSource)
```

The contract the vault reads the holder balances from

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | contract ISnapshotSource | The configured {ISnapshotSource} |

### _setDividendSnapshotSource

```solidity
function _setDividendSnapshotSource(contract ISnapshotSource source) internal virtual
```

Sets the snapshot source used to compute the dividends

_reverts if `source` is the zero address_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| source | contract ISnapshotSource | any contract implementing {ISnapshotSource} |

### _snapshotInfo

```solidity
function _snapshotInfo(uint256 time, address tokenHolder) internal view virtual returns (uint256, uint256)
```

_Balance of one holder and the total supply, at `time`_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |
| tokenHolder | address | the holder to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 |  |
| [1] | uint256 |  |

### _snapshotInfoBatch

```solidity
function _snapshotInfoBatch(uint256 time, address[] addresses) internal view virtual returns (uint256[], uint256)
```

_Balances of many holders and the total supply, at one `time`_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |
| addresses | address[] | the holders to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256[] |  |
| [1] | uint256 |  |

### _snapshotInfoBatch

```solidity
function _snapshotInfoBatch(uint256[] times, address[] addresses) internal view virtual returns (uint256[][], uint256[])
```

_Balances of holders across many `time`s_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| times | uint256[] | the dividend times |
| addresses | address[] | the holders to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256[][] |  |
| [1] | uint256[] |  |

### _authorizeSnapshotSourceManagement

```solidity
function _authorizeSnapshotSourceManagement() internal view virtual
```

_Authorization hook invoked before {setDividendSnapshotSource}.
Implemented by the deployment contract with the desired access-control policy._

### _getSnapshotSourceStorage

```solidity
function _getSnapshotSourceStorage() internal pure returns (struct IncomeVaultSnapshotModule.SnapshotSourceStorage $)
```

_Returns the ERC-7201 namespaced storage of this module_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| $ | struct IncomeVaultSnapshotModule.SnapshotSourceStorage | the storage struct |

## IncomeVaultValidationCore

### _validateTransfer

```solidity
function _validateTransfer(address from, address to, uint256 value) internal view virtual
```

_Reverts if the vault may not pay `value` to `to`. Implemented by the deployment — or by the
host contract, when the dividend logic is embedded in one._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| from | address | the address sending the payment, always the vault itself |
| to | address | the token holder receiving the dividends |
| value | uint256 | the amount of payment token |

## IncomeVaultValidationModule

### onlyRuleEngineManager

```solidity
modifier onlyRuleEngineManager()
```

_Restricts the management of the RuleEngine_

### __IncomeVaultValidation_init_unchained

```solidity
function __IncomeVaultValidation_init_unchained(contract IRuleEngine ruleEngine_) internal
```

Initializes the validation module

_Writes the RuleEngine slot that CMTAT's {ValidationModuleRuleEngineInternal} owns, at its
hardcoded ERC-7201 location. In the standalone vault that slot belongs to this contract alone. In
a host that also inherits a CMTAT validation stack it is **shared**, so a non-zero `ruleEngine_`
here would replace the *token's* compliance engine from the dividend initializer. Such a host must
pass the zero address, which CMTAT's initializer treats as a no-op, and keep the engine the token
already configured. Embedding the payout logic via {IncomeVaultValidationCore} instead avoids the
question entirely, and is the supported route. Finding M-4._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ruleEngine_ | contract IRuleEngine | the RuleEngine applied to the payouts, or the zero address for none |

### setRuleEngine

```solidity
function setRuleEngine(contract IRuleEngine ruleEngine_) public virtual
```

Updates the RuleEngine applied to the dividend payouts.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ruleEngine_ | contract IRuleEngine | the new RuleEngine, or the zero address to disable the rule checks |

### canTransfer

```solidity
function canTransfer(address from, address to, uint256 value) public view virtual returns (bool)
```

Returns true if the vault is allowed to pay `value` to `to`.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| from | address | the address sending the payment, always the vault itself |
| to | address | the token holder receiving the dividends |
| value | uint256 | the amount of payment token |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True if the pause, freeze and RuleEngine checks all allow the payout |

### detectTransferRestriction

```solidity
function detectTransferRestriction(address from, address to, uint256 value) public view virtual returns (uint8)
```

ERC-1404 restriction code returned by the RuleEngine for a payout from the vault.

_Returns `0` (no restriction) when no RuleEngine is set. The pause and freeze states are
not reflected here, only the rules: use {canTransfer} for the complete answer._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| from | address | the address sending the payment, always the vault itself |
| to | address | the token holder receiving the dividends |
| value | uint256 | the amount of payment token |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint8 | The ERC-1404 restriction code, `0` when the rules allow the payout |

### messageForTransferRestriction

```solidity
function messageForTransferRestriction(uint8 restrictionCode) public view virtual returns (string)
```

Human readable message matching a code returned by {detectTransferRestriction}.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| restrictionCode | uint8 | the ERC-1404 restriction code to translate |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | string | The message associated with `restrictionCode` |

### _authorizeRuleEngineManagement

```solidity
function _authorizeRuleEngineManagement() internal view virtual
```

_Authorization hook invoked before {setRuleEngine}.
Implemented by the deployment contract with the desired access-control policy.

CMTAT's {ValidationModuleRuleEngine} declares a hook with this same name and parameters.
That is **not** a collision to be renamed away: both this module and CMTAT's wrapper sit on the
same {ValidationModuleRuleEngineInternal}, whose ERC-7201 slot is a hardcoded constant, so a
contract inheriting both has exactly **one** RuleEngine. One capability, therefore one hook — and
a single override answering both declarations is the correct resolution, not an accident. Giving
the two hooks different names would create two doors to one slot, each able to carry a different
policy, and the weaker one would win. See finding M-4._

### _validateTransfer

```solidity
function _validateTransfer(address from, address to, uint256 value) internal view virtual
```

_The standalone vault's answer: its own pause state, the frozen status of both parties, and
the RuleEngine if one is configured._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| from | address | the address sending the payment, always the vault itself |
| to | address | the token holder receiving the dividends |
| value | uint256 | the amount of payment token |

## Ownable2StepERC165Module

### IERC173_INTERFACE_ID

```solidity
bytes4 IERC173_INTERFACE_ID
```

ERC-165 interface ID of ERC-173 (contract ownership standard)

_bytes4(keccak256("owner()")) ^ bytes4(keccak256("transferOwnership(address)"))_

### IOWNABLE2STEP_INTERFACE_ID

```solidity
bytes4 IOWNABLE2STEP_INTERFACE_ID
```

ERC-165 interface ID of the Ownable2Step-specific functions

_bytes4(keccak256("acceptOwnership()")) ^ bytes4(keccak256("pendingOwner()"))_

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool)
```

ERC-165 interface detection

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| interfaceId | bytes4 | The interface identifier to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True if the interface is supported, false otherwise |

## VersionModule

Exposes the IncomeVault release version through the ERC-3643 version interface.
@dev
Same shape as the CMTAT, RuleEngine and SnapshotEngine version modules: a single compile-time
constant read through {IERC3643Version-version}. Bump `VERSION` together with the `CHANGELOG.md`
entry of the release.

### version

```solidity
function version() public view virtual returns (string version_)
```

Returns the current version of the token contract.

_This value is useful to know which smart contract version has been used_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| version_ | string | A string representing the version of the token implementation (e.g., "1.0.0"). |

## IncomeVaultOpen

### claimDividend

```solidity
function claimDividend(uint256 time) public virtual
```

claim your payment

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | provide the date where you want to receive your payment |

### claimDividendFor

```solidity
function claimDividendFor(address holder, uint256 time) public virtual
```

Claim on behalf of a token holder
@dev
Callable by the holder, or by an address the holder authorised through {setOperator}. The
dividends always go to **the holder** — an operator pays the gas and chooses the moment, it can
never redirect the payment. Every other rule is unchanged: the claim window, the
already-claimed check and the transfer restrictions all apply exactly as for {claimDividend}.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | address | the token holder to claim for |
| time | uint256 | provide the date of the payment |

### claimDividendBatchFor

```solidity
function claimDividendBatchFor(address holder, uint256[] times) public virtual
```

Batch version of {claimDividendFor}

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | address | the token holder to claim for |
| times | uint256[] | provide the dates of the payments |

### claimDividendBatch

```solidity
function claimDividendBatch(uint256[] times) public virtual
```

batch version of {claimDividend}

_Don't check if the dividends have been already claimed before external call to the snapshot source._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| times | uint256[] | provide the dates where you want to receive your payment |

### validateTimeCode

```solidity
function validateTimeCode(uint256 time) public view virtual returns (enum IIncomeVault.TIME_ERROR_CODE code)
```

validate if a time is valid, return 0 if valid

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| code | enum IIncomeVault.TIME_ERROR_CODE | the reason the time is invalid, or `TIME_ERROR_CODE.OK` |

### validateTime

```solidity
function validateTime(uint256 time) public view virtual
```

validate if a time is valid, revert if invalid

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time to check |

### validateTimeBatch

```solidity
function validateTimeBatch(uint256[] times) public view virtual
```

batch version of {validateTime}

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| times | uint256[] | the dividend times to check |

### _claimDividend

```solidity
function _claimDividend(address sender, uint256 time) internal virtual
```

_{claimDividend} for an explicit holder_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | the token holder being paid |
| time | uint256 | the dividend time |

### _claimDividendBatch

```solidity
function _claimDividendBatch(address sender, uint256[] times) internal virtual
```

_{claimDividendBatch} for an explicit holder_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | the token holder being paid |
| times | uint256[] | the dividend times |

## IncomeVaultRestricted

### onlyDepositManager

```solidity
modifier onlyDepositManager()
```

_Restricts the deposit of dividends_

### onlyWithdrawManager

```solidity
modifier onlyWithdrawManager()
```

_Restricts the withdrawal of the deposited funds_

### onlyDistributeManager

```solidity
modifier onlyDistributeManager()
```

_Restricts the issuer-driven distribution of the dividends_

### onlyVaultOperator

```solidity
modifier onlyVaultOperator()
```

_Restricts the configuration of the claim window_

### __IncomeVaultRestricted_init_unchained

```solidity
function __IncomeVaultRestricted_init_unchained(uint256 timeLimitToWithdraw_) internal
```

_calls the different initialize functions from the different modules_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| timeLimitToWithdraw_ | uint256 | delay, after the dividend time, during which a claim is accepted |

### deposit

```solidity
function deposit(uint256 time, uint256 amount) public virtual
```

deposit an amount to pay the dividends.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | provide the date where you want to perform a deposit |
| amount | uint256 | the amount to deposit |

### depositBatch

```solidity
function depositBatch(uint256[] times, uint256[] amounts) public virtual
```

Deposit for several dividend times in one transaction
@dev
Equivalent to calling {deposit} once per entry — same accounting, same `newDeposit` event per
entry — but the payment token is pulled **once** for the total instead of once per time. That is
the reason the function exists; the common case is an issuer opening a year of coupon periods.

Repeating a `time` is allowed and accumulates, exactly as separate calls would.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| times | uint256[] | the dividend times to deposit for |
| amounts | uint256[] | the amount to deposit for each time, must be the same length and each non-zero |

### withdraw

```solidity
function withdraw(uint256 time, uint256 amount, address withdrawAddress) public virtual
```

withdraw a certain amount at a specified time.
@dev
Bounded by {unclaimedDividend}, so a sweep can never reach funds deposited for another dividend
time. Intended for after the claim window closes, when what remains is rounding dust and
unclaimed shares.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | provide the date where you want to perform a deposit |
| amount | uint256 | the amount to withdraw |
| withdrawAddress | address | address to receive `amount`of tokens |

### withdrawAll

```solidity
function withdrawAll(uint256 amount, address withdrawAddress) public virtual
```

withdraw all tokens from ERC20TokenPayment contracts deposited

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | the amount to withdraw |
| withdrawAddress | address | address to receive `amount`of tokens |

### distributeDividend

```solidity
function distributeDividend(address[] addresses, uint256 time) public virtual
```

distribute the dividends

_The dividends are distributed only if they have not yet been claimed by the token holder.
Subject to the same claim window **and** the same transfer restrictions as
{IncomeVaultOpen-claimDividend}: a holder the pause, freeze or RuleEngine refuses cannot be paid
by the issuer either, and one blocked holder reverts the whole distribution._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| addresses | address[] | compute and transfer dividend for these holders |
| time | uint256 | dividend time |

### distributeDividendBestEffort

```solidity
function distributeDividendBestEffort(address[] addresses, uint256 time) public virtual returns (uint256 paidCount, address[] skipped)
```

Distribute the dividends, skipping any holder whose payout is refused
@dev
Same computation as {distributeDividend}, but a holder the ValidationModule or the payment token
refuses is **skipped** instead of reverting the whole call. Use it when one non-compliant address
must not block a large payout run; use {distributeDividend} when the distribution should be
all-or-nothing.

Each payout is attempted through an external self-call so it can be wrapped in `try`/`catch`,
which gives **per-holder atomicity**: a holder is either fully paid — marked claimed *and*
transferred — or left completely untouched and still able to claim later. A partial state where
a holder is marked as claimed without receiving the tokens is not reachable.

Every skip emits {DividendDistributionSkipped} carrying the raw revert data, so the cause can be
decoded off-chain, and the skipped holders are returned for the caller to act on directly.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| addresses | address[] | compute and transfer dividend for these holders |
| time | uint256 | dividend time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| paidCount | uint256 | how many holders were paid |
| skipped | address[] | the holders that were not paid, trimmed to `paidCount` subtracted from the input |

### transferDividendSelf

```solidity
function transferDividendSelf(uint256 time, address tokenHolder, uint256 tokenHolderDividend) public virtual
```

Validate and pay one dividend — callable **only by the vault itself**
@dev
This exists solely so {distributeDividendBestEffort} can wrap a payout in `try`/`catch`, which
requires an external call. It carries no access control of its own beyond the self-call check,
so that check is what stands between it and an unauthorized payout: reverts
{IncomeVault_OnlySelfCall} for every caller other than `address(this)`.

`msg.sender` is used deliberately rather than `_msgSender()`. The check must identify the real
caller; an ERC-2771 forwarder must never be able to present itself as the vault.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | dividend time |
| tokenHolder | address | the holder to pay |
| tokenHolderDividend | uint256 | the amount to pay |

### setStatusClaim

```solidity
function setStatusClaim(uint256 time, bool status) public virtual
```

set the status to open or close the claims for a given time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | target time |
| status | bool | boolean (true or false) |

### setTimeLimitToWithdraw

```solidity
function setTimeLimitToWithdraw(uint256 timeLimitToWithdraw_) public virtual
```

configure the time limit to withdraw

_reverts if `timeLimitToWithdraw_` is zero: that would leave a one-second claim window_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| timeLimitToWithdraw_ | uint256 | delay, after the dividend time, during which a claim is accepted, must be greater than zero |

### _authorizeDeposit

```solidity
function _authorizeDeposit() internal view virtual
```

_Authorization hook invoked before a deposit.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeWithdraw

```solidity
function _authorizeWithdraw() internal view virtual
```

_Authorization hook invoked before {withdraw} and {withdrawAll}.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeDistribute

```solidity
function _authorizeDistribute() internal view virtual
```

_Authorization hook invoked before {distributeDividend}.
Implemented by the deployment contract with the desired access-control policy._

### _authorizeOperator

```solidity
function _authorizeOperator() internal view virtual
```

_Authorization hook invoked before {setStatusClaim} and {setTimeLimitToWithdraw}.
Implemented by the deployment contract with the desired access-control policy._

## IncomeVaultInvariantStorage

### newDeposit

```solidity
event newDeposit(uint256 time, address sender, uint256 dividend)
```

Emitted when an authorized address deposits dividends for a given time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time the deposit is attached to |
| sender | address | the address performing the deposit |
| dividend | uint256 | the amount of payment token deposited |

### DividendClaimed

```solidity
event DividendClaimed(uint256 time, address sender, uint256 dividend)
```

Emitted when the dividends of a token holder are claimed or distributed

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |
| sender | address | the token holder receiving the dividends |
| dividend | uint256 | the amount of payment token transferred |

### ERC20TokenPaymentSet

```solidity
event ERC20TokenPaymentSet(contract IERC20 newERC20TokenPayment)
```

Emitted when the ERC-20 used to pay the dividends is set

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newERC20TokenPayment | contract IERC20 | the payment token |

### ClaimStatusSet

```solidity
event ClaimStatusSet(uint256 time, bool status)
```

Emitted when the claims are opened or closed for a dividend time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |
| status | bool | true when the token holders can claim |

### TimeLimitToWithdrawSet

```solidity
event TimeLimitToWithdrawSet(uint256 timeLimitToWithdraw)
```

Emitted when the delay during which a claim is accepted is set

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| timeLimitToWithdraw | uint256 | the delay in seconds |

### Withdraw

```solidity
event Withdraw(uint256 time, address withdrawAddress, uint256 amount)
```

Emitted when an authorized address withdraws the funds deposited for a dividend time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time the funds were deposited for |
| withdrawAddress | address | the address receiving the funds |
| amount | uint256 | the amount of payment token withdrawn |

### DividendDistributionSkipped

```solidity
event DividendDistributionSkipped(uint256 time, address tokenHolder, bytes reason)
```

Emitted when a best-effort distribution skips a token holder

_Reported by {IncomeVaultRestricted-distributeDividendBestEffort}. The holder is left
completely untouched — not marked as claimed — and can still claim later, or be included in a
subsequent distribution._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | uint256 | the dividend time |
| tokenHolder | address | the holder who was not paid |
| reason | bytes | the raw revert data of the failed payout, so the cause can be decoded off-chain |

### WithdrawAll

```solidity
event WithdrawAll(address withdrawAddress, uint256 amount)
```

Emitted when an authorized address withdraws funds without a dividend time

_the per-time accounting in `segregatedDividend` is left untouched, see {withdrawAll}_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| withdrawAddress | address | the address receiving the funds |
| amount | uint256 | the amount of payment token withdrawn |

### DividendSnapshotSourceSet

```solidity
event DividendSnapshotSourceSet(contract ISnapshotSource newSource)
```

Emitted when the snapshot source used to compute the dividends is set.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newSource | contract ISnapshotSource | The contract queried for historical balances and total supply. |

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

### IncomeVault_SnapshotSourceWithAddressZeroNotAllowed

```solidity
error IncomeVault_SnapshotSourceWithAddressZeroNotAllowed()
```

### IncomeVault_TimeLimitToWithdrawZeroNotAllowed

```solidity
error IncomeVault_TimeLimitToWithdrawZeroNotAllowed()
```

Thrown when the withdraw time limit is set to zero.

_A limit of zero collapses the claim window `[time, time + limit]` to the single instant
`block.timestamp == time`, making the period effectively unclaimable._

### IncomeVault_ClaimPeriodOpen

```solidity
error IncomeVault_ClaimPeriodOpen(uint256 openClaimCount)
```

Thrown when the snapshot source is changed while at least one claim period is open.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| openClaimCount | uint256 | how many dividend times currently have their claims open |

### IncomeVault_OnlySelfCall

```solidity
error IncomeVault_OnlySelfCall()
```

Thrown when {IncomeVaultRestricted-transferDividendSelf} is called by anyone but the vault.

_That function exists only so the best-effort distribution can wrap a payout in try/catch,
which requires an external call. It must never be reachable from outside._

### IncomeVault_InvalidLengths

```solidity
error IncomeVault_InvalidLengths(uint256 timesLength, uint256 amountsLength)
```

Thrown when {IncomeVaultRestricted-depositBatch} is given arrays of different lengths.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| timesLength | uint256 | the number of dividend times supplied |
| amountsLength | uint256 | the number of amounts supplied |

### IncomeVault_UnauthorizedOperator

```solidity
error IncomeVault_UnauthorizedOperator(address holder, address caller)
```

Thrown when a caller claims for a holder without being that holder or their operator.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | address | the token holder whose dividends were targeted |
| caller | address | the address that attempted the claim |

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

### IncomeVault_InvalidTransfer

```solidity
error IncomeVault_InvalidTransfer(address from, address to, uint256 value)
```

Thrown when the ValidationModule (pause, freeze or RuleEngine) forbids the payout.

### IncomeVault_SameValue

```solidity
error IncomeVault_SameValue()
```

## IncomeVaultRolesStorage

### INCOME_VAULT_OPERATOR_ROLE

```solidity
bytes32 INCOME_VAULT_OPERATOR_ROLE
```

Role allowed to open/close the claims and to configure the withdraw time limit

### INCOME_VAULT_DEPOSIT_ROLE

```solidity
bytes32 INCOME_VAULT_DEPOSIT_ROLE
```

Role allowed to deposit the payment token in the vault

### INCOME_VAULT_DISTRIBUTE_ROLE

```solidity
bytes32 INCOME_VAULT_DISTRIBUTE_ROLE
```

Role allowed to push the dividends to a list of token holders

### INCOME_VAULT_WITHDRAW_ROLE

```solidity
bytes32 INCOME_VAULT_WITHDRAW_ROLE
```

Role allowed to withdraw the payment token from the vault

