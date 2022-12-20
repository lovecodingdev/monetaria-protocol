const hre = require("hardhat");
const { BigNumber, utils } = require('ethers');
const { ethers } = require("hardhat");

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
const AVG_BLOCK_TIME = 15_000;

let DEPLOYED = {};

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
    await verify({
      address: contract.address,
      constructorArguments: params
    });
    console.log(`${deployedKey} verified`);
  }
  return contract;
}

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
