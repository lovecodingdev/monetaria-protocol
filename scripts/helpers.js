const hre = require("hardhat");
const { BigNumber, utils } = require('ethers');

let DEPLOYED = {};
const AVG_BLOCK_TIME = 15_000;
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const GRACE_PERIOD = BigNumber.from(60 * 60);

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

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

module.exports = {
  AVG_BLOCK_TIME,
  ZERO_ADDRESS,
  GRACE_PERIOD,

  sleep,
  verify,
  deploy
}