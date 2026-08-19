# IncomeVault — common tasks.
#
# Why this file exists: the OpenZeppelin Foundry Upgrades plugin validates upgrade safety by reading
# Foundry's build-info, and it rejects the output of an *incremental* compile. Running
# `forge test --ffi` straight after editing a contract therefore fails every test with
#
#   Failed to run upgrade safety validation: ... Build info file ... is not from a full compilation.
#
# which names neither the cause nor the fix. `make test` does the full build first, so the trap is
# not something a contributor has to know about.

.DEFAULT_GOAL := help
.PHONY: help install build test test-match coverage coverage-report gas lint fmt fmt-check doc deploy deploy-ownable clean

FFI := --ffi

## help: list the available targets
help:
	@echo "IncomeVault — make targets"
	@echo
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo
	@echo "  Note: every target that compiles does a FULL build (forge clean && forge build)."
	@echo "        The upgrade-safety validation rejects an incremental one."

## install: fetch submodules and the Node dependencies the Upgrades plugin needs
install:
	git submodule update --init --recursive
	npm install

## build: full build (clean first — required by the upgrade-safety validation)
build:
	forge clean
	forge build --sizes

## test: full build, then the whole suite
test: build
	forge test $(FFI)

## test-match: run one contract, e.g. `make test-match C=OperatorTest`
test-match: build
	forge test $(FFI) --match-contract $(C) -vv

## coverage: line/branch/function coverage of src/, excluding tests and mocks
coverage: build
	forge coverage $(FFI) --exclude-tests --no-match-coverage '(test|mocks?|script)/' --report summary

## coverage-report: the same, rendered to HTML in doc/coverage (needs lcov/genhtml)
coverage-report: build
	forge coverage $(FFI) --exclude-tests --no-match-coverage '(test|mocks?|script)/' \
		--report lcov --report-file lcov.info
	rm -rf doc/coverage && mkdir -p doc/coverage
	genhtml lcov.info --branch-coverage --output-dir doc/coverage
	rm -f lcov.info
	@echo "open doc/coverage/index.html"

## gas: gas report for the whole suite
gas: build
	forge test $(FFI) --gas-report

## lint: forge lint over the sources
lint:
	forge lint src/

## fmt: format the sources in place
fmt:
	forge fmt src/ test/ script/

## fmt-check: report formatting differences without writing
fmt-check:
	forge fmt --check src/ test/ script/

## doc: regenerate the UML and the Surya diagrams/reports
doc:
	npm run uml
	cd doc/script && bash script_surya_graph.sh
	cd doc/script && bash script_surya_inheritance.sh
	cd doc/script && bash script_surya_report.sh
	@echo "Surya output is in docOut/ — replace doc/surya/ with it (see doc/TOOLCHAIN.md)"

## deploy: deploy the role-based vault (set the env vars first, see doc/README.md)
deploy: build
	forge script script/DeployIncomeVault.s.sol --rpc-url $(RPC_URL) --broadcast $(FFI)

## deploy-ownable: deploy the single-owner vault
deploy-ownable: build
	forge script script/DeployIncomeVaultOwnable2Step.s.sol --rpc-url $(RPC_URL) --broadcast $(FFI)

## clean: remove build output and scratch files
clean:
	forge clean
	rm -rf docOut lcov.info
