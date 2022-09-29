// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { BigNumber, utils } = require('ethers');
const { ethers } = require("hardhat");

const GRACE_PERIOD = BigNumber.from(60 * 60);
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const AVG_BLOCK_TIME = 15_000;

let DEPLOYED = {};

async function deploy(contractName, {config, params = [], wait = AVG_BLOCK_TIME, key} = {}) {
  var ContractFactory;
  if (config){
    ContractFactory = await hre.ethers.getContractFactory(contractName, config);
  }else{
    ContractFactory = await hre.ethers.getContractFactory(contractName);
  }
  let contract;
  let deployedKey = key || contractName;
  if(DEPLOYED[deployedKey]){
    contract = await ContractFactory.attach(DEPLOYED[deployedKey]);
    console.log(`${deployedKey} already deployed to: ${contract.address}`);
  }else{
    contract = await ContractFactory.deploy(...params);
    await contract.deployed();
    await contract.deployTransaction.wait();
    // await sleep(wait);
    DEPLOYED[deployedKey] = contract.address;
    console.log(`${deployedKey} deployed to: ${contract.address}`);
  }
  return contract;
}

AGG_DECIMALS = Math.pow(10, 8);
const TokenPrices = {
  MNT: 5 * AGG_DECIMALS,
  WETH: 4000 * AGG_DECIMALS,
  USDC: 1 * AGG_DECIMALS,
  USDT: 1 * AGG_DECIMALS,
  WBTC: 60000 * AGG_DECIMALS,
  LINK: 10 * AGG_DECIMALS,
  BUSD: 1 * AGG_DECIMALS,
}

async function deployAllMockAggregators () {
  var tokens = {};
  var tokenAggregators = {};

  for (const tokenSymbol of Object.keys(TokenPrices)) {
    console.log(tokenSymbol);
    tokenAggregators[tokenSymbol] = await deploy("MockAggregator", {
      params: [TokenPrices[tokenSymbol]],
      key: `${tokenSymbol}_MockAggregator`,
    });
  }

  return tokenAggregators;
};

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const [signer] = await ethers.getSigners();
  const DEPLOYER = signer.address;

  let tx;

  const poolAddressesProvider = await hre.ethers.getContractAt("PoolAddressesProvider", '0xabf63fe04c46e4f539F9a63E8ab4355636e802AA');
  console.log("PoolAddressesProvider: ", poolAddressesProvider.address);

  const poolConfigurator = await hre.ethers.getContractAt("IPoolConfigurator", '0xea73e15b51723ba7ef9e71fbd4265172656101ee');
  console.log("PoolConfigurator: ", poolConfigurator.address);

  const monetariaOracle  = await hre.ethers.getContractAt("MonetariaOracle", '0x7f317b397120Dca9a8eC99FaB161843d8b7a51D2');
  console.log("MonetariaOracle: ", monetariaOracle.address);

  // let tokenAggregators = await deployAllMockAggregators();

  tx = await monetariaOracle.setAssetSources(
    [
      '0x151AC69b7aef24b8E8dbE2c9aB7E4296569272f8',
      '0xE9c504aF8154995bdB94e8D3b6871c2fFC76De83',
      '0x4bfc328FfbAf2ac8ae90c90E832B0901aED02B5B',
      '0x72D6F8ba23aC707408E9dc35d81302d338E383aD',
    ], 
    [
      '0xafC2B1CC045488A9E2D96145873dB14BfDc0357D',
      '0x8655fE8C537FdFeb4a6E8bB43950e53204b55f22',
      '0x40CB72B78b5F6De05d634591ea5784FE95D0C2E0',
      '0x86b792AFFe9aBec12C242c04bed95A519490e214',
    ]
  );
  await tx.wait();

  console.log({DEPLOYED});
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
