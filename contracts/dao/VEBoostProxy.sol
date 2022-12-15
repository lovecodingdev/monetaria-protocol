// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

import './MNTToken.sol';
import './VotingEscrow.sol';
import './VEBoost.sol';

/**
 * @title Boost Delegation Proxy
 * @author Monetaria
 * @notice Boost Delegation Proxy
 */
 
contract VEBoostProxy {
  event CommitAdmins (
    address ownership_admin,
    address emergency_admin
  );

  event ApplyAdmins(
    address ownership_admin,
    address emergency_admin
  );

  event DelegationSet(
    address delegation
  );

  address constant VOTING_ESCROW = 0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2;

  address public delegation;

  address public emergency_admin;
  address public ownership_admin;
  address public future_emergency_admin;
  address public future_ownership_admin;

  constructor(address _delegation, address _o_admin, address _e_admin) {
    delegation = _delegation;
    ownership_admin = _o_admin;
    emergency_admin = _e_admin;

    emit DelegationSet(_delegation);
  }

  /**
    @notice Get the adjusted veMNT balance from the active boost delegation contract
    @param _account The account to query the adjusted veMNT balance of
    @return veMNT balance
   */
  function adjusted_balance_of(address _account) external view returns(uint256) {
    address _delegation = delegation;
    if (_delegation ==  address(0)) {
      return ERC20(VOTING_ESCROW).balanceOf(_account);
    }
    return VEBoost(_delegation).adjusted_balance_of(_account);
  }

  /**
    @notice Set delegation contract to 0x00, disabling boost delegation
    @dev Callable by the emergency admin in case of an issue with the delegation logic
   */
  function kill_delegation() external {
    require(msg.sender == ownership_admin || msg.sender == emergency_admin);

    delegation = address(0);

    emit DelegationSet(address(0));
  }

  /**
    @notice Set the delegation contract
    @dev Only callable by the ownership admin
    @param _delegation `VotingEscrowDelegation` deployment address
   */
  function set_delegation(address _delegation) external {
    require(msg.sender == ownership_admin, "Access denied");

    // call `adjusted_balance_of` to make sure it works
    VEBoost(_delegation).adjusted_balance_of(msg.sender);

    delegation = _delegation;

    emit DelegationSet(_delegation);
  }

  /**
    @notice Set ownership admin to `_o_admin` and emergency admin to `_e_admin`
    @param _o_admin Ownership admin
    @param _e_admin Emergency admin
   */
  function commit_set_admins(address _o_admin, address _e_admin) external {
    require(msg.sender == ownership_admin, "Access denied");

    future_ownership_admin = _o_admin;
    future_emergency_admin = _e_admin;

    emit CommitAdmins(_o_admin, _e_admin);
  }

  /**
    @notice Apply the effects of `commit_set_admins`
   */
  function apply_set_admins() external {
    require(msg.sender == ownership_admin, "Access denied");

    address _o_admin = future_ownership_admin;
    address _e_admin = future_emergency_admin;
    ownership_admin = _o_admin;
    emergency_admin = _e_admin;

    emit ApplyAdmins(_o_admin, _e_admin);
  }
}