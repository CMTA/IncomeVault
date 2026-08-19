# CHANGELOG

Please follow [https://changelog.md/](https://changelog.md/) conventions.

## 2.0.0

### Breaking changes

- The vault is no longer tied to the CMTAT. The holder balances and the total supply are read
  through the [`ISnapshotState`](https://github.com/CMTA/SnapshotEngine) interface, so **any**
  contract implementing it can be used as the snapshot source (the external `SnapshotEngine`, or a
  token embedding the snapshot logic). The state variable `CMTAT_TOKEN` (`ICMTATSnapshot`) is
  replaced by `snapshotEngine` (`ISnapshotState`).
- `initialize` no longer takes an `IAuthorizationEngine`, removed by CMTAT v3. New signature:
  `initialize(address admin, IERC20 ERC20TokenPayment_, ISnapshotState snapshotEngine_, IRuleEngine ruleEngine_, uint256 timeLimitToWithdraw_)`.
- The vault no longer inherits the CMTAT `ValidationModule`. Its own
  `IncomeVaultValidationModule` composes the CMTAT `AccessControlModule`, `PauseModule` and
  `EnforcementModule` and calls the RuleEngine through the view entry point
  `IRuleEngine.canTransfer`. A rejected payout now reverts with
  `IncomeVault_InvalidTransfer(from, to, value)` instead of `CMTAT_InvalidTransfer`.
- `withdraw` and `withdrawAll` use `SafeERC20.safeTransfer` directly; the self-approval step and
  the error `IncomeVault_FailApproval` are removed.
- The state moved from sequential storage slots guarded by `uint256[50] private __gap` to a single
  **ERC-7201 namespaced storage** struct, as OpenZeppelin Upgradeable and CMTAT v3 do. Every `__gap`
  is removed and `IncomeVault` now declares **no** sequential storage slot at all. The external ABI
  is unchanged — `snapshotEngine()`, `ERC20TokenPayment()`, `claimedDividend()`, `segregatedDividend()`,
  `segregatedClaim()` and `timeLimitToWithdraw()` are kept as explicit getters — but the storage
  layout is **not** compatible with a 1.x/2.0-rc deployment: this is a redeploy, not an upgrade.

### Fixed

- `INCOME_VAULT_DISTRIBUTE_ROLE` was defined as `keccak256("INCOME_VAULT_DEPOSIT_ROLE")` and
  therefore shared the deposit role. It is now `keccak256("INCOME_VAULT_DISTRIBUTE_ROLE")`.
- `initialize` checked the payment token against the zero address twice and never checked the
  snapshot source. The snapshot source is now rejected when zero
  (`IncomeVault_SnapshotEngineWithAddressZeroNotAllowed`).

### Toolchain

- Solidity 0.8.36, EVM target `prague`.
- CMTAT v2.4.0 → v3.3.0-rc3, RuleEngine v2.0.0 → v3.0.0-rc5, OpenZeppelin Contracts (and
  Contracts Upgradeable) v5.0.x → v5.7.0, OpenZeppelin Foundry Upgrades v0.1.0 → v0.4.2.
- New submodules: `lib/SnapshotEngine` (v0.5.0) and `lib/forge-std` (v1.16.1).
- `ReentrancyGuardUpgradeable` was removed from OpenZeppelin Contracts Upgradeable v5.7.0; the
  vault now uses `ReentrancyGuardTransient` (EIP-1153).

## 1.0.0
- 🎉 first release!
