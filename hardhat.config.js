/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-foundry");
require('solidity-docgen');

// Only used to generate doc/solidityAPI via `npx hardhat docgen`; the build and the
// tests run under Foundry. The solc settings mirror foundry.toml so the generated
// API reflects the contracts as they are actually compiled.
//
// NOTE: `settings` must sit INSIDE `solidity`. Left at the top level it is silently
// ignored, the optimizer never runs, and docgen reports a spurious contract-size
// warning for contracts that are within the limit under Foundry.
module.exports = {
  solidity: {
    version: "0.8.36",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      evmVersion: "prague"
    }
  },
  docgen: {
    // written straight to its committed location, so regenerating needs no manual move
    outputDir: 'doc/solidityAPI',
    pages: 'single'
  }
};
