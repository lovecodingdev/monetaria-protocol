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

const poolAddressesProviderAddress = '0xabf63fe04c46e4f539F9a63E8ab4355636e802AA';
const poolAddress = '0xb7d086dcbc9ceca5479d64e8168eeaf3aa74782a';
const poolConfiguratorAddress = '0xea73e15b51723ba7ef9e71fbd4265172656101ee'
const reservesSetupHelperAddress = '0x0207977fb4b34f4C943D2274114947FFA3973dBc'

let DEPLOYED = {};

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
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

async function deployAllTokens () {
  let tokens = {};

  for (const tokenSymbol of Object.keys(TokenContractId)) {
    console.log(tokenSymbol);
    let token = {};

    const MToken = await hre.ethers.getContractFactory("MToken");
    const mToken = await MToken.deploy(poolAddress);
    await mToken.deployed();
    await mToken.deployTransaction.wait();
    token.mToken = mToken.address;

    const StableDebtToken = await hre.ethers.getContractFactory("StableDebtToken");
    const stableDebtToken = await StableDebtToken.deploy(poolAddress);
    await stableDebtToken.deployed();
    await stableDebtToken.deployTransaction.wait();
    token.stableDebtToken = stableDebtToken.address;

    const VariableDebtToken = await hre.ethers.getContractFactory("VariableDebtToken");
    const variableDebtToken = await VariableDebtToken.deploy(poolAddress);
    await variableDebtToken.deployed();
    await variableDebtToken.deployTransaction.wait();
    token.variableDebtToken = variableDebtToken.address;

    tokens[tokenSymbol] = token;
  }

  return tokens;
};

async function main() {

  const [signer] = await ethers.getSigners();
  const DEPLOYER = signer.address;
  console.log({DEPLOYER});

  // let tokens = await deployAllTokens();
  // console.log({tokens});
  const poolAddressesProvider = await hre.ethers.getContractAt("IPoolAddressesProvider", poolAddressesProviderAddress);
  console.log("PoolAddressesProvider: ", poolAddressesProvider.address);

  const poolConfigurator = await hre.ethers.getContractAt("IPoolConfigurator", poolConfiguratorAddress);
  console.log("PoolConfigurator: ", poolConfigurator.address);

  const reservesSetupHelper = await hre.ethers.getContractAt("ReservesSetupHelper", reservesSetupHelperAddress);
  console.log("ReservesSetupHelper: ", reservesSetupHelper.address);

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
      mTokenImpl: '0x3b3Be494803e11d6D94d9Ad8FEFd672B06bfF3E7',
      stableDebtTokenImpl: '0x09C1dcb12aE73745Bc5D6Fa878C151797B9AcD28',
      variableDebtTokenImpl: '0x245750791e9d10B8F968D205e8BcFF9c3788b663',
      underlyingAssetDecimals: 18,
      interestRateStrategyAddress: reserveInterestRateStrategy.address,
      underlyingAsset: '0x72D6F8ba23aC707408E9dc35d81302d338E383aD',
      treasury: ZERO_ADDRESS,
      incentivesController: ZERO_ADDRESS,
      mTokenName: 'MBTC',
      mTokenSymbol: 'MBTC',
      variableDebtTokenName: 'VBTC',
      variableDebtTokenSymbol: 'VBTC',
      stableDebtTokenName: 'SBTC',
      stableDebtTokenSymbol: 'SBTC',
      params: '0x10',
    },
  ];
  
  let tx;

  tx = await poolConfigurator.connect(signer).initReserves(initInputParams);

  try {
    await tx.wait();    
  } catch (error) {
    
  }

  const reserveConfigures = [
    {
        asset: '0x72D6F8ba23aC707408E9dc35d81302d338E383aD',
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

  tx = await reservesSetupHelper.connect(signer).configureReserves(
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

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
