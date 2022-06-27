// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {IMonetariaIncentivesController} from './IMonetariaIncentivesController.sol';
import {IPool} from './IPool.sol';

/**
 * @title IInitializableMToken
 * @author Monetaria
 * @notice Interface for the initialize function on MToken
 **/
interface IInitializableMToken {
  /**
   * @dev Emitted when an mToken is initialized
   * @param underlyingAsset The address of the underlying asset
   * @param pool The address of the associated pool
   * @param treasury The address of the treasury
   * @param incentivesController The address of the incentives controller for this mToken
   * @param mTokenDecimals The decimals of the underlying
   * @param mTokenName The name of the mToken
   * @param mTokenSymbol The symbol of the mToken
   * @param params A set of encoded parameters for additional initialization
   **/
  event Initialized(
    address indexed underlyingAsset,
    address indexed pool,
    address treasury,
    address incentivesController,
    uint8 mTokenDecimals,
    string mTokenName,
    string mTokenSymbol,
    bytes params
  );

  /**
   * @notice Initializes the mToken
   * @param pool The pool contract that is initializing this contract
   * @param treasury The address of the Monetaria treasury, receiving the fees on this mToken
   * @param underlyingAsset The address of the underlying asset of this mToken (E.g. WETH for aWETH)
   * @param incentivesController The smart contract managing potential incentives distribution
   * @param mTokenDecimals The decimals of the mToken, same as the underlying asset's
   * @param mTokenName The name of the mToken
   * @param mTokenSymbol The symbol of the mToken
   * @param params A set of encoded parameters for additional initialization
   */
  function initialize(
    IPool pool,
    address treasury,
    address underlyingAsset,
    IMonetariaIncentivesController incentivesController,
    uint8 mTokenDecimals,
    string calldata mTokenName,
    string calldata mTokenSymbol,
    bytes calldata params
  ) external;
}
