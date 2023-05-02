const hre = require("hardhat");
const { BigNumber, utils } = require('ethers');
const { ethers } = require("hardhat");
const { ZERO_ADDRESS, deploy } = require("./helpers")

//Input for ETH Goerli
const LP_TOKEN = '0x55D603096FaeafFe8c634d1b35196a96a68e27A4'; //USDC_MTOKEN
const _MNTToken = '0x778190A52Ec57684e2a4AAa25aE1f3b68Ce2e2a7';
const _VotingEscrow = '0x24C3d01A33F0979a287c4F81A307AcCA001DE72e';
const _GaugeController = '0x7335dC5eB92Ca16E12e0A8F61F075c46c065190E';
const _VEBoostProxy = '0xCcF4C97Bd5A772EB28e60951121635DEe877d8EB';
const _Minter = '0x758E3CdB0d49C4328FE7cb187c4215D4e6DA622d';

async function main() {
  const [signer] = await ethers.getSigners();
  const DEPLOYER = signer.address;

  const gaugeController = await hre.ethers.getContractAt("GaugeController", _GaugeController);
  console.log("GaugeController: ", gaugeController.address);

  const liquidityGauge = await deploy("LiquidityGauge", {
    params: [
      LP_TOKEN,
      DEPLOYER,
      _Minter,
      _MNTToken,
      _VotingEscrow,
      _GaugeController,
      _VEBoostProxy
    ]
  });
  tx = await gaugeController["add_gauge(address,int128)"](liquidityGauge.address, 0);
  await tx.wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
