// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.9;

import {IStakedToken} from '../interfaces/IStakedToken.sol';
import {ITransferStrategyBase} from './ITransferStrategyBase.sol';

/**
 * @title IStakedTokenTransferStrategy
 * @author Monetaria
 **/
interface IStakedTokenTransferStrategy is ITransferStrategyBase {
  /**
   * @dev Perform a MAX_UINT approval of MONETARIA to the Staked Monetaria contract.
   */
  function renewApproval() external;

  /**
   * @dev Drop approval of MONETARIA to the Staked Monetaria contract in case of emergency.
   */
  function dropApproval() external;

  /**
   * @return Staked Token contract address
   */
  function getStakeContract() external view returns (address);

  /**
   * @return Underlying token address from the stake contract
   */
  function getUnderlyingToken() external view returns (address);
}
