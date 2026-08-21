# IncomeVault — Specification and technical choice

<!-- toc -->

- [Introduction](#introduction)
- [Coverage of the CMTAT Distribution module](#coverage-of-the-cmtat-distribution-module)
- [Snapshot source](#snapshot-source)
  - [Replacing the snapshot source](#replacing-the-snapshot-source)
- [Access control](#access-control)
  - [Deployment variants](#deployment-variants)
  - [Capability table](#capability-table)
  - [Depositing for several periods](#depositing-for-several-periods)
- [Segregated Deposit](#segregated-deposit)
- [ValidationModule](#validationmodule)
  - [Freezing the vault itself](#freezing-the-vault-itself)
  - [RuleEngine](#ruleengine)
- [Operation](#operation)
  - [Claim dividends](#claim-dividends)
  - [Claim restriction](#claim-restriction)
  - [Schema](#schema)
- [Claiming on behalf of a holder](#claiming-on-behalf-of-a-holder)
  - [Authorising by signature (ERC-7741)](#authorising-by-signature-erc-7741)
- [Per-period residue](#per-period-residue)
- [Withdraw funds](#withdraw-funds)
- [Distribute dividend](#distribute-dividend)
  - [Best-effort distribution](#best-effort-distribution)
- [Comparison with ERC-4626 / ERC-7540 vaults](#comparison-with-erc-4626--erc-7540-vaults)
  - [Why ERC-4626 does not fit a dividend](#why-erc-4626-does-not-fit-a-dividend)
  - [What ERC-7540 changes, and what it does not](#what-erc-7540-changes-and-what-it-does-not)
  - [When a 4626 vault is the right tool](#when-a-4626-vault-is-the-right-tool)
  - [A place the two could meet](#a-place-the-two-could-meet)
- [Source layout](#source-layout)
- [The stated API: IIncomeVault](#the-stated-api-iincomevault)
- [Embedding the distribution logic in a token](#embedding-the-distribution-logic-in-a-token)
- [Improvement](#improvement)
- [Deployment](#deployment)
  - [Deployment scripts](#deployment-scripts)
- [Threat model & FAQ](#threat-model--faq)
  - [Claim dividend several times](#claim-dividend-several-times)
  - [New dividend after claim](#new-dividend-after-claim)
  - [Transfer fails](#transfer-fails)
- [Technical choice](#technical-choice)
  - [Functionality](#functionality)
  - [Schema](#schema-2)
  - [Inheritance](#inheritance)
  - [Graph](#graph)
  - [Report](#report)

<!-- /toc -->

## Introduction

![IncomeVault architecture](./schema/plantuml/incomevault-architecture.png)

_Diagram source: [doc/schema/plantuml/incomevault-architecture.puml](./schema/plantuml/incomevault-architecture.puml). This is the overview; the detailed flow of the same process is [further down](#snapshot-source)._

 \0. On the snapshot source (e.g. a `SnapshotEngine` bound to a CMTAT), the admin registers the dividend `time` to perform a snapshot and store the holder’s balance at this specified time.

1. An authorized address perform a deposit in the `IncomeVault` for a specific `time`
2. An authorized address open the claim for this specific `time`
3. Holder claims his dividends by calling the function `claimDividend`

## Coverage of the CMTAT Distribution module

`IncomeVault` implements the optional **Distribution module** of the CMTA framework functional specifications (June 2026), section 3.2.4, functionalities 27 to 32.

| # | Specification | Status |
| --- | --- | --- |
| 27 | Distribution create parameters | ◑ partial — the settlement token is fixed per vault, not per distribution |
| 28 | Distribution set eligibility | ◑ different mechanism — evaluated at payout time, not a stored flag |
| 29 | Distribution set deposit | ● `deposit`, `depositBatch` |
| 30 | Distribution claim deposit | ● `claimDividend`, `claimDividendBatch` |
| 31 | Distribution schedule *(debt)* | ○ not implemented |
| 32 | Distribution unschedule *(debt)* | ○ not implemented |

Legend: ● implemented, ◑ partial or answered differently, ○ not implemented.

Beyond the specification, the vault adds a **claim window**, **issuer recovery** of what is left unclaimed, a **push** counterpart to the pull claim, **claim delegation** (ERC-7540 / ERC-7741) and per-period accounting — each answering a question the specification leaves open, such as how long a holder may claim for and where the rounding residue goes.

Functionalities 31 and 32 would need **no new state** if specified: the record dates already exist as `uint256[]` in the Snapshot module (`getNextSnapshots()`), and the terms already exist in the Debt module (`couponPaymentFrequency`, `interestScheduleFormat`, `currencyContract`) — though as strings, so a contract cannot act on them.

> **The full comparison lives in [`doc/cmtat-standard/CMTAT-Distribution-impl.md`](./cmtat-standard/CMTAT-Distribution-impl.md)**: the functionality-by-functionality table, what the vault adds and why, the analysis of 31/32, and **twelve changes we would propose to the specification**, split into nine amendments to functionalities that already exist and three additions the specification does not describe at all. It also argues that the specification should stay snapshot-*oriented* without being snapshot-*only* — balances pinned off-chain at a block height fix a record date just as well — and asks what the specification should say about holding a deposit as ERC-4626 shares.

## Snapshot source

The vault never talks to the token directly. It holds a single reference, `snapshotEngine`, typed with **`ISnapshotSource`** (`src/interfaces/ISnapshotSource.sol`) — the three functions it actually calls, and nothing else:

| Function | Used by |
| --- | --- |
| `snapshotInfo(uint256 time, address tokenHolder)` | `claimDividend` |
| `snapshotInfoBatch(uint256[] times, address[] addresses)` | `claimDividendBatch` |
| `snapshotInfoBatch(uint256 time, address[] addresses)` | `distributeDividend` |

`ISnapshotSource` is a strict subset of `ISnapshotState`, defined by the [SnapshotEngine](https://github.com/CMTA/SnapshotEngine), which declares eight functions. The signatures are copied verbatim, so **every `ISnapshotState` implementation already satisfies it** — the external `SnapshotEngine`, a token embedding the snapshot modules, or a custom provider — while a new implementation only has to write the three the vault calls, not five it would never see used. Solidity has no implicit conversion between unrelated interfaces, so pass one with an explicit cast: `ISnapshotSource(address(engine))`.

The address is set at initialization and cannot be the zero address.

The vault does not call it directly. `IncomeVaultSnapshotCore` declares the three questions the payout paths actually ask — one holder's balance at a `time`, many holders' balances at a `time`, and one holder's balances across many `time`s — and inherits nothing. `IncomeVaultSnapshotModule` is one *answer* to them: an `ISnapshotSource` held in its own namespace, reachable through `dividendSnapshotSource()`. A token that already records snapshots answers the same three hooks from itself, with no second contract and nothing stored. See *Embedding the distribution logic in a token*.

### Replacing the snapshot source

`setDividendSnapshotSource` allows a migration — a redeployed `SnapshotEngine`, or a token moving to embedded snapshot modules — but **only while no claim period is open**. The vault tracks how many dividend times currently have their claims open in `openClaimCount()`, and the setter reverts with `IncomeVault_ClaimPeriodOpen(openClaimCount)` while that is non-zero.

The reason for the gate: dividend amounts are computed from the snapshot source **at claim time**, not fixed at deposit. Swapping the source under an open period would silently re-price every unclaimed dividend of that period.

> **The gate narrows the hazard, it does not remove it.** Entitlements are always resolved against whichever source is configured *when the claim happens*. Re-opening a past `time` after a swap resolves that period against the **new** source. Holders who already claimed are protected — `claimedDividend` persists across the change — but holders who had not are not. Treat a swap as a migration that requires every period to be settled and closed, not as a routine configuration change. If historical periods must keep resolving against the source they were created with, that needs per-`time` pinning at deposit, which this prototype does not implement.

> The vault does **not** verify the interface through ERC-165. The canonical `SnapshotEngine` advertises no id for it, so a guard would reject the implementation the vault is built for. And ERC-165 expresses shape, never semantics: a source returning attacker-chosen balances satisfies this interface exactly as an honest one does. Trusting the snapshot source stays a configuration decision.

![IncomeVault global flow](./schema/plantuml/incomevault-global.png)

_Diagram source: [doc/schema/plantuml/incomevault-global.puml](./schema/plantuml/incomevault-global.puml)._

## Access control

The vault separates **what** is protected from **who** may do it. The logic contracts declare one `internal view virtual` authorization hook per capability, invoked by a modifier; each deployment contract overrides the hooks with the policy it wants. Because the hooks are declared without a body, the compiler refuses to deploy a vault that has not answered the question.

```solidity
// IncomeVaultRestricted — declares the capability
modifier onlyWithdrawManager() { _authorizeWithdraw(); _; }
function withdraw(...) public virtual onlyWithdrawManager { ... }
function _authorizeWithdraw() internal view virtual;

// IncomeVault — declares the policy
function _authorizeWithdraw() internal view virtual override onlyRole(INCOME_VAULT_WITHDRAW_ROLE) {}
```

### Deployment variants

Two deployments ship. **The choice is made at deployment and cannot be changed afterwards** — they are different contracts, not a setting, and a deployed proxy cannot be swapped from one to the other.

| Contract | Access control | `initialize` first argument |
| --- | --- | --- |
| `IncomeVault` | Role-based, CMTAT `AccessControlModule` (`AccessControlUpgradeable`) | `address admin` |
| `IncomeVaultOwnable2Step` | Single owner, ERC-173 `Ownable2StepUpgradeable` | `address owner_` |

### Capability table

| Capability | Function(s) | Hook | `IncomeVault` | `IncomeVaultOwnable2Step` |
| --- | --- | --- | --- | --- |
| Fund the vault | `deposit`, `depositBatch` | `_authorizeDeposit` | `INCOME_VAULT_DEPOSIT_ROLE` | owner |
| Remove funds | `withdraw`, `withdrawAll` | `_authorizeWithdraw` | `INCOME_VAULT_WITHDRAW_ROLE` | owner |
| Push payouts | `distributeDividend`, `distributeDividendBestEffort` | `_authorizeDistribute` | `INCOME_VAULT_DISTRIBUTE_ROLE` | owner |
| Claim window | `setStatusClaim`, `setTimeLimitToWithdraw` | `_authorizeOperator` | `INCOME_VAULT_OPERATOR_ROLE` | owner |
| Compliance engine | `setRuleEngine` | `_authorizeRuleEngineManagement` | `DEFAULT_ADMIN_ROLE` | owner |
| Snapshot source | `setDividendSnapshotSource` | `_authorizeSnapshotSourceManagement` | `DEFAULT_ADMIN_ROLE` | owner |
| Emergency stop | `pause`, `unpause` | `_authorizePause` | `PAUSER_ROLE` | owner |
| Permanent kill | `deactivateContract` | `_authorizeDeactivate` | `DEFAULT_ADMIN_ROLE` | owner |
| Address freeze | `setAddressFrozen`, `batchSetAddressFrozen` | `_authorizeFreeze` | `ENFORCER_ROLE` | owner |

> **The hook shares its name with CMTAT's, deliberately.** CMTAT declares `_authorizeRuleEngineManagement()` in `ValidationModuleRuleEngine`. A contract inheriting both that and this module has exactly **one** RuleEngine — both sit on the same `ValidationModuleRuleEngineInternal`, whose ERC-7201 slot is a hardcoded constant. One capability, one hook: a single override answering both declarations is the correct resolution. Renaming ours would create two hooks over one slot, each able to carry a different policy, and the weaker would win. Finding M-4.

Role management itself (`grantRole` / `revokeRole`) is held by `DEFAULT_ADMIN_ROLE` in the role-based variant; in the single-owner variant, ownership moves through the two-step `transferOwnership` / `acceptOwnership` handover.

> **`IncomeVaultOwnable2Step` cannot express separated duties.** Every capability collapses to the single owner, so the account that funds the vault is also the account that can empty it through `withdrawAll`. Pick it only when one key legitimately holds everything; an issuer paying dividends normally wants `IncomeVault`, where depositing and withdrawing are distinct privileges.

> **The role-based admin is not constrained by role separation.** The CMTAT `AccessControlModule` treats `DEFAULT_ADMIN_ROLE` as implicitly holding every role, so the admin passes every check — but it does **not** appear in `getRoleMember` enumerations, so an off-chain tool listing role holders will not show it. Role separation constrains the operators, never the admin.

> **`PAUSER_ROLE` and `ENFORCER_ROLE` are published by both variants** because they are declared by the CMTAT `PauseModule` and `EnforcementModule` the vault inherits. In `IncomeVaultOwnable2Step` they are never checked; granting them is impossible there and reading them means nothing. The vault's own four roles are declared in `IncomeVaultRolesStorage`, inherited only by `IncomeVault`, so they are not published by the variant that does not enforce them.

### Depositing for several periods

`depositBatch(times[], amounts[])` credits each `time` exactly as a separate `deposit` would — same accounting, one `newDeposit` event per entry — and pulls the payment token **once** for the total. Repeating a `time` accumulates, as separate calls would. The arrays must be the same non-zero length and every amount must be non-zero; otherwise the whole batch reverts and nothing is credited.

**Where the saving actually is, measured:** *inside* a transaction the batch is the more expensive of the two — decoding two dynamic `calldata` arrays outweighs the single token transfer. For three periods: **136,546 gas batched against 116,812 for three separate calls.** The win is the intrinsic per-transaction cost, paid once instead of N times:

| Three periods | in-call | + intrinsic | total |
| --- | --- | --- | --- |
| `depositBatch` | 136,263 | 21,000 x 1 | **157,263** |
| 3 x `deposit` | 116,812 | 21,000 x 3 | 179,812 |

So it is worth using for two or more periods, and the advantage grows with the count — but it is a transaction-count optimisation, not a cheaper deposit.

## Segregated Deposit

Each deposit is segregated in its time value. A `time` is the dividends distribution date (Unix Timestamp) to the token holders.

![IncomeVault segregated deposit](./schema/plantuml/incomevault-segregated-deposit.png)

_Diagram source: [doc/schema/plantuml/incomevault-segregated-deposit.puml](./schema/plantuml/incomevault-segregated-deposit.puml)._

## ValidationModule

A claim is considered as a transfer from the contract to the sender (token holder). This transfer can be restricted with the `IncomeVaultValidationModule`, which composes three CMTAT modules and an optional RuleEngine:

- `EnforcementModule` — freeze/unfreeze an address (`ENFORCER_ROLE`)
- `PauseModule` — put the contract in the pause state (`PAUSER_ROLE`), or deactivate it
- an optional `IRuleEngine` for additional rules

If any of them refuses the transfer, the function reverts with `IncomeVault_InvalidTransfer(from, to, value)`.

The public view `canTransfer(from, to, value)` returns the same answer without reverting. `detectTransferRestriction` answers for the **whole** decision in the same order — deactivation, pause, either party frozen, then the RuleEngine — so it returns `0` exactly when `canTransfer` is true, and `messageForTransferRestriction` explains each code. Both use CMTAT's `REJECTED_CODE_BASE` numbering and CMTAT's message strings, so a console written against a CMTAT reads a refused payout exactly as it reads a refused transfer.

### Freezing the vault itself

`canTransfer` is always called with the vault as `from`, and `setAddressFrozen` accepts any address — so `ENFORCER_ROLE` can freeze **the vault**, which stops every payout: both `claimDividend` and `distributeDividend` revert. It is a second kill-switch alongside `pause`, reachable without holding `PAUSER_ROLE`.

Know its limits before reaching for it:

- **It is not visible through `paused()`**, which stays `false`. A monitor watching the pause flag sees a healthy vault.
- **The revert is the ordinary `IncomeVault_InvalidTransfer`**, the same error a blocked holder gets. Distinguish the two by checking the `AddressFrozen` logs for the vault's own address.
- **It does not protect the funds.** Deposits still succeed, and `INCOME_VAULT_WITHDRAW_ROLE` can still drain the contract with `withdrawAll`. It stops holders being paid; it is not a safe mode.

Use `pause` for an emergency stop. Freezing the vault is the compliance-officer lever, and the pause state is the one an operator should monitor.

### RuleEngine 

As for the CMTAT, there is the possibility to configure a ruleEngine with rules to perform transfer rectriction/verification. As relevant rules, we have:

- Whitelist
- Blacklist
- Sanctionlist
- ConditionalTransfer

The vault is **not** a token bound to the RuleEngine. It only uses the *view* entry point `IRuleEngine.canTransfer(from, to, value)`:

- `transferred(...)` is restricted to bound tokens by the RuleEngine and would revert here;
- a dividend payout is a movement of the *payment* token, not of the security token, so it must not update the stateful rules of the engine.

The RuleEngine can be changed at any time with `setRuleEngine` (`DEFAULT_ADMIN_ROLE`), and set to the zero address to disable the rule checks.





## Operation

### Claim dividends

The distribution of dividends is not automatic. A token holder has to claim his dividends by calling the function `claimDividend`, similar to the Lido protocol. When he claims his dividends, he precises the defined `time`.

Therefore, a token holder has to know the different `time` when a deposit has been performed.

 

A function `claimDividend` in batch is also available to claim dividends for several different time.

### Claim restriction

An holder can not claim its dividends if:

a. The claim time is in the future (`IncomeVault_TooEarlyToWithdraw`)

b. The claim time is too far in the past, specified by `timeLimitToWithdraw` (`IncomeVault_TooLateToWithdraw`)

   `timeLimitToWithdraw` must be **greater than zero**: a limit of zero would collapse the window `[time, time + limit]` to the single instant `block.timestamp == time`, making the period unclaimable. Both `initialize` and `setTimeLimitToWithdraw` reject it with `IncomeVault_TimeLimitToWithdrawZeroNotAllowed`. Any positive value is accepted — a short settlement window can be deliberate.

c. Claim is not enabled for this specific `time` (`IncomeVault_ClaimNotActivated`)

d. Holder has already claim its dividends (`IncomeVault_DividendAlreadyClaimed`)

e. There is no dividend to claim (`IncomeVault_NoDividendToClaim`)

For the batch function, `claimDividendBatch`, `d` and `e` don't generate an error but instead, there is just no dividends distributed for this specific time.

### Schema

This schema describes the different smart contracts called when a token holder claims his dividends.

![Contracts called on a claim](./schema/plantuml/incomevault-ruleengine.png)

_Diagram source: [doc/schema/plantuml/incomevault-ruleengine.puml](./schema/plantuml/incomevault-ruleengine.puml)._

#### Formula

The computation of dividends is performing according to the following formula

```
senderDividend = (senderCMTATBalance * dividendTotalSupply) / TokenTotalSupply;
```

The sender dividend will be rounded to the inferior integer. Thus, the issuer should put a “limit” date to claim his dividend in order to withdraw the staying funds (due to rounding) from the smart contract.

Example with USDC (6 decimal) and a CMTAT (0 decimal)

tokenSupply CMTAT = 12’351

The sender has 4221 tokens.

21’555.50 $ in USDC are deposited corresponding to a value of 21555500000 tokens since USDC has 6 decimals.

 We have:

senderDividend = 4221 * 21555500000 / 12351 = 7366671969.880981297 = 7366671969 which correspond to **7366.671969**$

#### Schema

Schema without the `ValidationModule` (see next paragraph)

![claimDividend flow](./schema/plantuml/incomevault-claimdividend.png)

_Diagram source: [doc/schema/plantuml/incomevault-claimdividend.puml](./schema/plantuml/incomevault-claimdividend.puml)._



## Claiming on behalf of a holder

A holder can authorise another address to trigger their claims, using the shape ERC-7540 defines:

```solidity
vault.setOperator(custodian, true);                  // the holder authorises
vault.claimDividendFor(holder, time);                // the custodian triggers
vault.claimDividendBatchFor(holder, times);
vault.isOperator(holder, custodian);                 // -> true
```

**The operator can never receive the dividends.** They always go to the holder; the operator pays the gas and chooses the moment. Authorisation is per holder, revocable at any time with `setOperator(operator, false)`, and every other rule is unchanged — the claim window, the already-claimed check, the pause, the freeze and the RuleEngine all apply exactly as for `claimDividend`. `OperatorSet(controller, operator, approved)` matches ERC-7540, so tooling written for that standard can index it.

This closes the gap noted in the ERC-7540 comparison below: a custodian can now claim for the holders it serves, and a holder without gas can have someone claim for them.

The three members whose signatures are the standard's are declared in their own interface, `src/interfaces/IERC7540Operator.sol`, so the compatibility is stated in the type system rather than in a comment:

```solidity
interface IERC7540Operator {
    event OperatorSet(address indexed controller, address indexed operator, bool approved);
    function setOperator(address operator, bool approved) external returns (bool success);
    function isOperator(address controller, address operator) external view returns (bool status);
}
```

It inherits nothing, so `type(IERC7540Operator).interfaceId` is exactly the XOR of the two selectors and equals **`0xe3bc4e65`** — the value ERC-7540 assigns to "the operator methods that all ERC-7540 Vaults implement". `testOperatorInterfaceIdMatchesTheStandard` asserts that equality, so changing either signature breaks the build rather than silently breaking a custodian's integration.

> **The vault does not answer `true` for `0xe3bc4e65` from `supportsInterface`, on purpose.** Sharing the operator methods does not make it an asynchronous vault: a caller discovering that id would reasonably expect the ERC-7540 request lifecycle and ERC-7575's `share()`, none of which exists here. `testDoesNotClaimToBeAnErc7540Vault` pins the under-claim so it stays a decision rather than becoming an oversight.

### Authorising by signature (ERC-7741)

`setOperator` needs the holder to send a transaction. [ERC-7741](https://eips.ethereum.org/EIPS/eip-7741) removes that: the holder **signs** an EIP-712 message and anyone — a custodian, a relayer — submits it and pays the gas.

```solidity
vault.authorizeOperator(controller, operator, approved, nonce, deadline, signature);
vault.invalidateNonce(nonce);                    // burn a nonce you no longer want honoured
vault.authorizations(controller, nonce);         // has this nonce been spent?
vault.DOMAIN_SEPARATOR();                        // EIP-712 domain
```

The signed message is exactly the standard's:

```
AuthorizeOperator(address controller,address operator,bool approved,bytes32 nonce,uint256 deadline)
```

Four details worth knowing:

- **Smart-contract wallets work.** Signatures go through OpenZeppelin's `SignatureChecker`, so an [ERC-1271](https://eips.ethereum.org/EIPS/eip-1271) wallet authorises exactly as an EOA does — which matters, because institutional holders of a security token are usually contracts.
- **Nonces are `bytes32` and unordered**, as the standard specifies, so a holder can prepare several independent authorisations without imposing an order on them.
- **The nonce is spent before the signature is checked**, so no path can replay it.
- **The EIP-712 domain version stays `"1"` across releases.** Bumping it would silently invalidate every signature already issued.

Unlike the ERC-7540 operator id, the vault **does** advertise `0xa9e50872` through `supportsInterface` in both variants: ERC-7741 requires it, and unlike ERC-7540 this interface is implemented in full.

> ERC-7741 warns that "operators have significant control over users and the signed message can lead to undesired outcomes". Keep `deadline` short: a signature that leaks later remains usable until it expires or its nonce is burned with `invalidateNonce`.

## Per-period residue

Dividends round down, so a period keeps a residue: the rounding dust plus whatever was never claimed. Two views report it without any off-chain reconstruction:

| View | Meaning |
| --- | --- |
| `paidDividend(time)` | how much has actually been paid out for `time` |
| `unclaimedDividend(time)` | `segregatedDividend(time) - paidDividend(time)` — what is still held for `time` |

**`segregatedDividend` is not that number.** It is the pro-rata denominator and stays fixed at the deposit for the whole period, otherwise each claim would shrink the share of the next claimant. Only `unclaimedDividend` tells you what remains.

`withdraw` is bounded by `unclaimedDividend`, so a sweep can never reach another period's funds. Before this bound existed, a period whose holders had all claimed still reported its full deposit in `segregatedDividend`, and sweeping it drained the money deposited for a different period — leaving that period's holders unpayable with no error raised.

> The bound stops the damage spreading between periods. It does **not** make an early sweep safe: withdrawing before the claim window closes takes money the remaining holders of *that* period are entitled to, and lowers `segregatedDividend`, re-pricing every claim that has not happened yet. A claim that the period can no longer fund now **reverts** with `IncomeVault_NotEnoughAmount` rather than being paid out of another period's deposit. The holder is not silently short-changed and the other periods stay whole, but the swept period is genuinely unable to pay — the sweep, not the revert, is the mistake.

## Withdraw funds

An authorized user can call the following functions to withdraw funds from the vault:

```
1. withdraw(uint256 time, uint256 amount, address withdrawAddress) public onlyRole(INCOME_VAULT_WITHDRAW_ROLE)
```

and

```
2. withdrawAll(uint256 amount, address withdrawAddress) public onlyRole(INCOME_VAULT_WITHDRAW_ROLE)
```

With the function 1, the funds are withdrawn only from the specific time.

The second function allows to withdraw funds without a specific time, which can lead to an “unstable” state with the different pool of dividend. To be used only in case of emergency or if the vault is closed.

 

## Distribute dividend

An authorized user can also decide to distribute the dividend for a given time and a given list of addresses.

In this situation, the token holder can not decide if he wants to receive his dividends (he is forced to accept) and can not choose the address where he wants to receive his dividends.



Since the function is restricted by access control (`INCOME_VAULT_DISTRIBUTE_ROLE`), it is not possible to use Chainlink Automation to perform an automatic call and distribute the dividends. Moreover, the list of token holders has to be provided by the transaction’s sender.

`distributeDividend` is subject to the **same claim window** as a holder-driven claim: the claims must be open for that `time`, `time` must have passed, and the withdraw limit must not have expired. Without the "too early" bound the distribution would read the *live* balances — `ISnapshotState` falls back to them when no snapshot has been recorded yet — and would consume each holder's claim for that period at the wrong amount.

It also goes through the **ValidationModule**, exactly like a claim: the vault must not be paused, neither the vault nor the holder may be frozen, and the RuleEngine must allow the payout. A holder the RuleEngine refuses cannot be paid by the issuer either.

One blocked holder **reverts the whole distribution** rather than being skipped, so a compliance failure can never be silently dropped from a payout the operator believes succeeded. The revert carries `IncomeVault_InvalidTransfer(from, to, value)`, which names the offending address: remove it from the list and retry.

### Best-effort distribution

`distributeDividendBestEffort` is the alternative for a large payout run that one non-compliant address must not block. It computes the same amounts and applies the same claim window and transfer restrictions, but a holder whose payout is refused is **skipped** instead of reverting the call:

```solidity
(uint256 paidCount, address[] memory skipped) =
    vault.distributeDividendBestEffort(addresses, time);
```

Each skip emits `DividendDistributionSkipped(time, tokenHolder, reason)` carrying the **raw revert data**, so the cause — a freeze, a RuleEngine refusal, a payment-token failure — can be decoded off-chain.

Choose between the two by what a partial payout means for you:

| | `distributeDividend` | `distributeDividendBestEffort` |
| --- | --- | --- |
| One holder refused | the whole call reverts | that holder is skipped, the rest are paid |
| Use when | the distribution must be all-or-nothing | one bad address must not block the run |
| Reporting | the revert names the first offender | every skip is evented and returned |

**A skipped holder is left completely untouched.** The payout is attempted through an external self-call wrapped in `try`/`catch`, which gives per-holder atomicity: either the holder is marked claimed *and* paid, or neither. A holder who was skipped is not marked as claimed and can still claim themselves, or be included in a later distribution.

> The helper that call targets, `transferDividendSelf`, carries no access control of its own — it reverts `IncomeVault_OnlySelfCall` for every caller other than the vault. That check is what stands between it and an unauthorized payout, and it deliberately reads `msg.sender` rather than `_msgSender()` so an ERC-2771 forwarder can never present itself as the vault. `catch` also cannot distinguish a refused payout from an out-of-gas failure. The only contracts that can consume gas there — the payment token and the RuleEngine — are admin-set and already trusted.

## Comparison with ERC-4626 / ERC-7540 vaults

The `IncomeVault` is called a vault, but it is **not** an [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) tokenized vault and deliberately does not implement that standard. The two solve different problems, and the difference comes down to one question: **where does the entitlement come from?**

| | `IncomeVault` | ERC-4626 vault |
| --- | --- | --- |
| Entitlement | fixed by a **snapshot at a record date** — who held the token at `time` | continuous — whoever holds shares **now** owns a pro-rata claim |
| Unit of account | the security token (CMTAT), issued and governed elsewhere | the vault's own ERC-20 share, minted on deposit |
| How value reaches the holder | a **transfer** of a *different* token (e.g. USDC) | the **share price rises**; value is extracted by redeeming |
| Effect on the position | none — the holder keeps every token | `redeem`/`withdraw` **burns shares** |
| Periods | many, segregated by `time`, each with its own deadline | one pooled `totalAssets()` |
| Compliance on payout | RuleEngine, pause and freeze checked on every payout | no hook in the standard; `maxWithdraw` must return `0` rather than revert |
| Undistributed funds | swept by the issuer after `timeLimitToWithdraw` | remain in `totalAssets()`, accruing to holders |

### Why ERC-4626 does not fit a dividend

Four of those rows are not preferences, they are blockers:

1. **There is no record date in ERC-4626.** Entitlement follows the share. A buyer who acquires the token *after* the record date but before the payout would capture the dividend, and a seller who sold after the record date would lose it. That inverts the corporate-action semantics a coupon or dividend is meant to have — which is precisely what the snapshot exists to pin down.
2. **The security token would have to *be* the share.** ERC-4626's share is the vault contract's own ERC-20. A CMTAT is already issued, with its own register, transfer restrictions and identifier; its supply is set by the issuer, not by deposits. Making it 4626-compliant is not possible, and the alternative — holders depositing the CMTAT to receive vault shares — puts a *different* token into circulation and splits the register.
3. **A dividend is not a redemption.** ERC-4626 offers exactly one way to extract value, and it burns shares. Paying a coupon must not reduce the holder's stake in the instrument. The standard has no operation for "pay out without reducing the claim".
4. **Two different tokens.** `asset()` is the single token shares are redeemed for. The vault pays USDC to holders of a CMTAT — shares of X, paid in Y — which is outside the standard's model.

### What ERC-7540 changes, and what it does not

[ERC-7540](https://eips.ethereum.org/EIPS/eip-7540) extends ERC-4626 with **asynchronous** flows: `requestDeposit` / `requestRedeem` queue an intent, an operator fulfils it at a price decided at fulfilment, and the controller then claims. It exists because real-world-asset and cross-chain vaults cannot settle atomically.

That solves a **settlement-timing** problem, not an **entitlement** problem. The claim is still share-price based and still continuous, so none of the four blockers above is removed by adopting it.

It does bring things this vault does not have, and they are worth knowing about:

- a standard **request lifecycle** any 7540-aware interface can drive, instead of this project's bespoke `deposit` → `setStatusClaim` → `claimDividend` sequence;
- `setOperator` delegation (extended by [ERC-7741](https://eips.ethereum.org/EIPS/eip-7741) for signed authorisation), where the vault has none — a holder cannot appoint someone to claim on their behalf;
- specified **cancellation** of a pending request ([ERC-7887](https://eips.ethereum.org/EIPS/eip-7887));
- multi-asset share tokens ([ERC-7575](https://eips.ethereum.org/EIPS/eip-7575)).

Two ERC-7540 rules show how different the model is: `preview*` functions **must revert** in an async flow, since no honest quote exists before fulfilment — whereas this vault can always compute a claim exactly from the snapshot; and `requestId = 0` has a defined meaning rather than signalling "no request".

### When a 4626 vault *is* the right tool

If the instrument is **accumulating** rather than distributing — the holder's claim grows continuously and they realise it by redeeming — then ERC-4626 is the correct standard and reimplementing it here would be a mistake. A money-market fund share, a staking wrapper, or a fund whose NAV simply rises all fit that shape. Use ERC-7540 on top when settlement cannot be atomic.

The dividing line is whether the payout is **discrete and dated** (this vault) or **continuous and embedded in the price** (ERC-4626).

### A place the two could meet

Payment tokens deposited for a `time` sit idle in this contract from `deposit` until each holder claims — potentially months. A future version could hold that float as shares of a 4626 vault and redeem on each payout, so the undistributed dividend earns yield instead of nothing.

It is deliberately **not** implemented: the vault owes a *fixed nominal amount* per period, while 4626 shares carry share-price risk. A loss in the underlying vault would leave the contract unable to pay the amount it recorded at `deposit`, turning a bookkeeping contract into one that can be short. Doing it safely needs a buffer policy and an explicit rule for who absorbs a shortfall — a materially larger design than the one this prototype implements.

## Source layout

Each directory says what its files **are**, following the convention CMTAT uses:

| Path | Holds |
| --- | --- |
| `src/IncomeVaultBase.sol` | the composition root: the distribution logic, no meta-transaction policy |
| `src/IncomeVaultBaseERC2771.sol` | the same plus the ERC-2771 context — what the shipped deployments inherit |
| `src/deployment/` | the two deployable contracts, and nothing abstract |
| `src/public/` | the external surface, split by **who may call it** |
| `src/modules/` | the abstract capability mixins, one per capability |
| `src/interfaces/` | interfaces |
| `src/storage/` | declaration-only contracts: errors, events, role constants |

**`src/public/` is split by authorization, on purpose.** Every function in `IncomeVaultOpen` is permissionless; every function in `IncomeVaultRestricted` is gated by an authorization hook. The first question anyone asks of a contract holding other people's dividends is *what can an arbitrary address do to it?* — and here that is answered by opening one file, not by auditing which modifier each function carries. The two are not to be merged into a single "distribution module".

## The stated API: `IIncomeVault`

`src/interfaces/IIncomeVault.sol` declares everything an integrator calls — claiming, funding, pushing payouts, claim administration, and the state getters — so a caller imports one interface rather than a concrete contract and the whole graph behind it (CMTAT, the RuleEngine, the upgrade plumbing).

It is inherited by `IncomeVaultInternal`, the common base of both payout paths, so **the compiler** keeps it in step with the implementation rather than a convention doing it. That also means an embedded host presents the same API as the standalone vault — the two deployments are one interface, not two.

Both deployment variants advertise `type(IIncomeVault).interfaceId` through `supportsInterface`.

Three things are deliberately outside it:

| Left out | Why |
| --- | --- |
| `setOperator` / `isOperator`, and the signed variant | They belong to `IERC7540Operator` and `IERC7741`, implemented alongside. Restating a standardised name would fork it. |
| `transferDividendSelf` | `public` only because `try`/`catch` needs an external call; it rejects every caller but the contract itself. |
| Pause, freeze, `setRuleEngine`, the snapshot setter | Those belong to the standalone deployment's own modules, not to the distribution API an embedded host implements. |

The enum `TIME_ERROR_CODE` lives on the interface, because `validateTimeCode` returns it: a caller holding only the interface must be able to interpret the answer.

## Embedding the distribution logic in a token

`IncomeVault` is the standalone answer: a separate contract holding the payment token, reading balances from an external snapshot source, and running its own pause/freeze/RuleEngine stack. It is not the only one. A token that **already** has a validation stack and **already** records snapshots — a `CMTATUpgradeableInternalSnapshot`, for instance — can inherit `IncomeVaultOpen` and `IncomeVaultRestricted` directly and pay its own dividends, with no second contract, no second copy of the compliance rules and no snapshot address to keep in sync.

Two abstract contracts make that possible. Both **inherit nothing**, so a host answering them adds no bases of its own and cannot fail to linearize.

| Contract | Declares | The standalone answer | A CMTAT host's answer |
| --- | --- | --- | --- |
| `IncomeVaultValidationCore` | `_validateTransfer` | `IncomeVaultValidationModule`, built on the CMTAT `PauseModule`, `EnforcementModule` and RuleEngine | its own `canTransfer` |
| `IncomeVaultSnapshotCore` | `_snapshotInfo`, `_snapshotInfoBatch` (x2) | `IncomeVaultSnapshotModule`, an `ISnapshotSource` in storage | its own snapshot records |

The host then supplies the four `_authorize*` hooks with whatever access-control policy it already uses.

Neither split is cosmetic — each removed a hard compile failure:

- **Inheriting the policy** meant `IncomeVaultOpen` and `IncomeVaultRestricted` dragged `PauseModule` and `EnforcementModule` in transitively. A host that already had them could not linearize at all: `Error (5005)`, which no `override` list can repair.
- **Storing the source** meant a public `snapshotEngine()` getter. CMTAT declares a function with that exact name and the same parameters but a **different return type**, and Solidity cannot reconcile two functions that differ only in return type — again unresolvable by any override.

Renaming the getter to `dividendSnapshotSource()` and moving the source into its own ERC-7201 namespace removes both the collision and the storage slot, so a host that answers the hooks from itself never allocates one.

`test/mocks/CMTATDividendHostMock.sol` is a `CMTATUpgradeableInternalSnapshot` with the distribution logic embedded, and `test/mocks/EmbeddedDividendHostMock.sol` is the same without any CMTAT at all. Both exist only to **compile**: re-couple either dependency and they stop compiling.

## Improvement

- An automatic distribution of dividend could be performed through [Chainlink Automation](https://docs.chain.link/chainlink-automation) but it requires several changes to allow that.
- Only ERC20 tokens are supported. We could extends this to support direct native (e.g ether) too.

## Deployment

The contract has to be deployed with a transparent proxy and the contract is compatible with the standard [ERC-2771](https://eips.ethereum.org/EIPS/eip-2771) for meta transactions.

```
initialize(
    address admin,                        // `owner_` on IncomeVaultOwnable2Step
    IERC20 ERC20TokenPayment_,
    ISnapshotSource snapshotEngine_,
    IRuleEngine ruleEngine_,
    uint256 timeLimitToWithdraw_
)
```

### Deployment scripts

One script per variant, in [script](../script):

| Script | Deploys |
| --- | --- |
| `script/DeployIncomeVault.s.sol` | the role-based `IncomeVault` |
| `script/DeployIncomeVaultOwnable2Step.s.sol` | the single-owner `IncomeVaultOwnable2Step` |

Both use the same `Upgrades` plugin the tests use, so the deployment path is the tested one.

```bash
forge clean && forge build          # a FULL build: the upgrade-safety validation requires it

export PROXY_ADMIN=0x...            # owner of the ProxyAdmin, i.e. who may upgrade
export VAULT_ADMIN=0x...            # receives DEFAULT_ADMIN_ROLE (VAULT_OWNER for the Ownable variant)
export PAYMENT_TOKEN=0x...          # the ERC-20 dividends are paid in
export SNAPSHOT_ENGINE=0x...        # the ISnapshotSource
export TIME_LIMIT_TO_WITHDRAW=31536000
export FORWARDER=0x...              # optional, ERC-2771; omit to disable gasless support
export RULE_ENGINE=0x...            # optional; omit for no transfer restrictions

forge script script/DeployIncomeVault.s.sol --rpc-url <RPC> --broadcast --ffi
```

`--ffi` is required, as it is for the tests.

Before spending gas the script rejects a configuration the **contract cannot check for itself**: that `PAYMENT_TOKEN`, `SNAPSHOT_ENGINE` and any `RULE_ENGINE` are actually contracts. A mistyped address, or one copied from another chain, otherwise initializes cleanly and only reverts on the first claim.

`deploy(config)` is separated from the environment reading in `run()`, so `test/script/Deploy.t.sol` drives the same code an operator runs — including an end-to-end check that a vault the script produced actually pays a dividend.

 

## Threat model & FAQ

### Claim dividend several times

> What if a holder tries to claim the same dividend several times?

When a holder claims his dividends for a specific time, a boolean is set to true to indicate the claiming dividend.

```
 claimedDividend[tokenHolder][time] = true;
```

This boolean is set inside the internal function `_transferDividend`

Moreover, the functions to claim are protected against reentrancy attacks with the modifier `nonReentrant` from OpenZeppelin.

### New dividend after claim

> What happens if the authorized address deposit dividend after that a token holder has already claimed his dividends ?

A token holder can not claim his dividends if the claim status is not opened. Moreover, you can not deposit new dividends if the status is on open (=true).

The function `setStatusClaim` allows to open (true) or close(false) the claims for a specific time.

If you close the claim (claim status = false) and deposit new dividends, the previous token holders will be penalized since the dividends total supply for this specific time has improved for all token holders which have not already claimed their dividends,

In summary, when you have opened the claim, you should not deposit new dividends in the vault for a specific time.

### Transfer fails

> What happens if the token transfer fails?

In this case, the whole transaction is reverted, and the smart contract still considers that dividends have not been claimed by the token holder (sender).

## Technical choice

### Functionality

#### Upgradeable

The `IncomeVault` is upgradeable and can be deployed with a Transparent Proxy.

#### Version

Every deployment exposes its release version through the ERC-3643 `version()` view, the same way the CMTAT, the RuleEngine and the SnapshotEngine do:

```solidity
IERC3643Version(address(vault)).version()   // "1.1.0"
```

The value is the compile-time constant `VERSION` in `src/modules/VersionModule.sol`. Bump it together with the `CHANGELOG.md` heading of the release — the changelog checklist lists it as the first task.

#### Storage (ERC-7201)

The state of the vault is held in a single [ERC-7201](https://eips.ethereum.org/EIPS/eip-7201) namespaced storage struct, the pattern used by OpenZeppelin Upgradeable and by the CMTAT:

```solidity
// keccak256(abi.encode(uint256(keccak256("IncomeVault.storage.IncomeVaultInternal")) - 1)) & ~bytes32(uint256(0xff))
bytes32 private constant IncomeVaultInternalStorageLocation = 0xe4f8b033bcfc537db031b0e68e3c1ab0f1de86cf03893d031b6590510b0c0c00;

/// @custom:storage-location erc7201:IncomeVault.storage.IncomeVaultInternal
struct IncomeVaultInternalStorage {
    ISnapshotState _snapshotEngine;
    IERC20 _ERC20TokenPayment;
    mapping(address tokenHolder => mapping(uint256 time => bool claimed)) _claimedDividend;
    mapping(uint256 time => uint256 dividend) _segregatedDividend;
    mapping(uint256 time => bool status) _segregatedClaim;
    uint256 _timeLimitToWithdraw;
}
```

Because the namespace is derived from a hash, it cannot collide with the storage of the inherited CMTAT and OpenZeppelin modules, which use their own namespaces. Consequences:

- there is **no** `uint256[50] private __gap` anywhere, and the contract declares no sequential storage slot at all;
- a new field can simply be appended to the struct in a later version;
- the fields are read through the public getters `ERC20TokenPayment()`, `claimedDividend()`, `segregatedDividend()`, `segregatedClaim()` and `timeLimitToWithdraw()`, so the external interface is the same as if they were public state variables;
- **it is not the only namespace.** One capability owns one module and one namespace:

| Namespace | Owned by | Holds |
| --- | --- | --- |
| `IncomeVault.storage.IncomeVaultInternal` | `IncomeVaultInternal` | the distribution state: payment token, per-period deposits, claim flags, paid totals, open-period count, claim window |
| `IncomeVault.storage.SnapshotSource` | `IncomeVaultSnapshotModule` | the external `ISnapshotSource` |
| `IncomeVault.storage.Operator` | `IncomeVaultOperatorModule` | the claim-delegation authorisations |
| `IncomeVault.storage.ERC7741Module` | `ERC7741Module` | the consumed signature nonces |

  A host embedding only part of the logic allocates only the namespaces it inherits — a token that is its own snapshot source never allocates the second one at all. A new capability with state gets a new namespace, never a field appended to an existing struct.

The hardcoded slots are re-derived from their namespaces, checked to be disjoint, and compared against what the proxy really stores in `test/IncomeVaultStorage.t.sol`.

#### Urgency mechanism

Through the `PauseModule`, the contract can be put in pause (`PAUSER_ROLE`), forbidding all claims. A paused contract can also be permanently deactivated with `deactivateContract` (`DEFAULT_ADMIN_ROLE`).

#### Token agnostic

The vault reads the holder balances and the total supply through the `ISnapshotState` interface of the [SnapshotEngine](https://github.com/CMTA/SnapshotEngine), so it works with any contract implementing it and not only with the CMTAT. See [Snapshot source](#snapshot-source).

#### Reentrancy

`claimDividend` and `claimDividendBatch` are protected with `ReentrancyGuardTransient` (EIP-1153 transient storage). `ReentrancyGuardUpgradeable` was removed from OpenZeppelin Contracts Upgradeable v5.7.0; the transient variant is storage-free and therefore proxy safe.


#### Gasless support

> The gasless integration was not part of the audit performed by ABDK on the version [1.0.1](https://github.com/CMTA/RuleEngine/releases/tag/1.0.1)

The `IncomeVault` contract supports client-side gasless transactions using the [Gas Station Network](https://docs.opengsn.org/#the-problem) (GSN) pattern, the main open standard for transfering fee payment to another account than that of the transaction issuer. The contract uses the CMTAT `ERC2771Module`, a thin wrapper around the OpenZeppelin contract `ERC2771ContextUpgradeable`, which allows a contract to get the original client with `_msgSender()` instead of the fee payer given by `msg.sender` .

At deployment, the parameter `forwarder` inside the contract constructor has to be set with the defined address of the forwarder. Please note that the forwarder can not be changed after deployment.

Please see the OpenGSN [documentation](https://docs.opengsn.org/contracts/#receiving-a-relayed-call) for more details on what is done to support GSN in the contract.

**Gasless support is a deployment decision, not a property of the distribution logic.** `IncomeVaultBase` states what the vault does and knows nothing about forwarders; `IncomeVaultBaseERC2771` adds the ERC-2771 context on top of it and resolves the `ERC2771ContextUpgradeable` / `ContextUpgradeable` diamond. Both shipped deployments inherit the latter, so they behave exactly as described above. A deployment that does not want a trusted forwarder inherits `IncomeVaultBase` directly and carries none of the machinery — not an immutable forwarder address, not the calldata-suffix handling, not the `isTrustedForwarder` entry point. Before this split the only way to decline was to pass the zero address and pay for it anyway.

This matters beyond taste: **a trusted forwarder can name any `_msgSender()`**, so it is as privileged as every role behind it. A deployment with no need for meta-transactions should not carry one.

### Schema

> The diagrams below are generated from the sources. Regenerate them with `npm run uml` (UML class diagram) and the three scripts in [doc/script](./script) — they rebuild the full per-contract set under [doc/surya](./surya): call graphs, inheritance graphs and markdown reports.

#### UML

![uml](./schema/classDiagram.svg)

### Inheritance

#### IncomeVault

![surya_inheritance_IncomeVault](./surya/surya_inheritance/surya_inheritance_IncomeVault.sol.png)

#### IncomeVaultValidationModule

![surya_inheritance_IncomeVaultValidationModule](./surya/surya_inheritance/surya_inheritance_IncomeVaultValidationModule.sol.png)

### Graph

#### IncomeVault

![surya_graph_IncomeVault](./surya/surya_graph/surya_graph_IncomeVault.sol.png)

#### IncomeVaultOpen

![surya_graph_IncomeVaultOpen](./surya/surya_graph/surya_graph_IncomeVaultOpen.sol.png)

#### IncomeVaultRestricted

![surya_graph_IncomeVaultRestricted](./surya/surya_graph/surya_graph_IncomeVaultRestricted.sol.png)

#### IncomeVaultValidationModule

![surya_graph_IncomeVaultValidationModule](./surya/surya_graph/surya_graph_IncomeVaultValidationModule.sol.png)

### Report

A markdown report per contract (functions, visibility, modifiers) is available in [doc/surya/surya_report](./surya/surya_report).
