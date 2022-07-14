// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {DataTypes} from '../../protocol/libs/types/DataTypes.sol';

/**
 * @title DataTypesHelper
 * @author Monetaria
 * @dev Helper library to track user current debt balance, used by WETHGateway
 */
library DataTypesHelper {
  /**
   * @notice Fetches the user current stable and variable debt balances
   * @param user The user address
   * @param reserve The reserve data object
   * @return The stable debt balance
   * @return The variable debt balance
   **/
  function getUserCurrentDebt(address user, DataTypes.ReserveData memory reserve)
    internal
    view
    returns (uint256, uint256)
  {
    return (
      IERC20(reserve.stableDebtTokenAddress).balanceOf(user),
      IERC20(reserve.variableDebtTokenAddress).balanceOf(user)
    );
  }
}
