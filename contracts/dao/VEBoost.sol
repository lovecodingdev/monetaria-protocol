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

interface BoostV1 {
  function ownerOf(uint256 _token_id) external view returns(address);
  function token_boost(uint256 _token_id) external view returns(int256);
  function token_expiry(uint256 _token_id) external view returns(uint256);
}

/**
 * @title Boost Delegation
 * @author Monetaria
 * @notice Boost Delegation
 */
 
contract VEBoost is EIP712 {
  event Approval(
    address indexed _owner,
    address indexed _spender,
    uint256 _value 
  );

  event Transfer(
    address indexed _from,
    address indexed _to,
    uint256 _value
  );

  event Boost (
    address indexed _from,
    address indexed _to,
    uint256 _bias, 
    uint256 _slope, 
    uint256 _start
  );

  event Migrate (
    uint256 indexed _token_id
  );

  struct Point {
    uint256 bias;
    uint256 slope;
    uint256 ts;
  }

  
  string constant NAME = "Vote-Escrowed Boost";
  string constant SYMBOL = "veBoost";
  string constant VERSION = "v1.0.0";

  bytes32 constant EIP712_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)");
  bytes32 constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

  uint256 constant WEEK = 86400 * 7;

  bytes32 immutable _DOMAIN_SEPARATOR;
  address immutable _VE;

  mapping(address => mapping(address => uint256)) public allowance;
  mapping(address => uint256) public nonces;

  mapping(address => Point) public delegated;
  mapping(address => mapping(uint256 => uint256)) public delegated_slope_changes;

  mapping(address => Point) public received;
  mapping(address => mapping(uint256 => uint256)) public received_slope_changes;

  constructor(address _ve) EIP712("VEBoost", "1") {
    _DOMAIN_SEPARATOR = keccak256(abi.encode(EIP712_TYPEHASH, keccak256(bytes(NAME)), keccak256(bytes(VERSION)), block.chainid, address(this), blockhash(block.number - 1)));
    _VE = _ve;

    emit Transfer(address(0), msg.sender, 0);
  }

  function _checkpoint_read(address _user, bool _delegated) internal view returns(Point memory){
    Point memory point;

    if (_delegated) {
      point = delegated[_user];
    }else{
      point = received[_user];
    }

    if (point.ts == 0) {
      point.ts = block.timestamp;
    }

    if (point.ts == block.timestamp) {
      return point;
    }

    uint256 ts = (point.ts / WEEK) * WEEK;
    for(int i = 0; i < 255; i ++){
      ts += WEEK;

      uint256 dslope = 0;
      if (block.timestamp < ts) {
        ts = block.timestamp;
      }else{
        if (_delegated) {
          dslope = delegated_slope_changes[_user][ts];
        }else{
          dslope = received_slope_changes[_user][ts];
        }
      }

      point.bias -= point.slope * (ts - point.ts);
      point.slope -= dslope;
      point.ts = ts;

      if (ts == block.timestamp) {
        break;
      }
    }

    return point;
  }

  function _checkpoint_write(address _user, bool _delegated) internal returns(Point memory){
    Point memory point;

    if (_delegated) {
      point = delegated[_user];
    }else{
      point = received[_user];
    }

    if (point.ts == 0) {
      point.ts = block.timestamp;
    }

    if (point.ts == block.timestamp) {
      return point;
    }

    uint256 dbias = 0;
    uint256 ts = (point.ts / WEEK) * WEEK;
    for(int i = 0; i < 255; i ++){
      ts += WEEK;

      uint256 dslope = 0;
      if (block.timestamp < ts) {
        ts = block.timestamp;
      } else {
        if (_delegated) {
          dslope = delegated_slope_changes[_user][ts];
        } else {
          dslope = received_slope_changes[_user][ts];
        }
      }

      uint256 amount = point.slope * (ts - point.ts);

      dbias += amount;
      point.bias -= amount;
      point.slope -= dslope;
      point.ts = ts;

      if (ts == block.timestamp) {
        break;
      }
    }

    if (_delegated == false && dbias != 0) { // received boost
      emit Transfer(_user, address(0), dbias);
    }
    return point;
  }

  function _balance_of(address _user) internal view returns(uint256){
    uint256 amount = VotingEscrow(_VE).balanceOf(_user);

    Point memory point = _checkpoint_read(_user, true);
    amount -= (point.bias - point.slope * (block.timestamp - point.ts));

    point = _checkpoint_read(_user, false);
    amount += (point.bias - point.slope * (block.timestamp - point.ts));
    return amount;
  }

  function _boost(address _from, address _to, uint256 _amount, uint256 _endtime) internal {
    require(_to != _from && _to != address(0));
    require(_amount != 0);
    require(_endtime > block.timestamp);
    require(_endtime % WEEK == 0);
    require(_endtime <= VotingEscrow(_VE).locked__end(_from));

    // checkpoint delegated point
    Point memory point = _checkpoint_write(_from, true);
    require(_amount <= VotingEscrow(_VE).balanceOf(_from) - (point.bias - point.slope * (block.timestamp - point.ts)));

    // calculate slope and bias being added
    uint256 slope = _amount / (_endtime - block.timestamp);
    uint256 bias = slope * (_endtime - block.timestamp);

    // update delegated point
    point.bias += bias;
    point.slope += slope;

    // store updated values
    delegated[_from] = point;
    delegated_slope_changes[_from][_endtime] += slope;

    // update received amount
    point = _checkpoint_write(_to, false);
    point.bias += bias;
    point.slope += slope;

    // store updated values
    received[_to] = point;
    received_slope_changes[_to][_endtime] += slope;

    emit Transfer(_from, _to, _amount);
    emit Boost(_from, _to, bias, slope, block.timestamp);

    // also checkpoint received and delegated
    received[_from] = _checkpoint_write(_from, false);
    delegated[_to] = _checkpoint_write(_to, true);
  }

  function _boost_(address _to, uint256 _amount, uint256 _endtime, address _from) internal {
    // reduce approval if necessary
    if (_from != msg.sender) {
      uint256 _allowance = allowance[_from][msg.sender];
      if (_allowance != type(uint256).max) {
        allowance[_from][msg.sender] = _allowance - _amount;
        emit Approval(_from, msg.sender, _allowance - _amount);
      }
    }

    _boost(_from, _to, _amount, _endtime);
  }

  function boost(address _to, uint256 _amount, uint256 _endtime) external {
    _boost_(_to, _amount, _endtime, msg.sender);
  }

  function boost(address _to, uint256 _amount, uint256 _endtime, address _from) external {
    _boost_(_to, _amount, _endtime, _from);
  }

  function checkpoint_user(address _user) external {
    delegated[_user] = _checkpoint_write(_user, true);
    received[_user] = _checkpoint_write(_user, false);
  }

  /**
    * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
    *
    * This internal function is equivalent to `approve`, and can be used to
    * e.g. set automatic allowances for certain subsystems, etc.
    *
    * Emits an {Approval} event.
    *
    * Requirements:
    *
    * - `owner` cannot be the zero address.
    * - `spender` cannot be the zero address.
    */
  function _approve(
      address owner,
      address spender,
      uint256 amount
  ) internal {
      require(owner != address(0), "ERC20: approve from the zero address");
      require(spender != address(0), "ERC20: approve to the zero address");

      allowance[owner][spender] = amount;
      emit Approval(owner, spender, amount);
  }

  function approve(address _spender, uint256 _value) external returns(bool){
    address owner = msg.sender;
    _approve(owner, _spender, _value);
    return true;
  }

    /**
    @notice Approves spender by owner's signature to expend owner's tokens.
        See https://eips.ethereum.org/EIPS/eip-2612.
    @dev Inspired by https://github.com/yearn/yearn-vaults/blob/main/contracts/Vault.vy#L753-L793
    @dev Supports smart contract wallets which implement ERC1271
        https://eips.ethereum.org/EIPS/eip-1271
    @param _owner The address which is a source of funds and has signed the Permit.
    @param _spender The address which is allowed to spend the funds.
    @param _value The amount of tokens to be spent.
    @param _deadline The timestamp after which the Permit is no longer valid.
    @param _v The bytes[64] of the valid secp256k1 signature of permit by owner
    @param _r The bytes[0:32] of the valid secp256k1 signature of permit by owner
    @param _s The bytes[32:64] of the valid secp256k1 signature of permit by owner
    @return True, if transaction completes successfully
   */
  function permit(
    address _owner,
    address _spender,
    uint256 _value,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external returns (bool) {
    require(_owner != address(0));
    require(block.timestamp <= _deadline, "ERC20Permit: expired deadline");

    uint256 nonce = nonces[_owner];

    bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, _owner, _spender, _value, nonce, _deadline));

    bytes32 hash = _hashTypedDataV4(structHash);

    address signer = ECDSA.recover(hash, _v, _r, _s);
    require(signer == _owner, "ERC20Permit: invalid signature");

    _approve(_owner, _spender, _value);
    nonces[_owner] = nonce + 1;

    return true;
  }

  /**
    * @dev Atomically increases the allowance granted to `spender` by the caller.
    *
    * This is an alternative to {approve} that can be used as a mitigation for
    * problems described in {IERC20-approve}.
    *
    * Emits an {Approval} event indicating the updated allowance.
    *
    * Requirements:
    *
    * - `spender` cannot be the zero address.
    */
  function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
    address owner = msg.sender;
    _approve(owner, spender, allowance[owner][spender] + addedValue);
    return true;
  }

  /**
    * @dev Atomically decreases the allowance granted to `spender` by the caller.
    *
    * This is an alternative to {approve} that can be used as a mitigation for
    * problems described in {IERC20-approve}.
    *
    * Emits an {Approval} event indicating the updated allowance.
    *
    * Requirements:
    *
    * - `spender` cannot be the zero address.
    * - `spender` must have allowance for the caller of at least
    * `subtractedValue`.
    */
  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
    address owner = msg.sender;
    uint256 currentAllowance = allowance[owner][spender];
    require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
    unchecked {
        _approve(owner, spender, currentAllowance - subtractedValue);
    }

    return true;
  }

  function balanceOf(address _user) external view returns(uint256){
    return _balance_of(_user);
  }

  function adjusted_balance_of(address _user) external view returns(uint256){
    return _balance_of(_user);
  }

  function totalSupply() external view returns(uint256){
    return VotingEscrow(_VE).totalSupply();
  }

  function delegated_balance(address _user) external view returns(uint256){
    Point memory point = _checkpoint_read(_user, true);
    return point.bias - point.slope * (block.timestamp - point.ts);
  }


  function received_balance(address _user) external view returns(uint256){
    Point memory point = _checkpoint_read(_user, false);
    return point.bias - point.slope * (block.timestamp - point.ts);
  }

  function delegable_balance(address _user) external view returns(uint256){
    Point memory point = _checkpoint_read(_user, true);
    return VotingEscrow(_VE).balanceOf(_user) - (point.bias - point.slope * (block.timestamp - point.ts));
  }

    /**
    @notice Get the name for this gauge token
   */
  function name() external pure returns(string memory){
    return NAME;
  }

  /**
    @notice Get the symbol for this gauge token
   */
  function symbol() external pure returns(string memory){
    return SYMBOL;
  }

  /**
    @notice Get the number of decimals for this token
    @dev Implemented as a view method to reduce gas costs
    @return uint256 decimal places
   */
  function decimals() external pure returns(uint256) {
    return 18;
  }

  /**
    @notice Get the version of this gauge
   */
  function version() external pure returns(string memory) {
    return VERSION;
  }

  /**
    @notice Domain separator for this contract
   */
  function DOMAIN_SEPARATOR() external view returns(bytes32) {
    return _DOMAIN_SEPARATOR;
  }

  function VE() external view returns(address) {
    return _VE;
  }

}