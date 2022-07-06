// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');


  // We get the contract to deploy
  const PoolAddressesProvider = await hre.ethers.getContractFactory("PoolAddressesProvider");
  const poolAddressesProvider = await PoolAddressesProvider.deploy("Mainnet", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
  await poolAddressesProvider.deployed();
  console.log("PoolAddressesProvider deployed to:", poolAddressesProvider.address);

  const BorrowLogic = await hre.ethers.getContractFactory("BorrowLogic");
  const borrowLogic = await BorrowLogic.deploy();
  await borrowLogic.deployed();
  console.log("BorrowLogic deployed to:", borrowLogic.address);

  const BridgeLogic = await hre.ethers.getContractFactory("BridgeLogic");
  const bridgeLogic = await BridgeLogic.deploy();
  await bridgeLogic.deployed();
  console.log("BridgeLogic deployed to:", bridgeLogic.address);

  const EModeLogic = await hre.ethers.getContractFactory("EModeLogic");
  const eModeLogic = await EModeLogic.deploy();
  await eModeLogic.deployed();
  console.log("EModeLogic deployed to:", eModeLogic.address);

  const FlashLoanLogic = await hre.ethers.getContractFactory("FlashLoanLogic", {
    libraries: {
      BorrowLogic: borrowLogic.address,
    }
  });
  const flashLoanLogic = await FlashLoanLogic.deploy();
  await flashLoanLogic.deployed();
  console.log("FlashLoanLogic deployed to:", flashLoanLogic.address);

  const LiquidationLogic = await hre.ethers.getContractFactory("LiquidationLogic");
  const liquidationLogic = await LiquidationLogic.deploy();
  await liquidationLogic.deployed();
  console.log("LiquidationLogic deployed to:", liquidationLogic.address);

  const PoolLogic = await hre.ethers.getContractFactory("PoolLogic");
  const poolLogic = await PoolLogic.deploy();
  await poolLogic.deployed();
  console.log("PoolLogic deployed to:", poolLogic.address);

  const SupplyLogic = await hre.ethers.getContractFactory("SupplyLogic");
  const supplyLogic = await SupplyLogic.deploy();
  await supplyLogic.deployed();
  console.log("SupplyLogic deployed to:", supplyLogic.address);

  const Pool = await hre.ethers.getContractFactory("Pool", {
    libraries: {
      BorrowLogic: borrowLogic.address,
      BridgeLogic: bridgeLogic.address,
      EModeLogic: eModeLogic.address,
      FlashLoanLogic: flashLoanLogic.address,
      LiquidationLogic: liquidationLogic.address,
      PoolLogic: poolLogic.address,
      SupplyLogic: supplyLogic.address,
    }
  });
  const pool = await Pool.deploy(poolAddressesProvider.address);
  await pool.deployed();
  console.log("Pool deployed to:", pool.address, await pool.ADDRESSES_PROVIDER());

  await poolAddressesProvider.setPoolImpl(pool.address);
  console.log("AddressesProvider Pool: ", await poolAddressesProvider.getPool());

  var poolContract = await Pool.attach(await poolAddressesProvider.getPool());
  console.log("Pool getRevision: ", poolContract.address, await poolContract.POOL_REVISION());
  
  const Pool2 = await hre.ethers.getContractFactory("Pool2", {
    libraries: {
      BorrowLogic: borrowLogic.address,
      BridgeLogic: bridgeLogic.address,
      EModeLogic: eModeLogic.address,
      FlashLoanLogic: flashLoanLogic.address,
      LiquidationLogic: liquidationLogic.address,
      PoolLogic: poolLogic.address,
      SupplyLogic: supplyLogic.address,
    }
  });
  const pool2 = await Pool2.deploy(poolAddressesProvider.address);
  await pool2.deployed();
  console.log("Pool2 deployed to:", pool2.address, await pool2.ADDRESSES_PROVIDER());

  await poolAddressesProvider.setPoolImpl(pool2.address);
  console.log("AddressesProvider Pool: ", await poolAddressesProvider.getPool());

  poolContract = await Pool.attach(await poolAddressesProvider.getPool());
  console.log("Pool getRevision: ", poolContract.address, await poolContract.POOL_REVISION());

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
