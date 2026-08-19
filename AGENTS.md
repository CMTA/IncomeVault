# IncomeVault — Agent Guide

> **Note — keep in sync:** `AGENTS.md` and `CLAUDE.md` must always be **identical**.
> Any edit to one must be applied verbatim to the other.

> **Note — commit messages:** After each group of modifications or each feature
> added, always provide a **one-line GitHub commit message** (Conventional-Commits
> style, e.g. `feat: ...`, `fix: ...`, `docs: ...`).

## What this project is

`IncomeVault` is a CMTA prototype smart contract that distributes coupon/dividend
payments to holders of a [CMTAT](https://github.com/CMTA/CMTAT) security token.
Dividends are deposited in the vault in an **ERC-20 payment token** (e.g. USDC),
segregated per distribution date (`time`), and claimed by holders pro-rata using
the CMTAT **snapshot module** (`ICMTATSnapshot.snapshotInfo`).

> **The contracts are NOT audited.** Do not present them as production-ready.

## Key concepts

- **Segregated deposits by `time`** — `time` is a Unix timestamp identifying a
  distribution. State is keyed by it: `segregatedDividend[time]`,
  `segregatedClaim[time]`, `claimedDividend[holder][time]`.
- **Claim flow** — admin registers a CMTAT snapshot at `time` → deposit role calls
  `deposit(time, amount)` → operator calls `setStatusClaim(time, true)` → holders
  call `claimDividend(time)` / `claimDividendBatch(times)`.
- **Pro-rata formula** — `senderDividend = (senderCMTATBalance * segregatedDividend[time]) / tokenTotalSupply`,
  rounded down. Dust stays in the vault; the issuer withdraws it after `timeLimitToWithdraw`.
- **Claim window** — `validateTime` / `validateTimeCode` reject a claim when the
  claim is not activated, `block.timestamp < time` (too early), or
  `block.timestamp > time + timeLimitToWithdraw` (too late).
- **Access control** — OpenZeppelin `AccessControl` via CMTAT's `AuthorizationModule`.
  Roles: `DEFAULT_ADMIN_ROLE`, `INCOME_VAULT_OPERATOR_ROLE`,
  `INCOME_VAULT_DEPOSIT_ROLE`, `INCOME_VAULT_WITHDRAW_ROLE`,
  `INCOME_VAULT_DISTRIBUTE_ROLE`.
- **Transfer restriction** — a claim is treated as a transfer from the vault to the
  holder and goes through CMTAT's `ValidationModule._operateOnTransfer` (pause,
  freeze, RuleEngine rules such as whitelist/blacklist/sanction list).
- **Upgradeable** — deployed behind an OpenZeppelin **Transparent Proxy**;
  `initialize(...)` replaces the constructor, every contract reserves a
  `uint256[50] private __gap`.
- **Gasless / meta-tx** — inherits CMTAT's `MetaTxModule` (ERC-2771). The
  forwarder address is set in the constructor and is **immutable**. `_msgSender()`,
  `_msgData()` and `_contextSuffixLength()` are overridden to resolve the
  `ERC2771ContextUpgradeable` / `ContextUpgradeable` diamond.
- **Reentrancy** — claims use `nonReentrant`; `_transferDividend` sets
  `claimedDividend[holder][time] = true` *before* the ERC-20 transfer.

## File tree

```
src/
├── IncomeVault.sol                        # Entry point: constructor(forwarder), initialize(), _msgSender/_msgData overrides
├── public/
│   ├── IncomeVaultOpen.sol                # Permissionless: claimDividend, claimDividendBatch, validateTime(Code|Batch)
│   └── IncomeVaultRestricted.sol          # Role-gated: deposit, withdraw, withdrawAll, distributeDividend,
│                                          #   setStatusClaim, setTimeLimitToWithdraw
└── libraries/
    ├── IncomeVaultInternal.sol            # Storage (CMTAT_TOKEN, ERC20TokenPayment, mappings) + _computeDividend(Batch), _transferDividend
    └── IncomeVaultInvariantStorage.sol    # Role constants, custom errors, events

test/
├── HelperContract.sol                     # Shared constants, test addresses, CMTAT/payment-token handles
├── IncomeVault.t.sol                      # Single claim: deposit, claim, error cases
├── IncomeVaultBatch.t.sol                 # claimDividendBatch behaviour
├── IncomeVaultRestricted.t.sol            # Access control, deposit/withdraw/withdrawAll, setStatusClaim
└── RuleEngineIntegration.t.sol            # End-to-end with RuleEngine + RuleWhitelist
```

Tests deploy the vault through `Upgrades` (openzeppelin-foundry-upgrades), which
is why `--ffi` is required and why `forge coverage` does not work here.

## Other important files

| Path | Purpose |
| --- | --- |
| `foundry.toml` | solc 0.8.22, optimizer 200 runs, EVM `london`, `build_info`, `storageLayout`, `fs_permissions` on `./out` (needed by OZ Upgrades) |
| `remappings.txt` | `CMTAT/`, `RuleEngine/`, `OZ/`, `OZUpgradeable/`, `@openzeppelin/contracts-upgradeable/` |
| `hardhat.config.js` | Only used for `solidity-docgen` (`npx hardhat docgen`), mirrors the Foundry solc settings |
| `package.json` | npm scripts: lint (ethlint/prettier), `uml`, `surya:*`, `docgen` |
| `.soliumrc.json`, `.soliumignore` | Ethlint/Solium configuration |
| `CHANGELOG.md` | changelog.md conventions; current release `1.0.0` |
| `doc/specification.md` | Roles table, claim restrictions, formula, threat model & FAQ |
| `doc/technical.md` | Upgradeability, pause, gasless (GSN/ERC-2771) design notes |
| `doc/TOOLCHAIN.md` | Tested dependency versions, doc-generation and lint commands |
| `doc/solidityAPI/index.md` | Generated Solidity API (docgen) |
| `doc/surya/`, `doc/schema/` | Surya graphs/reports, UML and drawio diagrams |
| `doc/audits/tools/slither-report.md` | Slither static-analysis report |
| `.github/workflows/ci.yml` | CI: `forge install`, `forge build --sizes`, `forge test -vvv --ffi` |

## Dependencies (tested versions)

- Solidity **0.8.22** (contracts declare `pragma ^0.8.20`)
- CMTAT **v2.4.0** (submodule `lib/CMTAT`)
- RuleEngine **v2.0.0** (submodule `lib/RuleEngine`)
- openzeppelin-contracts **v5.0.0** (submodule `lib/openzeppelin-contracts`)
- openzeppelin-contracts-upgradeable **v5.0.2** (submodule)
- openzeppelin-foundry-upgrades **v0.1.0** (submodule)
- forge-std (submodule `lib/forge-std`)

Submodules are **not** updated automatically — pin them to a release tag, never to
an intermediary commit.

## Common commands

```bash
forge install                              # initialize submodules (required first)
forge build --contracts src/IncomeVault.sol
forge build --sizes                        # as run in CI
forge test --ffi                           # --ffi is mandatory (OZ Upgrades plugin)
forge test --match-contract IncomeVaultTest --match-test testHolderCanClaimWithDepositAndOneHolder
forge coverage --ffi                       # known not to work with the proxy deployment

npm install
npm run lint:sol                           # ethlint on src/
npm run lint:sol:prettier                  # prettier-plugin-solidity
npm run surya:graph && npm run surya:report
npm run uml && npx hardhat docgen

slither . --checklist --filter-paths "openzeppelin-contracts|test|CMTAT|forge-std" > slither-report.md
```

## Conventions & invariants

- **Versioning:** `CHANGELOG.md` follows [changelog.md](https://changelog.md/);
  add an entry for any user-visible contract change.
- **Upgrade safety:** never reorder or remove existing storage variables; add new
  ones at the end and shrink the trailing `uint256[50] private __gap` accordingly.
  `IncomeVault` has an `/// @custom:oz-upgrades-unsafe-allow constructor` annotation
  — keep it and keep `_disableInitializers()` in the constructor.
- **Initialization order matters:** `PauseModule` must be initialized before
  `ValidationModule` (see `__IncomeVault_init`).
- **Claim accounting:** always set `claimedDividend[holder][time]` before any
  external call; keep `nonReentrant` on the claim entry points.
- **Deposits vs. open claims:** do not deposit for a `time` whose claim status is
  already `true` — it dilutes holders who have not yet claimed.
- **ERC-20 safety:** use `SafeERC20` (`safeTransfer` / `safeTransferFrom`) for the
  payment token.
- **Style:** 4-space indent, NatSpec (`@notice` / `@param` / `@dev`) on public and
  internal functions, custom errors prefixed `IncomeVault_`, `SPDX-License-Identifier: MPL-2.0`
  header on every Solidity file.
- **Documentation:** the README and `doc/` must state that the contracts are not
  audited; keep that disclaimer intact.

## Known quirks (verify before "fixing")

- `IncomeVaultInvariantStorage.sol` defines
  `INCOME_VAULT_DISTRIBUTE_ROLE = keccak256("INCOME_VAULT_DEPOSIT_ROLE")` — the
  distribute and deposit roles therefore share the same role hash.
- `IncomeVault.__IncomeVault_init` checks `ERC20TokenPayment_ == address(0)` twice;
  `cmtat_token` is never checked against the zero address despite the
  `IncomeVault_CMTATWithAddressZeroNotAllowed()` error existing.
- `withdraw` / `withdrawAll` call `approve(address(this), amount)` then
  `safeTransferFrom(address(this), ...)` instead of a direct `safeTransfer`.
- `package.json` scripts reference a `script/` directory that does not exist in
  this repository (the Surya shell scripts live in `doc/script/`).
