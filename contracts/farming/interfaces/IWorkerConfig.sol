// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IWorkerConfig {
  /// @dev Return whether the given worker accepts more debt.
  function acceptDebt(address worker) external view returns (bool);

  /// @dev Return the work factor for the worker + debt, using 1e4 as denom.
  function workFactor(address worker, uint256 debt) external view returns (uint256);

  /// @dev Return the work factor for the worker + debt, using 1e4 as denom.
  function workFactor(
    address worker,
    uint256 debt,
    address positionOwner
  ) external view returns (uint256);

  /// @dev Return the kill factor for the worker + debt, using 1e4 as denom.
  function killFactor(address worker, uint256 debt) external view returns (uint256);

  /// @dev Return the kill factor for the worker + debt, using 1e4 as denom.
  function killFactor(
    address worker,
    uint256 debt,
    address positionOwner
  ) external view returns (uint256);

  /// @dev Return the kill factor for the worker + debt without checking isStable, using 1e4 as denom.
  function rawKillFactor(address worker, uint256 debt) external view returns (uint256);

  /// @dev Return the kill factor for the worker + debt without checking isStable, using 1e4 as denom.
  function rawKillFactor(
    address worker,
    uint256 debt,
    address positionOwner
  ) external view returns (uint256);

  /// @dev Return if worker is stable.
  function isStable(address worker) external view returns (bool);

  /// @dev Revert if liquidity pool under manipulation
  function isReserveConsistent(address worker) external view returns (bool);
}
