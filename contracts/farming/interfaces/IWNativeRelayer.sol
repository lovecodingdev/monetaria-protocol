// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IWNativeRelayer {
  function withdraw(uint256 _amount) external;
}