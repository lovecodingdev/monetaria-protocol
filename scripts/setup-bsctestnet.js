// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { BigNumber, utils } = require('ethers');
const { ethers } = require("hardhat");
const { ZERO_ADDRESS, deploy } = require("./helpers")

const poolAddressesProviderAddress = '0xcc6E0458845CBe15a0E4f980C5F1543E9d8316d5';
const reservesSetupHelperAddress = '0x822AB04DA1a8979018AE8280D4Eacb8cDD295FCd'

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
    ]
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
  // try {
  //   let code = await ethers.provider.call(tx, tx.blockNumber)
  // } catch (err) {
  //   const code = err.transaction.data.replace('Reverted ','');
  //   console.log({err});
  //   let reason = ethers.utils.toUtf8String('0x' + code.substr(138));
  //   console.log('revert reason:', reason);
  // }
}

async function main() {

  const [signer] = await ethers.getSigners();
  const DEPLOYER = signer.address;
  console.log({DEPLOYER});

  const poolAddressesProvider = await hre.ethers.getContractAt("IPoolAddressesProvider", poolAddressesProviderAddress);
  console.log("PoolAddressesProvider: ", poolAddressesProvider.address);

  const reservesSetupHelper = await hre.ethers.getContractAt("ReservesSetupHelper", reservesSetupHelperAddress);
  console.log("ReservesSetupHelper: ", reservesSetupHelper.address);

  await setupReserve(
    '0x87ee3ED4B0fbcadAc4a3D9797a77C112ccE9143e', 
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
