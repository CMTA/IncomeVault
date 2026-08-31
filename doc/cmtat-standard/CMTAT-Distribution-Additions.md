# Additions to the CMTAT Distribution module

> The contracts are **NOT audited**. Do not use them in production without an audit.

The CMTA framework functional specifications (June 2026) describe an optional **Distribution module** in section 3.2.4, with functionalities numbered 27 to 32 — see [`cmtat-framework-functional-specifications-june-2026.pdf`](./cmtat-framework-functional-specifications-june-2026.pdf).

This document holds the **additions**: behaviour with no counterpart in section 3.2.4 at all. No implementation can be conforming or non-conforming on these today, because the specification says nothing about them — each is a gap every implementer has had to fill privately, and privately means incompatibly.

The companion **amendments** — changes to functionalities the specification already defines, where a conforming implementation may already satisfy the proposal — are in [`CMTAT-Distribution-Amendments.md`](./CMTAT-Distribution-Amendments.md). The functionality-by-functionality comparison both came out of is in [`CMTAT-Distribution-impl.md`](./CMTAT-Distribution-impl.md).

One earlier proposal is split across the two documents: capping the claim period amends functionality 30 and is C-2 there, while recovering what is left after that cap is a new operation and is A-1 below.

## The specification text these refer to

Quoted from section 3.2.4 of [`cmtat-framework-functional-specifications-june-2026.pdf`](./cmtat-framework-functional-specifications-june-2026.pdf) so a proposal can be read without opening it. The PDF remains authoritative; square brackets are the specification's own.

> **3.2.4 Distribution module**
>
> Issuers may be required to make distributions to holders of securities (e.g. dividend payments for equity securities or interest payments for debt securities). Issuers may wish to carry out distributions off-chain (i.e. by transferring fiat currencies to the securities' holders' bank account). However, if the issuer intends to carry out such distributions on-chain, this may require the distribution of new tokens to existing token holders, on the basis of a snapshot carried out at the moment the legal entitlement to the distribution arises as not all token holders may be eligible for distributions.
>
> Distribution events are typically performed according to a predefined schedule, and according to the token distribution at a given time, which can be determined by a snapshot performed with the Snapshot module.
>
> **Functionalities**
>
> 27. **Distribution create parameters**: Define settlement token (i.e. the token that is to be distributed), identify a (past or future) block time/height for distribution snapshot, and amount to be distributed.
> 28. **Distribution set eligibility**: Flag a given users' tokens as being eligible or non-eligible to receive distributions (default: eligible).
> 29. **Distribution set deposit**: Send deposit amount for claiming settlement tokens to token holders flagged as eligible.
> 30. **Distribution claim deposit**: Allow token holders to claim their share of a deposit, identified by a deposit Identification, according to the token balance at the snapshot created at the defined time/height.
>
> Additional use cases for tokens representing debt instruments:
>
> 31. **Distribution schedule**: Define a schedule for interest payments [and repayment of the par value at maturity], based on the token attributes.
> 32. **Distribution unschedule**: Cancel the previously set schedule for interest payments [and repayment of the principal amount at maturity].

## The additions

| id | Proposal | Why — what implementing it exposed |
| --- | --- | --- |
| A-1 | **Recovery of what is not claimed**, once the claim period has closed | The specification never says where unclaimed funds end up. Rounding residue and the shares of holders who never claim would otherwise stay locked in the contract permanently. Pairs with C-2, which is what makes "closed" meaningful, and with C-3, which makes the residue a known quantity. `IncomeVault` bounds recovery per period by `unclaimedDividend(time)`. |
| A-2 | **A push counterpart to the pull claim of 30** | Functionality 30 is pull-only, which strands holders who never transact — custodied positions, dormant addresses, holders without gas. A distribution mechanism that requires every beneficiary to act is not one an issuer can rely on to discharge an obligation. |
| A-3 | **Delegated claiming: who may claim on a holder's behalf** | Follows from A-2. A holder who cannot pay gas, or cannot transact at all, still has to be paid. `IncomeVault` uses ERC-7540's `setOperator` and ERC-7741's signed authorisation, with the payout always going to the holder rather than the operator. The specification names no mechanism, so every implementation invents one and none of them interoperate. |

These three are not defects in an implementation — they are places where the specification stops short of what an issuer needs to discharge a real obligation. A-1 depends on the claim period actually closing, which is C-2 in the amendments; A-3 follows from A-2, since a push payout and a delegated claim answer the same problem for the same holders.
