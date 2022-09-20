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

  const poolAddressesProvider = "0xabf63fe04c46e4f539F9a63E8ab4355636e802AA";
  const poolAddressesProviderRegistry = "0x87Aebc6809c8e2CB7370ef6dac47e604EDd0065c";
  const monetariaProtocolDataProvider = "0xaD1d03B474B143856c1E522d3e3B1909107e3b40";
  const aclManager = "0x0A9d17f3aB363f6Ee5e51EF48d0ccE40F98F72B2";
  const poolConfiguratorImpl = "0x05184AeC80cA506Df14a876B46405FC35c42143A";
  const poolConfigurator = "0xea73e15b51723ba7ef9e71fbd4265172656101ee";

  const priceOracle = "0x69f6b5FeEC2F5F39f92289dd288F09A7bbc0A200";
  const monetariaOracle = "0x7f317b397120Dca9a8eC99FaB161843d8b7a51D2";

  const configuratorLogic = "0x9FF84701981Afa8f16b856dBcd6DEEF5421AEd8B";
  const liquidationLogic = "0xE6d2C61487194148dB78669E87A5653c64E33419";
  const borrowLogic = "0x9D8CA1671d4DfD02e4090af4fa1A92bd148717A1";
  const supplyLogic = "0x19Be61f8Ab6E1BB2634d82F7800BcF9c91c7Ca92";
  const poolLogic = "0x5572E5EB1dCdA4101Db6178DB275369160d7D002";
  const bridgeLogic = '0x7e6867c13CF89c4253a52B628ee32Cbc84a7e09e';
  const eModeLogic = '0x03a946A0B832E79f090D3bfDa733FbC14742E2Aa';
  const flashLoanLogic = '0xcd041E7fA59436adDB80Cc1A883663d860695903';
  
  const poolImpl = "0xD84353DE3aa9edAA50442f987A027CDf58d1f8da";
  const pool = "0xb7d086dcbc9ceca5479d64e8168eeaf3aa74782a";

  const reservesSetupHelper = "0x0207977fb4b34f4C943D2274114947FFA3973dBc";

  const wETHGateway = '0x301fd6DC1fEb455a38575C1610D033836C90A720';
  const walletBalanceProvider = '0xDE620449A1896fBDF532A9a05618C8047C0CC020';
  const uiPoolDataProviderV3 = '0x41e3057c29D12bdf0f4cceE00883504767ed6db9';
  const uiIncentiveDataProviderV3 = '0x25c5Fa5e212bd834eC3839ac2c451Ed3927c8363';
  
  await verify({
    address: poolAddressesProvider,
    constructorArguments: [
      "ETH_Goerli",
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
        '0x151AC69b7aef24b8E8dbE2c9aB7E4296569272f8',
        '0xE9c504aF8154995bdB94e8D3b6871c2fFC76De83',
        '0x4bfc328FfbAf2ac8ae90c90E832B0901aED02B5B',
        '0x72D6F8ba23aC707408E9dc35d81302d338E383aD',
      ], 
      [
        '0xcC0cF6b84c795ad280934E3Ae4a041144718852f',
        '0x5B6924b143C571F1a791441fd0d6Fb20F9be51Ca',
        '0x756b8D6D88d53fDAaBc517Fd3181c3393f2B0D30',
        '0x25d6fc3C5708f084e1E6543aCDB3792a31799b96',
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
      '0x5B6924b143C571F1a791441fd0d6Fb20F9be51Ca',
      '0x5B6924b143C571F1a791441fd0d6Fb20F9be51Ca',
    ]
  })

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

