require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("@typechain/hardhat");
require('dotenv').config()

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("env", "Prints env", async (taskArgs, hre) => {
  console.log(process.env);
});

task("network", "Prints network", async (taskArgs, hre) => {
  console.log(await hre.ethers.provider.getNetwork());
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    // Docs for the compiler https://docs.soliditylang.org/en/v0.8.10/using-the-compiler.html
    version: '0.8.9',
    settings: {
      optimizer: {
        enabled: true,
        runs: 100000,
      },
      evmVersion: 'london',
    },
  },
  gasReporter: {
    enabled: true,
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
  },
  networks: {
    localhost: {
      allowUnlimitedContractSize: true,
    },
    hardhat: {
      allowUnlimitedContractSize: true,
      gasPrice: 20000000000,
      gas: 6000000,
    },
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [process.env.ACCOUNT],
      allowUnlimitedContractSize: true,
      gasPrice: 20000000000,
      gas: 6000000,
    },
    bsctestnet: {
      url: `https://bsc-testnet.public.blastapi.io`,
      accounts: [process.env.ACCOUNT],
      allowUnlimitedContractSize: true,
      gasPrice: 20000000000,
      gas: 6000000,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
