// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract IGenericSpookyMasterChef {
  // Info of each user.
  struct UserInfo {
    uint256 amount; // How many LP tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
  }
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;

  // Deposit LP tokens to MasterChef for BOO allocation.
  function deposit(uint256 _pid, uint256 _amount) external {}

  // Withdraw LP tokens from MasterChef.
  function withdraw(uint256 _pid, uint256 _amount) external {}

  function pendingBOO(uint256 _pid, address _user) external view returns (uint256) {}
}
