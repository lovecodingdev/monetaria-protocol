// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IVault {
  /// @notice Return the total ERC20 entitled to the token holders. Be careful of unaccrued interests.
  function totalToken() external view returns (uint256);

  /// @notice Add more ERC20 to the bank. Hope to get some good returns.
  function deposit(uint256 amountToken) external payable;

  /// @notice Withdraw ERC20 from the bank by burning the share tokens.
  function withdraw(uint256 share) external;

  /// @notice Request funds from user through Vault
  function requestFunds(address targetedToken, uint256 amount) external;

  /// @notice Underlying token address
  function token() external view returns (address);
}
