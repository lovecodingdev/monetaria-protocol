// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Making the original MasterChefV2 as an interface leads to compilation fail.
// Use Contract instead of Interface here
contract IGenericPancakeMasterChef {
  // Deposit LP tokens to MasterChef for CAKE allocation.
  function deposit(uint256 _pid, uint256 _amount) external {}

  // Withdraw LP tokens from MasterChef.
  function withdraw(uint256 _pid, uint256 _amount) external {}

  function pendingCake(uint256 _pid, address _user) external view returns (uint256) {}
}
