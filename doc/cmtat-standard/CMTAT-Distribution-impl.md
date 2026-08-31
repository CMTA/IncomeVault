# The CMTAT Distribution module, as implemented by `IncomeVault`

> The contracts are **NOT audited**. Do not use them in production without an audit.

The CMTA framework functional specifications (June 2026) describe an optional **Distribution module** in section 3.2.4, with functionalities numbered 27 to 32 — see [`cmtat-framework-functional-specifications-june-2026.pdf`](./cmtat-framework-functional-specifications-june-2026.pdf).

This document is the long form of the comparison summarised in [`doc/README.md`](../README.md#coverage-of-the-cmtat-distribution-module). It states which parts of the module `IncomeVault` covers, which it answers differently, which it does not implement, what it adds that the specification does not describe, and the changes we would propose to the specification as a result of implementing it.

## Coverage, functionality by functionality

| # | Specification | Status | In `IncomeVault` |
| --- | --- | --- | --- |
| 27 | **Distribution create parameters** — settlement token, a past or future block time/height for the snapshot, and the amount | ◑ partial | The `time` and the amount are per distribution: `deposit(time, amount)`. The **settlement token is not** — `ERC20TokenPayment` is fixed once at `initialize` for the whole vault. One vault distributes one token. |
| 28 | **Distribution set eligibility** — flag a user's tokens eligible or non-eligible, default eligible | ◑ different mechanism | No per-distribution flag. Eligibility is evaluated **at payout time** by `IncomeVaultValidationModule`: pause state, address freeze, and an optional `IRuleEngine.canTransfer`. Default is eligible. |
| 29 | **Distribution set deposit** — send the deposit for claiming by eligible holders | ● implemented | `deposit(time, amount)`, and `depositBatch(times, amounts)` for several dates in one transaction. Gated by `_authorizeDeposit`. Funds are segregated per `time`. |
| 30 | **Distribution claim deposit** — holders claim their share of a deposit, identified by a deposit id, per the snapshot balance | ● implemented | `claimDividend(time)` / `claimDividendBatch(times)`. The deposit id **is** the `time`. Share is `balance * segregatedDividend[time] / totalSupply`, rounded down. |
| 31 | **Distribution schedule** *(debt instruments)* — a schedule for interest payments and repayment at maturity | ○ not implemented | Each distribution is funded explicitly. `depositBatch` funds several dates in one call but creates no recurring schedule. The parameters for one already exist elsewhere in the framework — see [below](#functionalities-31-and-32-need-no-new-state). |
| 32 | **Distribution unschedule** *(debt instruments)* — cancel that schedule | ○ not implemented | Nothing to cancel here. On the Snapshot module it already exists as `unscheduleSnapshotNotOptimized(time)`; in the vault the nearest operations are `setStatusClaim(time, false)` and `withdraw` / `withdrawAll`. |

Legend: ● implemented, ◑ partial or answered differently, ○ not implemented.

## The two gaps

**One settlement token per vault (27).** The specification lets each distribution name its own settlement token; here the token is chosen at deployment. An issuer distributing in two currencies deploys two vaults. This is a deliberate simplification, not an oversight: making the token per-`time` would put a second address in every accounting entry and make `withdrawAll` ambiguous about which balance it sweeps.

**No payment schedule (31, 32).** Both are listed by the specification as *additional* use cases for debt instruments, and both belong more naturally beside the Debt module than beside distribution: a coupon schedule is derived from the instrument's terms, which `IncomeVault` does not hold. The vault is the settlement half — given a date and an amount, it segregates, restricts and pays. Scheduling is left to whatever produces those dates.

## What `IncomeVault` adds beyond the specification

The specification defines the minimum; several behaviours here have no counterpart in it and are answers to questions it leaves open.

| Capability | Why it exists |
| --- | --- |
| **Claim window** — `setStatusClaim`, `timeLimitToWithdraw`, `validateTime(Code\|Batch)` | The specification says when a holder becomes entitled, not for how long. Claims are refused before `time` (the snapshot would not exist, so balances would be read live and be wrong) and after `time + timeLimitToWithdraw`. |
| **Issuer recovery** — `withdraw`, `withdrawAll` | The specification is silent on unclaimed funds. Rounding dust and unclaimed shares would otherwise be locked forever. Bounded per period by `unclaimedDividend(time)`. |
| **Push distribution** — `distributeDividend`, `distributeDividendBestEffort` | Lets the issuer pay holders who never transact. The best-effort variant skips a blocked holder instead of reverting the batch. |
| **Claim delegation** — ERC-7540 `setOperator`, ERC-7741 signed authorisation | A holder who cannot pay gas, or cannot transact at all, can still be paid. Payouts always go to the holder. |
| **Per-period accounting** — `segregatedDividend`, `paidDividend`, `unclaimedDividend`, `openClaimCount` | Makes "how much of this period is left" answerable on-chain, which the pro-rata denominator alone cannot answer. |
| **Restricted payouts** | The specification treats eligibility as a flag; here a payout is a transfer and passes the same pause / freeze / RuleEngine checks a token transfer would. |

## Functionalities 31 and 32 need no new state

Both look like missing features, but the parameters a payment schedule needs **already exist** in the CMTAT framework — split across two other modules. What is missing is the link between them, and in one case the type.

| A schedule needs | Where it already lives | Type |
| --- | --- | --- |
| The dates themselves | `SnapshotEngine.getAllSnapshots()` / `getNextSnapshots()` | `uint256[]` — **machine-readable** |
| Coupon frequency | `ICMTATDebt.DebtInstrument.couponPaymentFrequency` | `string` |
| Accrual schedule (formats A / B / C) | `DebtInstrument.interestScheduleFormat` | `string` |
| Payment date, when it differs from accrual | `DebtInstrument.interestPaymentDate` | `string` |
| Maturity, for the final repayment | `DebtInstrument.maturityDate` | `string` |
| Rate and par value | `DebtInstrument.interestRate`, `parValue` | `uint256` |
| **Settlement token** | `DebtInstrument.currencyContract` | `address` |

Two consequences follow.

**The Debt module already holds the terms, but as prose.** Every schedule field is a `string`. That is enough for a human, a prospectus or an off-chain agent, and it is deliberate — the CMTA formats A/B/C are descriptive. It is *not* enough for a contract: nothing can iterate `interestScheduleFormat` to learn that a payment falls due next Tuesday. So the Debt module can carry the parameters of functionality 31 today, and the CMTAT reference implementation would need no new storage — but a contract cannot act on them.

**The Snapshot module already holds the dates, and in the right type.** `getNextSnapshots()` returns the scheduled record dates as sorted `uint256` timestamps. That *is* the executable half of a distribution schedule, and it already exists on-chain. Functionality **32 (unschedule)** maps almost exactly onto `unscheduleSnapshotNotOptimized(time)`: cancelling the record date cancels the distribution, as long as nothing has been deposited for it.

So the proposal is not "add a scheduler" — see amendment C-7 in *Changes we would propose to the standard*. It is: **specify 31 and 32 as derived rather than stored** — the dates are the scheduled snapshots, the terms are the debt attributes, and a distribution schedule is the join of the two plus an amount per date. That keeps one source of truth for record dates, which matters because a second list could disagree with the snapshots the balances are actually read from.

`IncomeVault` implements neither, and does not read the schedule at all: `ISnapshotSource` is deliberately the three balance-reading functions and nothing else.

## Where the module lives

The specification presents Distribution as an **optional module of a CMTAT**. This project ships it as a separate contract, so an existing token needs no upgrade and the distribution logic can be redeployed independently. Since the modularity work it is also embeddable: a CMTAT with internal snapshots can inherit `IncomeVaultOpen` and `IncomeVaultRestricted` and pay its own dividends, with no second contract — see [*Embedding the distribution logic in a token*](../README.md#embedding-the-distribution-logic-in-a-token). Both shapes use the same `IIncomeVault` API.

Note also that the vault **never schedules snapshots**. Specification functionalities 15 to 17 (schedule / reschedule / unschedule) belong to the Snapshot module; the vault only reads, through the three functions of `ISnapshotSource`. The issuer schedules the snapshot on the snapshot source, then deposits for the same `time`.

## Eligibility without a snapshot

Section 3.2.4 ties distribution to the Snapshot module: functionality 27 identifies "a (past or future) block time/height for distribution snapshot", and 30 pays "according to the token balance at the snapshot created at the defined time/height". Snapshots are the right default — they are on-chain, verifiable by anyone, and need no trusted party. They should not be the only permitted mechanism.

A record date fixes *which balances count*. Taking an on-chain snapshot is one way to answer that; it is not the only one, and for some issuers it is the wrong one:

- **Balances pinned off-chain at a block height.** The register is read at a block, the entitlement computed off-chain, and the result published — as a list written into a contract, or as a merkle root claimed against. Nothing is snapshotted on-chain, yet the record date is exactly as well defined, because a block height is immutable.
- **Registers that are not fully on-chain.** Where part of the holder base is held through a custodian or a book-entry register, the eligible set is not the token balance and no on-chain snapshot can produce it.
- **Entitlements that are not proportional to balance.** Different share classes, a cap per holder, or a withholding rate that varies by jurisdiction. The pro-rata assumption is the Snapshot module's, not the issuer's.

**What the specification should say.** Keep the snapshot as the recommended binding, and restate 27 and 30 in terms of a *record-date balance source* that a snapshot satisfies — rather than naming the Snapshot module as the mechanism. The obligation that matters is not "a snapshot exists" but "the balances used are fixed at the record date and cannot change afterwards". That is what makes the payout reproducible, and an off-chain pinning at a block height satisfies it as completely as a snapshot does. This is why amendment **C-1** is phrased against a resolved balance source rather than against a snapshot.

**Where `IncomeVault` sits.** It is already source-agnostic in principle: it never calls the token, only `ISnapshotSource`, and the guide is explicit that any contract implementing those three functions works. The limit is in the shape rather than the coupling. `snapshotInfo(time, holder)` must answer **on-chain, from stored state**, and `claimDividend(uint256 time)` carries no proof argument. So:

- balances **computed** off-chain and then **written** into a contract implementing `ISnapshotSource` work today, unchanged;
- a **merkle root** claimed against does not, because the proof would have to travel with the claim — that needs `claimDividend(time, amount, proof)`, a different entry point, not a different source.

A specification that permits both should say which of the two it means, since they imply different claim signatures.

## Holding the deposit in an ERC-4626 vault

Functionality 29 has the issuer send the deposit, and 30 has holders claim it later. Between those two the settlement tokens sit idle in the contract — for a coupon with a long claim period, potentially months. An implementation could hold that float as shares of an [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) vault and redeem on each payout, so undistributed funds earn yield instead of nothing.

The specification says nothing about this, and it should, because the naive version is unsafe.

**The obligation is a fixed nominal amount; 4626 shares are not.** At `deposit` the issuer records an amount owed per holder. Shares carry share-price risk, so a loss in the underlying vault leaves the contract unable to pay what it recorded. A bookkeeping contract becomes one that can be short, and the holders who claim last absorb it. Doing this safely needs a buffer policy and an explicit rule for who covers a shortfall — a materially larger design than section 3.2.4 describes. `IncomeVault` deliberately does not implement it; the reasoning is in [`doc/README.md`](../README.md#comparison-with-erc-4626--erc-7540-vaults).

**A separate case: the settlement token *is* a vault share.** Nothing stops an issuer distributing a yield-bearing token — `DebtInstrument.currencyContract` can point at an ERC-4626 vault, and functionality 27's settlement token has no constraint. Then "amount to be distributed" is ambiguous: shares or assets? A share-denominated obligation is fixed in shares and floats in value; an asset-denominated one is the reverse, and requires converting at some moment the specification would have to name. Rounding direction matters here too, since 4626 rounds in the vault's favour by design and a claim rounds in the issuer's. This is amendment **C-9**.

**What is worth stating either way:** whether the deposit for a distribution must be held as the settlement token itself, or may be held in another form and converted at payout. The answer decides whether a shortfall is possible at all, and it is invisible to a holder reading the contract.

## Changes we would propose to the standard

Twelve proposals, of two kinds, kept apart because they carry different weight. An **amendment** constrains or clarifies a functionality the specification already defines, and a conforming implementation may already satisfy it — the specification just does not say so. An **addition** describes behaviour with no counterpart in section 3.2.4 at all, so no implementation can be conforming or non-conforming today; each one is a gap every implementer has had to fill privately.

Old proposal 2 is split across the two tables: capping the claim period amends functionality 30, but recovering what is left afterwards is a new operation.

### Amendments to functionalities already in the specification

The nine amendments — C-1 to C-9, each naming the functionality it changes — are in [`CMTAT-Distribution-Amendments.md`](./CMTAT-Distribution-Amendments.md), so a reader taking them to the specification is not carrying the whole comparison with them. In short:

| id | Amends | Proposal |
| --- | --- | --- |
| C-1 | 27, 30 | Require a record date to resolve against balances that are already fixed, and reject one that is not |
| C-2 | 30 | Cap the claim period with a deadline after which a claim is refused |
| C-3 | 30 | State the rounding direction for a holder's share |
| C-4 | 28 | Say whether eligibility is per distribution or per address, and when it is evaluated |
| C-5 | 29 | Forbid, or define, topping up a distribution whose claiming is already open |
| C-6 | 27 + debt attributes | Reconcile the settlement token: per distribution, or per instrument? |
| C-7 | 31, 32 | Specify them as derived from the Snapshot and Debt modules, not as a store of their own |
| C-8 | Debt attributes | Give the schedule fields a machine-readable form alongside the descriptive strings |
| C-9 | 27, 29 | Say whether the deposit must be held as the settlement token, and what `amount` means when that token is itself a vault share |

**C-1 and C-5 can cause value to move incorrectly**; the other seven leave a question open. The reasoning for each is in the linked document.

### Additions — behaviour the specification does not describe at all

| id | Proposal | Why — what implementing it exposed |
| --- | --- | --- |
| A-1 | **Recovery of what is not claimed**, once the claim period has closed | The specification never says where unclaimed funds end up. Rounding residue and the shares of holders who never claim would otherwise stay locked in the contract permanently. Pairs with C-2, which is what makes "closed" meaningful, and with C-3, which makes the residue a known quantity. `IncomeVault` bounds recovery per period by `unclaimedDividend(time)`. |
| A-2 | **A push counterpart to the pull claim of 30** | Functionality 30 is pull-only, which strands holders who never transact — custodied positions, dormant addresses, holders without gas. A distribution mechanism that requires every beneficiary to act is not one an issuer can rely on to discharge an obligation. |
| A-3 | **Delegated claiming: who may claim on a holder's behalf** | Follows from A-2. A holder who cannot pay gas, or cannot transact at all, still has to be paid. `IncomeVault` uses ERC-7540's `setOperator` and ERC-7741's signed authorisation, with the payout always going to the holder rather than the operator. The specification names no mechanism, so every implementation invents one and none of them interoperate. |

The three additions are not defects in an implementation — they are places where the specification stops short of what an issuer needs to discharge a real obligation.
