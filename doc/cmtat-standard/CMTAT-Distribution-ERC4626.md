# Holding a distribution deposit in an ERC-4626 vault

> The contracts are **NOT audited**. Do not use them in production without an audit.

Between functionality 29 (the issuer sends the deposit) and functionality 30 (holders claim it), the settlement tokens sit idle in the contract — for a coupon with a long claim period, potentially months. Whether an implementation may put that float to work, and what happens if it does, is a question the CMTA framework functional specifications (June 2026) do not answer.

This document is that question in full. It is the evidence behind amendment **C-9** in [`CMTAT-Distribution-Amendments.md`](./CMTAT-Distribution-Amendments.md); the functionality-by-functionality comparison it came out of is [`CMTAT-Distribution-impl.md`](./CMTAT-Distribution-impl.md), and the three additions the specification does not describe at all are in [`CMTAT-Distribution-Additions.md`](./CMTAT-Distribution-Additions.md).

Why `IncomeVault` is not itself an ERC-4626 vault is a different question, answered in [*Comparison with ERC-4626 / ERC-7540 vaults*](../README.md#comparison-with-erc-4626--erc-7540-vaults). This document is only about what the **deposit** is held as.

## The specification text this refers to

Quoted from section 3.2.4 of [`cmtat-framework-functional-specifications-june-2026.pdf`](./cmtat-framework-functional-specifications-june-2026.pdf), so the question can be read without opening it. The float exists in the window between 29 and 30, and 27 is what names the token it is held in.

> 27. **Distribution create parameters**: Define settlement token (i.e. the token that is to be distributed), identify a (past or future) block time/height for distribution snapshot, and amount to be distributed.
> 29. **Distribution set deposit**: Send deposit amount for claiming settlement tokens to token holders flagged as eligible.
> 30. **Distribution claim deposit**: Allow token holders to claim their share of a deposit, identified by a deposit Identification, according to the token balance at the snapshot created at the defined time/height.

None of the three says what form the deposit is held in between 29 and 30, nor constrains the settlement token of 27 to be a plain ERC-20.

## The ERC-4626 requirements this refers to

Quoted from [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626), as reproduced in the OpenZeppelin `IERC4626` interface this project builds against. These four are the ones that decide the question.

> **`asset()`** — Returns the address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
> - MUST be an ERC-20 token contract.
> - MUST NOT revert.

> **`totalAssets()`** — Returns the total amount of the underlying asset that is "managed" by Vault.
> - SHOULD include any compounding that occurs from yield.

> **`previewRedeem(shares)`** — Allows an on-chain or off-chain user to simulate the effects of their redemption at the current block, given current on-chain conditions.
> - MUST return as close to and no more than the exact amount of assets that would be withdrawn in a redeem call in the same transaction.
> - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
>
> NOTE: any unfavorable discrepancy between `convertToAssets` and `previewRedeem` SHOULD be considered slippage in share price or some other type of condition, meaning **the depositor will lose assets by redeeming**.

> **`redeem(shares, receiver, owner)`** — Burns exactly shares from owner and sends assets of underlying tokens to receiver.

`totalAssets()` including yield is the whole attraction. The other three are why the naive version is unsafe: redemption is the only way out and it burns, the amount out is bounded above but never below, and the standard's own note says the depositor can lose assets by redeeming.

## The question

Functionality 29 has the issuer send the deposit, and 30 has holders claim it later. Between those two the settlement tokens sit idle in the contract — for a coupon with a long claim period, potentially months. An implementation could hold that float as shares of an [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) vault and redeem on each payout, so undistributed funds earn yield instead of nothing.

The specification says nothing about this, and it should, because the naive version is unsafe.

**The obligation is a fixed nominal amount; 4626 shares are not.** At `deposit` the issuer records an amount owed per holder. Shares carry share-price risk, so a loss in the underlying vault leaves the contract unable to pay what it recorded. A bookkeeping contract becomes one that can run a deficit, and the holders who claim last absorb it. Doing this safely needs a buffer policy and an explicit rule for who covers a shortfall — a materially larger design than section 3.2.4 describes. `IncomeVault` deliberately does not implement it; the reasoning is in [`doc/README.md`](../README.md#comparison-with-erc-4626--erc-7540-vaults).

**A separate case: the settlement token *is* a vault share.** Nothing stops an issuer distributing a yield-bearing token — `DebtInstrument.currencyContract` can point at an ERC-4626 vault, and functionality 27's settlement token has no constraint. Then "amount to be distributed" is ambiguous: shares or assets? A share-denominated obligation is fixed in shares and floats in value; an asset-denominated one is the reverse, and requires converting at some moment the specification would have to name. Rounding direction matters here too, since 4626 rounds in the vault's favour by design and a claim rounds in the issuer's. This is amendment **C-9**.

**What is worth stating either way:** whether the deposit for a distribution must be held as the settlement token itself, or may be held in another form and converted at payout. The answer decides whether a shortfall is possible at all, and it is invisible to a holder reading the contract.
