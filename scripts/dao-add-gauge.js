const hre = require("hardhat");
const { BigNumber, utils } = require('ethers');
const { ethers } = require("hardhat");
const { ZERO_ADDRESS, deploy } = require("./helpers")

async function main() {
  const [signer] = await ethers.getSigners();
  const DEPLOYER = signer.address;

  const LP_TOKEN = '0x9E0Bb0E2dfA711F7076bB04A8cBbE526855107e7'; //WBTC_MTOKEN
  
  const _MNTToken = '0x64E2C58F063EFED4477C313a4d4e51184CfFE198';
  const _VotingEscrow = '0x823C2FCEc33005188b3FA5eFB7130851C91e9562';
  const _GaugeController = '0x39c76fD1808e1a3A1db4D3B82b360D65c48C50F3';
  const _VEBoostProxy = '0x377Ad7013986Ae9af2e7329544F49916d175433D';
  const _Minter = '0xF1C88F235a1292075Da43f70f6c51eefdb5BAf60';
  
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
