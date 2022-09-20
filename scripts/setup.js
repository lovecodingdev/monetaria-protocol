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

  const poolConfigurator = await hre.ethers.getContractAt("IPoolConfigurator", poolConfiguratorAddress);
  console.log("PoolConfigurator: ", poolConfigurator.address);

  const reservesSetupHelper = await hre.ethers.getContractAt("ReservesSetupHelper", reservesSetupHelperAddress);
  console.log("ReservesSetupHelper: ", reservesSetupHelper.address);

  // const initInputParams = [
  //   {
  //     mTokenImpl: '0x782e7B4578a36637cf05fd38BB32e9bA2F91332c',
  //     stableDebtTokenImpl: '0xF7822930cE885c8A164B7FbCf311d277D81c2c7e',
  //     variableDebtTokenImpl: '0xcc638Ad8b8CaBad6Ffa64633F72eD9af463f75f2',
  //     underlyingAssetDecimals: 18,
  //     interestRateStrategyAddress: '0x91f78d489a01eD3C9FdEc6C1DA2aC297e010f1c0',
  //     underlyingAsset: '0x151AC69b7aef24b8E8dbE2c9aB7E4296569272f8',
  //     treasury: ZERO_ADDRESS,
  //     incentivesController: ZERO_ADDRESS,
  //     mTokenName: 'MMNT',
  //     mTokenSymbol: 'MMNT',
  //     variableDebtTokenName: 'VMNT',
  //     variableDebtTokenSymbol: 'VMNT',
  //     stableDebtTokenName: 'SMNT',
  //     stableDebtTokenSymbol: 'SMNT',
  //     params: '0x10',
  //   },
  // ];
  
  // let tx;

  // tx = await poolConfigurator.connect(signer).initReserves(initInputParams);

  // try {
  //   await tx.wait();    
  // } catch (error) {
    
  // }

  const reserveConfigures = [
    {
        asset: '0x151AC69b7aef24b8E8dbE2c9aB7E4296569272f8',
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
