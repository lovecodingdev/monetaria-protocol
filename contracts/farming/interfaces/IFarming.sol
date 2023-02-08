// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IFarming {
  /// @notice Return the total ERC20 entitled to the token holders. Be careful of unaccrued interests.
  function totalToken() external view returns (uint256);

  /// @notice Request funds from user through Vault
  function requestFunds(address targetedToken, uint256 amount) external;

  /// @notice Underlying token address
  function token() external view returns (address);
}
