// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.9;

import {IPool} from '../../interfaces/IPool.sol';
import {IDelegationToken} from '../../interfaces/IDelegationToken.sol';
import {MToken} from './MToken.sol';

/**
 * @title DelegationAwareAToken
 * @author Monetaria
 * @notice MToken enabled to delegate voting power of the underlying asset to a different address
 * @dev The underlying asset needs to be compatible with the COMP delegation interface
 */
contract DelegationAwareAToken is MToken {
  /**
   * @dev Emitted when underlying voting power is delegated
   * @param delegatee The address of the delegatee
   */
  event DelegateUnderlyingTo(address indexed delegatee);

  /**
   * @dev Constructor.
   * @param pool The address of the Pool contract
   */
  constructor(IPool pool) MToken(pool) {
    // Intentionally left blank
  }

  /**
   * @notice Delegates voting power of the underlying asset to a `delegatee` address
   * @param delegatee The address that will receive the delegation
   **/
  function delegateUnderlyingTo(address delegatee) external onlyPoolAdmin {
    IDelegationToken(_underlyingAsset).delegate(delegatee);
    emit DelegateUnderlyingTo(delegatee);
  }
}
