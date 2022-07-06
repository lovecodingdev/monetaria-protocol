// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

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

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const poolAddressesProvider = await deploy("PoolAddressesProvider", undefined, "Mainnet", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");

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

  const poolConfigurator = await deploy("PoolConfigurator", {
    libraries: {
      ConfiguratorLogic: configuratorLogic.address,
    }
  });

  await poolAddressesProvider.setPoolImpl(pool.address);
  console.log("AddressesProvider Pool: ", await poolAddressesProvider.getPool());

  await poolAddressesProvider.setPoolConfiguratorImpl(poolConfigurator.address);
  console.log("AddressesProvider PoolConfigurator: ", await poolAddressesProvider.getPoolConfigurator());

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
