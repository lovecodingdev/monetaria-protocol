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

// let DEPLOYED = {
//   PoolAddressesProvider: '0x665a8beb5E1E0876240aeae65F59E7C1ab95d3D8',
//   PoolAddressesProviderRegistry: '0x47903c1589e180f07E29E387696f8911BF1242Ec',
//   SupplyLogic: '0x206543e36ECE2cEd36331f4A106eb84fBd1d7696',
//   BorrowLogic: '0x1CACe2064C53B5e5DEc5Ad47e3e35C455E32f51f',
//   BridgeLogic: '0xdd2f8235732DB565264F71dC8a2E32C492cd2848',
//   EModeLogic: '0x2E032F3Cc8A68D8aDf6806488057aF13153F4cfA',
//   FlashLoanLogic: '0xC4CCeb8b77c0C038c122819C8cBA682f279d46E3',
//   LiquidationLogic: '0x822AB04DA1a8979018AE8280D4Eacb8cDD295FCd',
//   PoolLogic: '0xCBbAcC7A5827f467E29b7E0c90e46dA597aa0159',
//   ConfiguratorLogic: '0x6939382Ab025E3be8B00528909D586D8598fC70B',
//   Pool: '0x722F28B954C36d420F885a8bB6eB969953338800',
//   PoolConfigurator: '0xCbc030D217A9D97e43758C0dC3b5FC24852a18d6',
//   PriceOracle: '0xb83F9F1462896A3010994A820C783f343bA608c9',
//   SequencerOracle: '0x2a9f33Fd39D1aB50cAd800F6696E89dD8bFfbdF9',
//   ACLManager: '0x9871AaB8e04264fff585490cC33027fD7fd7bDE2',
//   PriceOracleSentinel: '0x1e2a8Dd8463325A87647A34bcD24F94b0ceeAbD7',
//   MonetariaProtocolDataProvider: '0x64E2C58F063EFED4477C313a4d4e51184CfFE198',
//   MNT_MintableERC20: '0x13D37C126Ab634eFBa4D250d7D07b42d6D8aeCF4',
//   MNT_MockAggregator: '0x72a1AedfB92db29d8A29f2C3EF08d0a6946F73B3',
//   WETH_WETH9Mocked: '0x377Ad7013986Ae9af2e7329544F49916d175433D',
//   WETH_MockAggregator: '0xF1C88F235a1292075Da43f70f6c51eefdb5BAf60',
//   USDC_MintableERC20: '0x31e16AB7254934cB3f09C484f72ABB2d59DB48a0',
//   USDC_MockAggregator: '0xe99D8E0a520A183bBC60057D72151a2978539741',
//   USDT_MintableERC20: '0xdd8bdc16c47Dc594C4b36fcC1c2e62e2A46D07c6',
//   USDT_MockAggregator: '0xED2525B8D2eA26230E6585AE7EfbcAe8b81f74f4',
//   WBTC_MintableERC20: '0xcA2E8Abd6934597B33BE57f61385E9746448BF86',
//   WBTC_MockAggregator: '0x47805fc6687464a0D35046d0F6D6Da2C255dD3dd',
//   LINK_MintableERC20: '0xd0A90B92293f9174C52D4fFbf0C724C2c8EB66c6',
//   LINK_MockAggregator: '0x39c76fD1808e1a3A1db4D3B82b360D65c48C50F3',
//   BUSD_MintableERC20: '0x0ce8Eb2AC39EdA7950Ab8901231d22a39CBf911A',
//   BUSD_MockAggregator: '0x3200c69BaAC0DE4F9b474F941C9eeec36891520a',
//   MonetariaOracle: '0x75e3dD221a53f2085d233F4FEc0224B8DBC9002A',
//   WETHGateway: '0xb0CA176D676E4fB31305E2ef887C92DDD53ad12f',
//   WalletBalanceProvider: '0x2D55905f98B40194191e2714728F493b8a7db8B9',
//   UiPoolDataProviderV3: '0x0D5FF4b68f3bf66008c84e1717121E143e33aFaE',
//   UiIncentiveDataProviderV3: '0x06d24A54B4b25A8A23d65C5bfda8B6FB197A69C1',
//   EmissionManager: '0xf07F2D84343Eb2311e47005E6B90f87B8D00d8CF',
//   RewardsController: '0x2bF491725a4bFaF0c47C7c68151e28CAf43259c0',
// }

let DEPLOYED = {};

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

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

async function deployMockOracle(DEPLOYER){
  const priceOracle = await deploy("PriceOracle");
  const sequencerOracle = await deploy("SequencerOracle", {
    params: [DEPLOYER]
  });

  return {priceOracle, sequencerOracle}
}

const TokenContractId = {
  MNT: 'MONETARIA',
  WETH: 'WETH',
  USDC: 'USDC',
  USDT: 'USDT',
  WBTC: 'WBTC',
  LINK: 'LINK',
  BUSD: 'BUSD',
}

const TokenPrices = {
  MNT: 5,
  WETH: 4000,
  USDC: 1,
  USDT: 1,
  WBTC: 60000,
  LINK: 10,
  BUSD: 1,
}

async function deployAllMockTokens () {
  var tokens = {};
  var tokenAggregators = {};

  for (const tokenSymbol of Object.keys(TokenContractId)) {
    console.log(tokenSymbol);
    if (tokenSymbol === 'WETH') {
      tokens[tokenSymbol] = await deploy("WETH9Mocked", {
        key: 'WETH_WETH9Mocked'
      });
      tokenAggregators[tokenSymbol] = await deploy("MockAggregator", {
        params: [TokenPrices[tokenSymbol]],
        key: 'WETH_MockAggregator'
      });
      continue;
    }
    let decimals = 18;

    tokens[tokenSymbol] = await deploy("MintableERC20", {
      params: [tokenSymbol, tokenSymbol, decimals],
      key: `${tokenSymbol}_MintableERC20`,
    });
    tokenAggregators[tokenSymbol] = await deploy("MockAggregator", {
      params: [TokenPrices[tokenSymbol]],
      key: `${tokenSymbol}_MockAggregator`,
    });
  }

  return {tokens, tokenAggregators};
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

  const poolAddressesProvider = await deploy("PoolAddressesProvider", {
    params: ["ETH_Goerli", DEPLOYER]
  });
  const poolAddressesProviderRegistry = await deploy("PoolAddressesProviderRegistry", {
    params: [DEPLOYER]
  });
  tx = await poolAddressesProviderRegistry.registerAddressesProvider(poolAddressesProvider.address, 1);
  await tx.wait();

  const supplyLogic = await deploy("SupplyLogic");
  const borrowLogic = await deploy("BorrowLogic");
  const bridgeLogic = await deploy("BridgeLogic");
  const eModeLogic = await deploy("EModeLogic");
  const flashLoanLogic = await deploy("FlashLoanLogic", {
    config: {
      libraries: {
        BorrowLogic: borrowLogic.address,
      }
    }
  });
  const liquidationLogic = await deploy("LiquidationLogic");
  const poolLogic = await deploy("PoolLogic");
  const configuratorLogic = await deploy("ConfiguratorLogic");

  const pool = await deploy("Pool", {
    config: {
      libraries: {
        BorrowLogic: borrowLogic.address,
        BridgeLogic: bridgeLogic.address,
        EModeLogic: eModeLogic.address,
        FlashLoanLogic: flashLoanLogic.address,
        LiquidationLogic: liquidationLogic.address,
        PoolLogic: poolLogic.address,
        SupplyLogic: supplyLogic.address,
      }
    }, 
    params: [poolAddressesProvider.address]
  });
  tx = await poolAddressesProvider.setPoolImpl(pool.address);
  await tx.wait();
  console.log("AddressesProvider Pool: ", await poolAddressesProvider.getPool());

  const poolConfigurator = await deploy("PoolConfigurator", {
    config: {
      libraries: {
        ConfiguratorLogic: configuratorLogic.address,
      }
    }
  });
  tx = await poolAddressesProvider.setPoolConfiguratorImpl(poolConfigurator.address);
  await tx.wait();
  console.log("AddressesProvider PoolConfigurator: ", await poolAddressesProvider.getPoolConfigurator());

  let {priceOracle, sequencerOracle} = await deployMockOracle(DEPLOYER);

  tx = await poolAddressesProvider.setACLAdmin(DEPLOYER);
  await tx.wait();
  console.log("AddressesProvider ACLAdmin: ", await poolAddressesProvider.getACLAdmin());

  const aclManager = await deploy("ACLManager", {
    params: [poolAddressesProvider.address]
  });
  tx = await poolAddressesProvider.setACLManager(aclManager.address);
  await tx.wait();
  console.log("AddressesProvider ACLManager: ", await poolAddressesProvider.getACLManager());

  const priceOracleSentinel = await deploy("PriceOracleSentinel", {
    params: [poolAddressesProvider.address, sequencerOracle.address, GRACE_PERIOD]
  });
  tx = await poolAddressesProvider.setPriceOracleSentinel(priceOracleSentinel.address);
  await tx.wait();
  console.log("AddressesProvider PriceOracleSentinel: ", await poolAddressesProvider.getPriceOracleSentinel());

  const poolDataProvider = await deploy("MonetariaProtocolDataProvider", {
    params: [poolAddressesProvider.address]
  });
  tx = await poolAddressesProvider.setPoolDataProvider(poolDataProvider.address);
  await tx.wait();
  console.log("AddressesProvider PoolDataProvider: ", await poolAddressesProvider.getPoolDataProvider());

  const mockTokens = await deployAllMockTokens();

  const monetariaOracle = await deploy("MonetariaOracle", {
    params: [
      poolAddressesProvider.address, 
      [
        mockTokens.tokens.MNT.address,
        mockTokens.tokens.WETH.address,
        mockTokens.tokens.USDC.address,
        mockTokens.tokens.WBTC.address,
      ], 
      [
        mockTokens.tokenAggregators.MNT.address,
        mockTokens.tokenAggregators.WETH.address,
        mockTokens.tokenAggregators.USDC.address,
        mockTokens.tokenAggregators.WBTC.address,
      ], 
      ZERO_ADDRESS, 
      ZERO_ADDRESS, 
      1
    ]
  });
  tx = await poolAddressesProvider.setPriceOracle(monetariaOracle.address);
  await tx.wait();
  console.log("AddressesProvider PriceOracle: ", await poolAddressesProvider.getPriceOracle());

  const wethGateway = await deploy("WETHGateway", {
    params: [
      mockTokens.tokens.WETH.address, 
      DEPLOYER
    ]
  });

  const walletBalanceProvider = await deploy("WalletBalanceProvider");

  const uiPoolDataProviderV3 = await deploy("UiPoolDataProviderV3", {
    params: [
      mockTokens.tokenAggregators.WETH.address, 
      mockTokens.tokenAggregators.WETH.address
    ]
  });

  const uiIncentiveDataProviderV3 = await deploy("UiIncentiveDataProviderV3");

  //Rewards
  const emissionManager = await deploy("EmissionManager", {
    params: [ZERO_ADDRESS, DEPLOYER]
  });

  const rewardsController = await deploy("RewardsController", {
    params:[emissionManager.address]
  });
  await emissionManager.setRewardsController(rewardsController.address);
  await tx.wait();
  console.log("EmissionManager RewardsController: ", await emissionManager.getRewardsController());

  const reservesSetupHelper = await deploy("ReservesSetupHelper");
  const reserveInterestRateStrategy = await deploy("DefaultReserveInterestRateStrategy", {
    params: [poolAddressesProvider.address, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  });

  tx = await aclManager.addAssetListingAdmin(DEPLOYER);
  await tx.wait();
  console.log("ACLManager AssetListingAdmin: ", DEPLOYER, await aclManager.isAssetListingAdmin(DEPLOYER));

  tx = await aclManager.addRiskAdmin(reservesSetupHelper.address);
  await tx.wait();
  console.log("ACLManager RiskAdmin: ", reservesSetupHelper.address, await aclManager.isRiskAdmin(reservesSetupHelper.address));

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
