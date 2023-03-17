const hre = require("hardhat");
const { BigNumber, utils } = require('ethers');
const { ethers } = require("hardhat");
const { ZERO_ADDRESS, deploy } = require("./helpers")

async function main() {
  const [signer] = await ethers.getSigners();
  const DEPLOYER = signer.address;
  
  const mntToken = await deploy("MNTToken");
  const veMNT = await deploy("VotingEscrow", {
    params: [mntToken.address,"Vote-Escrowed MNT", "veMNT", "v1.0.0"]
  });
  const gaugeController = await deploy("GaugeController", {
    params: [mntToken.address, veMNT.address]
  });
  const veBoost = await deploy("VEBoost", {
    params: [veMNT.address]
  });
  const veBoostProxy = await deploy("VEBoostProxy", {
    params: [veBoost.address, DEPLOYER, DEPLOYER]
  });
  const minter = await deploy("Minter", {
    params: [mntToken.address, gaugeController.address]
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
