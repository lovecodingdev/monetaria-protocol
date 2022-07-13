// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.9;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IDelegationToken} from '../../interfaces/IDelegationToken.sol';

/**
 * @title MintableDelegationERC20
 * @dev ERC20 minting logic with delegation
 */
contract MintableDelegationERC20 is IDelegationToken, ERC20 {
  address public delegatee;
  uint8 private immutable _decimals;

  constructor(
    string memory name,
    string memory symbol,
    uint8 decimals_
  ) ERC20(name, symbol) {
    _decimals = decimals_;
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  /**
   * @dev Function to mint tokens
   * @param value The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(uint256 value) public returns (bool) {
    _mint(msg.sender, value);
    return true;
  }

  function delegate(address delegateeAddress) external override {
    delegatee = delegateeAddress;
  }
}
