// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { BigNumber, utils } = require('ethers');

const GRACE_PERIOD = BigNumber.from(60 * 60);
const DEPLOYER = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

async function deploy(contractName, config, ...params) {
  var ContractFactory;
  if (config){
    ContractFactory = await hre.ethers.getContractFactory(contractName, config);
  }else{
    ContractFactory = await hre.ethers.getContractFactory(contractName);
  }
  const contract = await ContractFactory.deploy(...params);
  await contract.deployed();
  console.log(`${contractName} deployed to: ${contract.address}`);
  return contract;
}

async function deployMockOracle(){
  const priceOracle = await deploy("PriceOracle");
  const sequencerOracle = await deploy("SequencerOracle", undefined, DEPLOYER);

  return {priceOracle, sequencerOracle}
}

const TokenContractId = {
  DAI: 'DAI',
  AAVE: 'AAVE',
  TUSD: 'TUSD',
  BAT: 'BAT',
  WETH: 'WETH',
  USDC: 'USDC',
  USDT: 'USDT',
  SUSD: 'SUSD',
  ZRX: 'ZRX',
  MKR: 'MKR',
  WBTC: 'WBTC',
  LINK: 'LINK',
  KNC: 'KNC',
  MANA: 'MANA',
  REN: 'REN',
  SNX: 'SNX',
  BUSD: 'BUSD',
  USD: 'USD',
  YFI: 'YFI',
  UNI: 'UNI',
  ENJ: 'ENJ',
  WMATIC: 'WMATIC',
  STAKE: 'STAKE',
  xSUSHI: 'xSUSHI',
  WAVAX: 'WAVAX',
}

async function deployAllMockTokens () {
  var tokens = {};

  for (const tokenSymbol of Object.keys(TokenContractId)) {
    if (tokenSymbol === 'WETH') {
      tokens[tokenSymbol] = await deploy("WETH9Mocked");
      continue;
    }
    let decimals = 18;

    tokens[tokenSymbol] = await deploy("MintableERC20", null, 
      tokenSymbol,
      tokenSymbol,
      decimals,
    );
  }

  return tokens;
};


async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const poolAddressesProvider = await deploy("PoolAddressesProvider", undefined, "Mainnet", DEPLOYER);

  const supplyLogic = await deploy("SupplyLogic");
  const borrowLogic = await deploy("BorrowLogic");
  const bridgeLogic = await deploy("BridgeLogic");
  const eModeLogic = await deploy("EModeLogic");
  const flashLoanLogic = await deploy("FlashLoanLogic", {
    libraries: {
      BorrowLogic: borrowLogic.address,
    }
  });
  const liquidationLogic = await deploy("LiquidationLogic");
  const poolLogic = await deploy("PoolLogic");
  const configuratorLogic = await deploy("ConfiguratorLogic");

  const pool = await deploy("Pool", {
    libraries: {
      BorrowLogic: borrowLogic.address,
      BridgeLogic: bridgeLogic.address,
      EModeLogic: eModeLogic.address,
      FlashLoanLogic: flashLoanLogic.address,
      LiquidationLogic: liquidationLogic.address,
      PoolLogic: poolLogic.address,
      SupplyLogic: supplyLogic.address,
    }
  }, poolAddressesProvider.address);
  await poolAddressesProvider.setPoolImpl(pool.address);
  console.log("AddressesProvider Pool: ", await poolAddressesProvider.getPool());

  const poolConfigurator = await deploy("PoolConfigurator", {
    libraries: {
      ConfiguratorLogic: configuratorLogic.address,
    }
  });
  await poolAddressesProvider.setPoolConfiguratorImpl(poolConfigurator.address);
  console.log("AddressesProvider PoolConfigurator: ", await poolAddressesProvider.getPoolConfigurator());

  let {priceOracle, sequencerOracle} = await deployMockOracle();
  await poolAddressesProvider.setPriceOracle(priceOracle.address);
  console.log("AddressesProvider PriceOracle: ", await poolAddressesProvider.getPriceOracle());

  await poolAddressesProvider.setACLAdmin(DEPLOYER);
  console.log("AddressesProvider ACLAdmin: ", await poolAddressesProvider.getACLAdmin());

  const aclManager = await deploy("ACLManager", undefined, poolAddressesProvider.address);
  await poolAddressesProvider.setACLManager(aclManager.address);
  console.log("AddressesProvider ACLManager: ", await poolAddressesProvider.getACLManager());

  const priceOracleSentinel = await deploy(
    "PriceOracleSentinel", undefined, poolAddressesProvider.address, sequencerOracle.address, GRACE_PERIOD
  );
  await poolAddressesProvider.setPriceOracleSentinel(priceOracleSentinel.address);
  console.log("AddressesProvider PriceOracleSentinel: ", await poolAddressesProvider.getPriceOracleSentinel());

  const poolDataProvider = await deploy("MonetariaProtocolDataProvider", undefined, poolAddressesProvider.address);
  await poolAddressesProvider.setPoolDataProvider(poolDataProvider.address);
  console.log("AddressesProvider PoolDataProvider: ", await poolAddressesProvider.getPoolDataProvider());

  const mockTokens = await deployAllMockTokens();
  const monetariaOracle = await deploy("MonetariaOracle", undefined,
    poolAddressesProvider.address, [], [], priceOracle.address, mockTokens.WETH.address, BigNumber.from(""+10**18)
  );
  console.log(await mockTokens.WETH.totalSupply());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
