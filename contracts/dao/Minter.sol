// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';

import './GaugeController.sol';
import './LiquidityGauge.sol';
import './MNTToken.sol';

/**
 * @title Token Minter
 * @author Monetaria
 * @notice Implementation of Token Minter
 */
contract Minter {
  using SafeMath for uint256;

  event Minted(
    address indexed recipient,
    address gauge,
    uint256 minted
  );
  
  address public token;
  address public controller;

  // user -> gauge -> value
  mapping(address => mapping(address => uint256)) public minted;

  // minter -> user -> can mint?
  mapping(address => mapping(address => bool)) public allowed_to_mint_for;

  constructor(address _token, address _controller) {
    token = _token;
    controller = _controller;
  }

  function _mint_for(address gauge_addr, address _for) internal {
    require(GaugeController(controller).gauge_types(gauge_addr) >= 0);  // dev: gauge is not added

    LiquidityGauge(gauge_addr).user_checkpoint(_for);
    uint256 total_mint = LiquidityGauge(gauge_addr).integrate_fraction(_for);
    uint256 to_mint = total_mint - minted[_for][gauge_addr];

    if (to_mint != 0) {
      MNTToken(token).mint(_for, to_mint);
      minted[_for][gauge_addr] = total_mint;

      emit Minted(_for, gauge_addr, total_mint);
    }
  }

  /**
    @notice Mint everything which belongs to `msg.sender` and send to them
    @param gauge_addr `LiquidityGauge` address to get mintable amount from
   */
  // @nonreentrant('lock')
  function mint(address gauge_addr) external {
    _mint_for(gauge_addr, msg.sender);
  }

  /**
    @notice Mint everything which belongs to `msg.sender` across multiple gauges
    @param gauge_addrs List of `LiquidityGauge` addresses
   */
  // @nonreentrant('lock')
  function mint_many(address[8] memory gauge_addrs) external {
    for(uint i = 0; i < 8; i ++){
      if (gauge_addrs[i] == address(0)) {
        break;
      }
      _mint_for(gauge_addrs[i], msg.sender);
    }
  }

  /**
    @notice Mint tokens for `_for`
    @dev Only possible when `msg.sender` has been approved via `toggle_approve_mint`
    @param gauge_addr `LiquidityGauge` address to get mintable amount from
    @param _for Address to mint to
   */
  // @nonreentrant('lock')
  function mint_for(address gauge_addr, address _for) external {
    if (allowed_to_mint_for[msg.sender][_for]) {
      _mint_for(gauge_addr, _for);
    }
  }

  /**
    @notice allow `minting_user` to mint for `msg.sender`
    @param minting_user Address to toggle permission for
   */
  function toggle_approve_mint(address minting_user) external {
    allowed_to_mint_for[minting_user][msg.sender] = !allowed_to_mint_for[minting_user][msg.sender];
  }
}