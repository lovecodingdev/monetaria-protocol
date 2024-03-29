// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IMasterChefBSC {
  function pendingCake(uint256 pid, address user) external view returns (uint256);

  function deposit(uint256 pid, uint256 amount) external;

  function withdraw(uint256 pid, uint256 amount) external;

  function emergencyWithdraw(uint256 pid) external;
}
