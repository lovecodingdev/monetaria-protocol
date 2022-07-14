// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {ITransferStrategyBase} from './ITransferStrategyBase.sol';

/**
 * @title IPullRewardsTransferStrategy
 * @author Monetaria
 **/
interface IPullRewardsTransferStrategy is ITransferStrategyBase {
  /**
   * @return Address of the rewards vault
   */
  function getRewardsVault() external view returns (address);
}
