require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  gasReporter: {
    currency: 'CHF',
    gasPrice: 21
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      // So bridge tests see block.timestamp < timelock (1701817200); ALBA tests run first in file
      initialDate: "2023-12-05T22:56:00.000Z",
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1,
          },
        },
      },
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1,
          },
        },
      }
    ]
  },
};
