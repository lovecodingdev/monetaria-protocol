// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { BigNumber, utils } = require('ethers');
const { ethers } = require("hardhat");
const { ZERO_ADDRESS, deploy } = require("./helpers")

//Input
const POOL_ADDRESS_PROVIDER = '0x254eCbA99Ebef34aEFAF367725f0a940d6e2fbeB';
const RESERVES_SETUP_HELPER = '0x019E2a0bD139D13B6CAbEF9a808E642FcE90c0Ea'
const UNDERLYING_ASSET = "0x37DFe2D29af249b78e1f42c29B21dEcee9a37e58";

async function setupReserve(underlyingAsset, poolAddressesProvider, reservesSetupHelper){
  const poolConfiguratorAddress =  await poolAddressesProvider.getPoolConfigurator();
  const poolConfigurator = await hre.ethers.getContractAt("IPoolConfigurator", poolConfiguratorAddress);
  console.log("PoolConfigurator: ", poolConfigurator.address);

  const poolAddress =  await poolAddressesProvider.getPool();
  const pool = await hre.ethers.getContractAt("IPool", poolAddress);
  console.log("Pool: ", pool.address);

  const token = await hre.ethers.getContractAt("ERC20", underlyingAsset);
  const tokenSymbol = await token.symbol();
  const tokenDecimals = await token.decimals();
  console.log(`Token Symbol: ${tokenSymbol} Decimals: ${tokenDecimals}`);

  const mToken = await deploy("MToken", {
    params: [poolAddress],
    key: `${tokenSymbol}_MToken_IMPL`,
  });
  const stableDebtToken = await deploy("StableDebtToken", {
    params: [poolAddress],
    key: `${tokenSymbol}_StableDebtToken_IMPL`,
  });
  const variableDebtToken = await deploy("VariableDebtToken", {
    params: [poolAddress],
    key: `${tokenSymbol}_VariableDebtToken_IMPL`,
  });

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
    ],
    key: `${tokenSymbol}_DefaultReserveInterestRateStrategy`
  });

  const initInputParams = [
    {
      mTokenImpl: mToken.address,
      stableDebtTokenImpl: stableDebtToken.address,
      variableDebtTokenImpl: variableDebtToken.address,
      underlyingAssetDecimals: tokenDecimals,
      interestRateStrategyAddress: reserveInterestRateStrategy.address,
      underlyingAsset,
      treasury: ZERO_ADDRESS,
      incentivesController: ZERO_ADDRESS,
      mTokenName: 'M'+tokenSymbol,
      mTokenSymbol: 'M'+tokenSymbol,
      variableDebtTokenName: 'V'+tokenSymbol,
      variableDebtTokenSymbol: 'V'+tokenSymbol,
      stableDebtTokenName: 'S'+tokenSymbol,
      stableDebtTokenSymbol: 'S'+tokenSymbol,
      params: '0x10',
    },
  ];

  let tx;

  tx = await poolConfigurator.initReserves(initInputParams);

  try {
    await tx.wait();    
  } catch (error) {
    
  }

  const reserveConfigures = [
    {
      asset: underlyingAsset,
      baseLTV: 8500,
      liquidationThreshold: 9000,
      liquidationBonus: 10200,
      reserveFactor: 5,
      borrowCap: 1_000_000,
      supplyCap: 1_000_000,
      stableBorrowingEnabled: true,
      borrowingEnabled: true,
    },
  ];

  tx = await reservesSetupHelper.configureReserves(
    poolConfiguratorAddress,
    reserveConfigures
  );
  await tx.wait();

  console.log(await pool.getReserveData(UNDERLYING_ASSET));
}

async function main() {

  const [signer] = await ethers.getSigners();
  const DEPLOYER = signer.address;
  console.log({DEPLOYER});

  const poolAddressesProvider = await hre.ethers.getContractAt("IPoolAddressesProvider", POOL_ADDRESS_PROVIDER);
  console.log("PoolAddressesProvider: ", poolAddressesProvider.address);

  const reservesSetupHelper = await hre.ethers.getContractAt("ReservesSetupHelper", RESERVES_SETUP_HELPER);
  console.log("ReservesSetupHelper: ", reservesSetupHelper.address);

  await setupReserve(
    UNDERLYING_ASSET, 
    poolAddressesProvider, 
    reservesSetupHelper
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
