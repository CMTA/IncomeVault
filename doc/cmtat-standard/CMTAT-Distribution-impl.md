# The CMTAT Distribution module, as implemented by `IncomeVault`

> The contracts are **NOT audited**. Do not use them in production without an audit.

The CMTA framework functional specifications (June 2026) describe an optional **Distribution
module** in section 3.2.4, with functionalities numbered 27 to 32 — see
[`cmtat-framework-functional-specifications-june-2026.pdf`](./cmtat-framework-functional-specifications-june-2026.pdf).

This document is the long form of the comparison summarised in
[`doc/README.md`](../README.md#coverage-of-the-cmtat-distribution-module). It states which parts of
the module `IncomeVault` covers, which it answers differently, which it does not implement, what it
adds that the specification does not describe, and the changes we would propose to the specification
as a result of implementing it.

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

**One settlement token per vault (27).** The specification lets each distribution name its own
settlement token; here the token is chosen at deployment. An issuer distributing in two currencies
deploys two vaults. This is a deliberate simplification, not an oversight: making the token
per-`time` would put a second address in every accounting entry and make `withdrawAll` ambiguous
about which balance it sweeps.

**No payment schedule (31, 32).** Both are listed by the specification as *additional* use cases for
debt instruments, and both belong more naturally beside the Debt module than beside distribution: a
coupon schedule is derived from the instrument's terms, which `IncomeVault` does not hold. The vault
is the settlement half — given a date and an amount, it segregates, restricts and pays. Scheduling
is left to whatever produces those dates.

## What `IncomeVault` adds beyond the specification

The specification defines the minimum; several behaviours here have no counterpart in it and are
answers to questions it leaves open.

| Capability | Why it exists |
| --- | --- |
| **Claim window** — `setStatusClaim`, `timeLimitToWithdraw`, `validateTime(Code\|Batch)` | The specification says when a holder becomes entitled, not for how long. Claims are refused before `time` (the snapshot would not exist, so balances would be read live and be wrong) and after `time + timeLimitToWithdraw`. |
| **Issuer recovery** — `withdraw`, `withdrawAll` | The specification is silent on unclaimed funds. Rounding dust and unclaimed shares would otherwise be locked forever. Bounded per period by `unclaimedDividend(time)`. |
| **Push distribution** — `distributeDividend`, `distributeDividendBestEffort` | Lets the issuer pay holders who never transact. The best-effort variant skips a blocked holder instead of reverting the batch. |
| **Claim delegation** — ERC-7540 `setOperator`, ERC-7741 signed authorisation | A holder who cannot pay gas, or cannot transact at all, can still be paid. Payouts always go to the holder. |
| **Per-period accounting** — `segregatedDividend`, `paidDividend`, `unclaimedDividend`, `openClaimCount` | Makes "how much of this period is left" answerable on-chain, which the pro-rata denominator alone cannot answer. |
| **Restricted payouts** | The specification treats eligibility as a flag; here a payout is a transfer and passes the same pause / freeze / RuleEngine checks a token transfer would. |

## Functionalities 31 and 32 need no new state

Both look like missing features, but the parameters a payment schedule needs **already exist** in
the CMTAT framework — split across two other modules. What is missing is the link between them, and
in one case the type.

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

**The Debt module already holds the terms, but as prose.** Every schedule field is a `string`. That
is enough for a human, a prospectus or an off-chain agent, and it is deliberate — the CMTA formats
A/B/C are descriptive. It is *not* enough for a contract: nothing can iterate
`interestScheduleFormat` to learn that a payment falls due next Tuesday. So the Debt module can
carry the parameters of functionality 31 today, and the CMTAT reference implementation would need no
new storage — but a contract cannot act on them.

**The Snapshot module already holds the dates, and in the right type.** `getNextSnapshots()` returns
the scheduled record dates as sorted `uint256` timestamps. That *is* the executable half of a
distribution schedule, and it already exists on-chain. Functionality **32 (unschedule)** maps almost
exactly onto `unscheduleSnapshotNotOptimized(time)`: cancelling the record date cancels the
distribution, as long as nothing has been deposited for it.

So the proposal is not "add a scheduler" — see item 9 of *Changes we would propose to the standard*.
It is: **specify 31 and 32 as derived rather than stored** — the dates are the scheduled snapshots,
the terms are the debt attributes, and a distribution schedule is the join of the two plus an amount
per date. That keeps one source of truth for record dates, which matters because a second list could
disagree with the snapshots the balances are actually read from.

`IncomeVault` implements neither, and does not read the schedule at all: `ISnapshotSource` is
deliberately the three balance-reading functions and nothing else.

## Where the module lives

The specification presents Distribution as an **optional module of a CMTAT**. This project ships it
as a separate contract, so an existing token needs no upgrade and the distribution logic can be
redeployed independently. Since the modularity work it is also embeddable: a CMTAT with internal
snapshots can inherit `IncomeVaultOpen` and `IncomeVaultRestricted` and pay its own dividends, with
no second contract — see
[*Embedding the distribution logic in a token*](../README.md#embedding-the-distribution-logic-in-a-token).
Both shapes use the same `IIncomeVault` API.

Note also that the vault **never schedules snapshots**. Specification functionalities 15 to 17
(schedule / reschedule / unschedule) belong to the Snapshot module; the vault only reads, through
the three functions of `ISnapshotSource`. The issuer schedules the snapshot on the snapshot source,
then deposits for the same `time`.

## Changes we would propose to the standard

Each of these is something the specification leaves open and an implementation is forced to decide.
They are ordered by how much damage the ambiguity can do.

| # | Proposal | Why — what implementing it exposed |
| --- | --- | --- |
| 1 | **Require a distribution's record date to reference an existing snapshot**, and require implementations to reject one that does not | A snapshot lookup for a time that was never scheduled does not fail — `SnapshotEngine` returns the holder's **live balance** (`_snapshotBalanceOf` ends `return snapshotted ? value : ownerBalance`). A distribution funded against a mistyped date therefore pays out pro-rata to balances *at claim time*, which anyone can change by acquiring tokens before claiming. The specification should make the record date a reference to a snapshot, not a free timestamp. |
| 2 | **Define the claim period, and what happens to what is not claimed** | Functionality 30 says holders may claim; it never says until when, or where unclaimed funds end up. Without a deadline a distribution is an open liability forever. `IncomeVault` adds `timeLimitToWithdraw` plus issuer recovery bounded per period. |
| 3 | **State the rounding rule and the destination of the residue** | Pro-rata division always leaves dust. The specification is silent, so two conforming implementations can disagree on who gets it. State that shares round **down** and that the remainder is recoverable by the issuer. |
| 4 | **Say whether eligibility (28) is per distribution or per address, and when it is evaluated** | A flag set in advance and a check performed at payout behave differently: an address frozen between the record date and the claim is eligible under one reading and not the other. `IncomeVault` evaluates at payout, through the same pause / freeze / RuleEngine path a transfer takes. |
| 5 | **Forbid, or define, topping up a distribution whose claiming is already open** | Nothing in 29 prevents a second deposit after holders have begun claiming. Those who already claimed took their share of the smaller amount; those who had not take a share of the larger. The specification should either forbid it or define the accounting. |
| 6 | **Add a push counterpart to the pull claim of 30** | Functionality 30 is pull-only, which strands holders who never transact — custodied positions, dormant addresses, holders without gas. A distribution mechanism that requires every beneficiary to act is not one an issuer can rely on to discharge an obligation. |
| 7 | **Define delegation: who may claim on a holder's behalf** | Follows from 6. `IncomeVault` uses ERC-7540's `setOperator` and ERC-7741's signed authorisation, with the payout always going to the holder. The specification names no mechanism, so every implementation invents one. |
| 8 | **Say whether the settlement token is per distribution or per instrument** | Functionality 27 puts it per distribution; `DebtInstrument.currencyContract` puts it per instrument, and is already an `address` rather than a string. These are two different data models for the same thing and should be reconciled. |
| 9 | **Specify 31 and 32 as derived from the Snapshot and Debt modules** | See above. The dates exist as `uint256[]`, the terms exist as strings; the specification should say so rather than implying a third store. |
| 10 | **Give the schedule fields a machine-readable form**, alongside the descriptive strings | `couponPaymentFrequency`, `interestScheduleFormat` and `interestPaymentDate` are prose. Any automation — a keeper funding coupons, a contract asserting the next payment date — must parse them off-chain and be trusted. An optional structured form would make 31 executable without removing the human-readable one. |

Proposals 1 and 5 can cause value to move incorrectly. The rest leave a question open.

