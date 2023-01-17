// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IMdexSwapMining {
  /// @dev Get rewards from users in the current pool;
  function getUserReward(uint256 pid) external view returns (uint256, uint256);

  /// @dev Withdraws all the transaction rewards of the pool
  function takerWithdraw() external;
}
