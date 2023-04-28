// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

const hre = require("hardhat");
const { BigNumber, utils } = require('ethers');
const { ethers } = require("hardhat");
const { deploy, GRACE_PERIOD, ZERO_ADDRESS } = require("./helpers");

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

const TokenDecimals = {
  MNT: 18,
  WETH: 18,
  USDC: 6,
  USDT: 6,
  WBTC: 8,
  LINK: 18,
  BUSD: 18,
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
    let decimals = TokenDecimals[tokenSymbol] || 18;

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
  tx = await emissionManager.setRewardsController(rewardsController.address);
  await tx.wait();
  console.log("EmissionManager RewardsController: ", await emissionManager.getRewardsController());

  const reservesSetupHelper = await deploy("ReservesSetupHelper");
  const reserveInterestRateStrategy = await deploy("DefaultReserveInterestRateStrategy", {
    params: [
      poolAddressesProvider.address, 
      "800000000000000000000000000", 
      "0", 
      "40000000000000000000000000", 
      "750000000000000000000000000", 
      "5000000000000000000000000", 
      "750000000000000000000000000", 
      "10000000000000000000000000", 
      "80000000000000000000000000", 
      "200000000000000000000000000"
    ]
  });

  tx = await aclManager.addAssetListingAdmin(DEPLOYER);
  await tx.wait();
  console.log("ACLManager AssetListingAdmin: ", DEPLOYER, await aclManager.isAssetListingAdmin(DEPLOYER));

  tx = await aclManager.addRiskAdmin(reservesSetupHelper.address);
  await tx.wait();
  console.log("ACLManager RiskAdmin: ", reservesSetupHelper.address, await aclManager.isRiskAdmin(reservesSetupHelper.address));

  tx = await aclManager.addRiskAdmin(DEPLOYER);
  await tx.wait();
  console.log("ACLManager RiskAdmin: ", DEPLOYER, await aclManager.isRiskAdmin(DEPLOYER));

  tx = await aclManager.addPoolAdmin(DEPLOYER);
  await tx.wait();
  console.log("ACLManager PoolAdmin: ", DEPLOYER, await aclManager.isPoolAdmin(DEPLOYER));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
