require("@nomiclabs/hardhat-waffle");
require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-etherscan");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const ALCHEMY_API_KEY = "INu5-0_xdInuuUiaac_D5eO2E5LEeTPY";

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
      url: `https://eth-goerli.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
      accounts: ['1c3480c2c549b54de1ff395ea3636942339bd26c7d821e6c132d2ad4acec14eb'],
      allowUnlimitedContractSize: true,
      gasPrice: 20000000000,
      gas: 6000000,
    }  
  },
  etherscan: {
    apiKey: "S5YC7V62ZDAA2M5J32411166F2AQFG61YD",
  },
};
