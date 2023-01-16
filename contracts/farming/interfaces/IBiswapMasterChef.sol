// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract IBiswapMasterChef {
  // Info of each user.
  struct UserInfo {
    uint256 amount; // How many LP tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
  }

  // Info of each pool.
  struct PoolInfo {
    IERC20 lpToken; // Address of LP token contract.
    uint256 allocPoint; // How many allocation points assigned to this pool. BSWs to distribute per block.
    uint256 lastRewardBlock; // Last block number that BSWs distribution occurs.
    uint256 accBSWPerShare; // Accumulated BSW per share, times 1e12. See below.
  }

  // the reward token like CAKE, in this case, it's called BSW
  address public BSW;

  // Info of each pool.
  PoolInfo[] public poolInfo;

  // Info of each user that stakes LP tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;

  // Deposit LP tokens to MasterChef for BSW allocation.
  function deposit(uint256 _pid, uint256 _amount) external virtual;

  // Withdraw LP tokens from MasterChef.
  function withdraw(uint256 _pid, uint256 _amount) external virtual;

  // Query pending BSW
  function pendingBSW(uint256 _pid, address _user) external virtual returns (uint256);
}
