# Coverage report

Generated output. **Do not edit** — regenerate it instead:

```bash
make coverage-report     # HTML here, needs lcov/genhtml
make coverage            # summary table in the terminal, no extra tooling
```

`make coverage-report` deletes and recreates this directory, so this note is copied back in by the Makefile from `doc/script/coverage-README.md`. Edit it there.

## Coverage does work here

An older note in the agent guides said `forge coverage` did not work on this project because the tests deploy through a proxy. That is **no longer true** — the whole suite runs under coverage and the report above is real output from it. If you hit a failure, it is far more likely to be the `build` prerequisite than coverage itself.

## Reading the numbers

Two files report **0%** and that is expected, not a gap: `IncomeVaultSnapshotCore` and `IncomeVaultValidationCore` declare hooks with **no bodies**. There is no code in them to execute, so nothing can cover them. They exist to be inherited and answered elsewhere.

Function coverage is the lowest figure and the least useful one here. It counts `internal` helpers and the `_authorize*` overrides — empty bodies whose whole purpose is to carry a modifier — so a payout path exercised end to end still leaves several "uncovered" functions behind.

## Scope

`src/` only. Tests, mocks and `script/` are excluded, via:

```
forge coverage --ffi --exclude-tests --no-match-coverage '(test|mocks?|script)/'
```

Without `--ffi` every test fails: the OpenZeppelin Upgrades plugin shells out to `@openzeppelin/upgrades-core`.
