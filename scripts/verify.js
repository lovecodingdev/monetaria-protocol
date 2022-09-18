const hre = require("hardhat");

async function main() {
  const [ signer ] = await ethers.getSigners();
  const DEPLOYER = signer.address;

  const poolAddressesProvider = "0xabf63fe04c46e4f539F9a63E8ab4355636e802AA";
  const poolAddressesProviderRegistry = "0x87Aebc6809c8e2CB7370ef6dac47e604EDd0065c";
  const monetariaProtocolDataProvider = "0xaD1d03B474B143856c1E522d3e3B1909107e3b40";
  const aclManager = "0x0A9d17f3aB363f6Ee5e51EF48d0ccE40F98F72B2";
  const btcpxToken = "0x9D51a697f82DBaEfe09C34dc0c3F7e94b960ddA8";
  const usdcToken = "0x8f75DB6A17c05391b6D9918eBE8B1F895a3e3900";
  const prxyToken = "0x97F09A382700320f41d97DFBc3b730E0D70e7a04";

  const btcpxAggregator = "0x1E7E7e51de6E425B0778abbDa2794C0E418CE166";
  const usdcAggregator = "0x68C25f8671ab0efCe98739fc19016356d3065359";
  const prxyAggregator = "0x06AF38D21399720b9181986F8eaa50c329dD3Aaa";

  const aaveOracle = "0x1631CDd670e9c3D7a1f3a5483C9666dAe2746d30";
  const configuratorLogic = "0x116C4F5048bFcce38E59c7d5DC560Ac007176847";
  const liquidationLogic = "0x828664116459DBB70d0cb5c3DBcF5698B7288Ad4";
  const borrowLogic = "0x26D0995F20f50E567011E389F3945d6f17A4b456";
  const supplyLogic = "0xb3195F7581F7ef066e1bF4AAf6aB5011b8eD6B33";
  const poolLogic = "0x7dF5a97217f33056A126E6eb9a12dc7C522c023d";
  const particularLogic = "0xfD6c56803DbE87094859A6Dd3BDb712A2C87BAe5";

  const poolImpl = "0xFd9254e84666b10Eee9E6dEE0Fe6c3333e63D373";
  const pool = "0xd0aEe99E12219bA64CD2bf3dD17e04669405356F";
  const poolConfiguratorImpl = "0x0637e976c42bED5182A8000035d9B25466f41Cc3";
  const poolConfigurator = "0x2B39A38dB049D1cb1C22adb7cA234aaEce80ffbD";
  const prxyTreasury = "0x6937971ab637E14A994290C68e890FDDd10E4110";
  const pTokenImpl = "0x5ebF44771aC95C023132789a261Ab707493e5d51";
  const reservesSetupHelper = "0x499eFDad9aca7323894790B1350d0aecf3E5dD0d";

  // await hre.run("verify:verify", {
  //   address: poolAddressesProvider,
  //   constructorArguments: [
  //     "ETH_Goerli",
  //     DEPLOYER,
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: poolAddressesProviderRegistry,
  //   constructorArguments: [
  //     DEPLOYER,
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: monetariaProtocolDataProvider,
  //   constructorArguments: [
  //     poolAddressesProvider
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: aclManager,
  //   constructorArguments: [
  //     poolAddressesProvider
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: aaveOracle,
  //   constructorArguments: [
  //     poolAddressesProvider,
  //     [ btcpxToken, usdcToken ],
  //     [ btcpxAggregator, usdcAggregator ],
  //     "0x0000000000000000000000000000000000000000",
  //     "0x0000000000000000000000000000000000000000",
  //     0
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: particularLogic,
  //   constructorArguments: [
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: liquidationLogic,
  //   constructorArguments: [
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: borrowLogic,
  //   constructorArguments: [
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: supplyLogic,
  //   constructorArguments: [
  //   ]
  // })
  
  // await hre.run("verify:verify", {
  //   address: poolLogic,
  //   constructorArguments: [
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: poolImpl,
  //   constructorArguments: [
  //     poolAddressesProvider
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: pool,
  //   constructorArguments: [
  //     poolAddressesProvider
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: poolConfiguratorImpl,
  //   constructorArguments: [
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: pTokenImpl,
  //   constructorArguments: [
  //     pool
  //   ]
  // })

  // await hre.run("verify:verify", {
  //   address: reservesSetupHelper,
  //   constructorArguments: [
  //   ]
  // })
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

