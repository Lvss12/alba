require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  gasReporter: {
    currency: "CHF",
    gasPrice: 21,
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      // So bridge tests see block.timestamp < timelock (1701817200); ALBA tests run first in file
      initialDate: "2023-12-05T22:56:00.000Z",
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "",
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
    },
  },
  solidity: {
    version: "0.8.9",
    settings: {
      // Keep IR disabled because this codebase fails with a Yul stack-depth error on 0.8.9.
      viaIR: false,
      optimizer: {
        enabled: true,
        runs: 1,
      },
      metadata: {
        bytecodeHash: "none",
      },
    },
  },
};
