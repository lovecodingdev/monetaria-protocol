const hre = require("hardhat");
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

async function verify(params) {
  try {
    await hre.run("verify:verify", params);
  } catch (error) {
    if(String(error).includes("already verified")){
      console.log(`${params.address} is already verified.`);
    }else{
      console.log(error)
    }
  }
}

async function main() {
  const [ signer ] = await ethers.getSigners();
  const DEPLOYER = signer.address;

  const poolAddressesProvider = "0xcc6E0458845CBe15a0E4f980C5F1543E9d8316d5";
  const poolAddressesProviderRegistry = "0xB6A37CC7231A3F2309f14366762F0961FE53ef77";
  const monetariaProtocolDataProvider = "0xC6Ad5084822A7DadBcfa706A55D76Af2c4D5e8f3";
  const aclManager = "0x9756838D773F7fa53D147bd7B80bD85a2323a6E7";
  const poolConfiguratorImpl = "0x8bB9a812b5318a13643982A411281bb4Bb5Ff32d";
  const poolConfigurator = "0xBCb0Dc229156De9c9D2537E559611F50E8f3633b";

  const priceOracle = "0x827B638BF222b135dd5fca3Ed1F4464787c97D4A";
  const monetariaOracle = "0x91F9B6ADdF61837f8aC786Fb38930E19E0094a55";

  const configuratorLogic = "0x3D9b032E8Dd6b1a1D3DD5A109a041f15E8855141";
  const liquidationLogic = "0x7C7f0Aa873553Ca26dA3c550778d39EAaf30b5eB";
  const borrowLogic = "0x9852F34041195eFc1B6273cBbD2940e397934aFB";
  const supplyLogic = "0x191e089827CD1d4dEd594143F6F11F0A15C20F18";
  const poolLogic = "0xA8E509595f8A5f054B51E33C405F3950503614BF";
  const bridgeLogic = '0x5253923B2a726774Ec66578C6C62a2bF3A6DEbe7';
  const eModeLogic = '0x4FE2c20a86D6B60341127B8Dbb8043537E39BAB6';
  const flashLoanLogic = '0x3fFB3DA2fA643Bc7a3c321512d706091e778AAE7';
  
  const poolImpl = "0x9bE24feCFD4DB52D09A0fA03A27e72F91396245E";
  const pool = "0x945f65f1Abe6383De79C01A9aE7eB8f499Bff88b";

  const reservesSetupHelper = "0x822AB04DA1a8979018AE8280D4Eacb8cDD295FCd";

  const wETHGateway = '0x665a8beb5E1E0876240aeae65F59E7C1ab95d3D8';
  const walletBalanceProvider = '0x47903c1589e180f07E29E387696f8911BF1242Ec';
  const uiPoolDataProviderV3 = '0x206543e36ECE2cEd36331f4A106eb84fBd1d7696';
  const uiIncentiveDataProviderV3 = '0x1CACe2064C53B5e5DEc5Ad47e3e35C455E32f51f';
  
  await verify({
    address: poolAddressesProvider,
    constructorArguments: [
      "BSC Testnet",
      DEPLOYER,
    ]
  })

  await verify({
    address: poolAddressesProviderRegistry,
    constructorArguments: [
      DEPLOYER,
    ]
  })

  await verify({
    address: monetariaProtocolDataProvider,
    constructorArguments: [
      poolAddressesProvider
    ]
  })

  await verify({
    address: aclManager,
    constructorArguments: [
      poolAddressesProvider
    ]
  })

  await verify({
    address: poolConfiguratorImpl,
    constructorArguments: [
    ]
  })

  await verify({
    address: poolConfigurator,
    constructorArguments: [
      poolAddressesProvider
    ]
  })

  await verify({
    address: monetariaOracle,
    constructorArguments: [
      poolAddressesProvider,
      [
        '0x87ee3ED4B0fbcadAc4a3D9797a77C112ccE9143e',
        '0xEC09910cC141cb409Cfd1Cb78611c18852a63028',
        '0x7E1c82bf3f14461D41B3AA75c274a0e222692eCf',
        '0xa3D90fC1FFaA5721A6037664E7AAF7F707330740',
      ], 
      [
        '0x78479830e0b28244C25a35Aeb743F76AC341bF58',
        '0x5A87401b224235f72bD50183a688ec7ccc26D451',
        '0xD4Db7FE100D85ec2AC615188D88568e582E97AA0',
        '0xCb16C6C2Af8741CF71810746EE0217D34a08a6ce',
      ], 
      ZERO_ADDRESS,
      ZERO_ADDRESS,
      1
    ]
  })

  await verify({
    address: liquidationLogic,
    constructorArguments: [
    ]
  })

  await verify({
    address: borrowLogic,
    constructorArguments: [
    ]
  })

  await verify({
    address: supplyLogic,
    constructorArguments: [
    ]
  })

  await verify({
    address: eModeLogic,
    constructorArguments: [
    ]
  })

  await verify({
    address: flashLoanLogic,
    constructorArguments: [
    ]
  })
  
  await verify({
    address: configuratorLogic,
    constructorArguments: [
    ]
  })
  
  await verify({
    address: bridgeLogic,
    constructorArguments: [
    ]
  })
  
  await verify({
    address: poolLogic,
    constructorArguments: [
    ]
  })

  await verify({
    address: poolImpl,
    constructorArguments: [
      poolAddressesProvider
    ]
  })

  await verify({
    address: pool,
    constructorArguments: [
      poolAddressesProvider
    ]
  })

  await verify({
    address: reservesSetupHelper,
    constructorArguments: [
    ]
  })

  await verify({
    address: uiPoolDataProviderV3,
    constructorArguments: [
      '0x5A87401b224235f72bD50183a688ec7ccc26D451',
      '0x5A87401b224235f72bD50183a688ec7ccc26D451',
    ]
  })

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

