// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {GPv2SafeERC20} from '../../dependencies/gnosis/contracts/GPv2SafeERC20.sol';
import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {VersionedInitializable} from '../libs/upgradeability/VersionedInitializable.sol';
import {Errors} from '../libs/helpers/Errors.sol';
import {WadRayMath} from '../libs/math/WadRayMath.sol';
import {IPool} from '../../interfaces/IPool.sol';
import {IMToken} from '../../interfaces/IMToken.sol';
import {IMonetariaIncentivesController} from '../../interfaces/IMonetariaIncentivesController.sol';
import {IInitializableMToken} from '../../interfaces/IInitializableMToken.sol';
import {ScaledBalanceTokenBase} from './base/ScaledBalanceTokenBase.sol';
import {IncentivizedERC20} from './base/IncentivizedERC20.sol';
import {EIP712Base} from './base/EIP712Base.sol';

import {GovernancePowerDelegationERC20} from './base/GovernancePowerDelegationERC20.sol';
import {ITransferHook} from '../../interfaces/ITransferHook.sol';

/**
 * @title Monetaria Token
 * @author Monetaria
 * @notice Implementation of the Monetaria token
 */
contract MNTToken is GovernancePowerDelegationERC20, VersionedInitializable {
  using SafeMath for uint256;

  string internal constant NAME = 'Monetaria Token';
  string internal constant SYMBOL = 'MNT';
  uint8 internal constant DECIMALS = 18;

  uint256 public constant REVISION = 1;

  // Allocation:
  // =========
  // * shareholders - 30%
  // * emplyees - 3%
  // * DAO-controlled reserve - 5%
  // * Early users - 5%
  // == 43% ==
  // left for inflation: 57%

  // Supply parameters
  uint256 internal constant YEAR = 86400 * 365;
  uint256 internal constant INITIAL_SUPPLY = 1_303_030_303;
  uint256 internal constant INITIAL_RATE = 274_815_283 * 10 ** 18 / YEAR;  // leading to 43% premine;
  uint256 internal constant RATE_REDUCTION_TIME = YEAR;
  uint256 internal constant RATE_REDUCTION_COEFFICIENT = 1189207115002721024;  // 2 ** (1/4) * 1e18;
  uint256 internal constant RATE_DENOMINATOR = 10 ** 18;
  uint256 internal constant INFLATION_DELAY = 86400;

  // Supply variables
  int128 public mining_epoch;
  uint256 public start_epoch_time;
  uint256 public rate;
  uint256 internal start_epoch_supply;

  /// @dev owner => next valid nonce to submit with permit()
  mapping(address => uint256) public _nonces;

  mapping(address => mapping(uint256 => Snapshot)) public _votingSnapshots;

  mapping(address => uint256) public _votingSnapshotsCounts;

  /// @dev reference to the Aave governance contract to call (if initialized) on _beforeTokenTransfer
  /// !!! IMPORTANT The Aave governance is considered a trustable contract, being its responsibility
  /// to control all potential reentrancies by calling back the AaveToken
  ITransferHook public _monetariaGovernance;

  bytes32 public DOMAIN_SEPARATOR;
  bytes public constant EIP712_REVISION = bytes('1');
  bytes32 internal constant EIP712_DOMAIN = keccak256(
    'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
  );
  bytes32 public constant PERMIT_TYPEHASH = keccak256(
    'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'
  );

  mapping(address => address) internal _votingDelegates;

  mapping(address => mapping(uint256 => Snapshot)) internal _propositionPowerSnapshots;
  mapping(address => uint256) internal _propositionPowerSnapshotsCounts;

  mapping(address => address) internal _propositionPowerDelegates;

  address public minter;
  address public admin;

  constructor() public ERC20(NAME, SYMBOL) {
    uint256 init_supply = INITIAL_SUPPLY * 10 ** DECIMALS;
    _mint(msg.sender, init_supply);

    admin = msg.sender;
    start_epoch_time = block.timestamp + INFLATION_DELAY - RATE_REDUCTION_TIME;
    mining_epoch = -1;
    rate = 0;
    start_epoch_supply = init_supply;
  }

  /**
   * @dev initializes the contract upon assignment to the InitializableAdminUpgradeabilityProxy
   */
  function initialize() external initializer {}

  /**
   * @dev implements the permit function as for https://github.com/ethereum/EIPs/blob/8a34d644aacf0f9f8f00815307fd7dd5da07655f/EIPS/eip-2612.md
   * @param owner the owner of the funds
   * @param spender the spender
   * @param value the amount
   * @param deadline the deadline timestamp, type(uint256).max for no deadline
   * @param v signature param
   * @param s signature param
   * @param r signature param
   */

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(owner != address(0), 'INVALID_OWNER');
    //solium-disable-next-line
    require(block.timestamp <= deadline, 'INVALID_EXPIRATION');
    uint256 currentValidNonce = _nonces[owner];
    bytes32 digest = keccak256(
      abi.encodePacked(
        '\x19\x01',
        DOMAIN_SEPARATOR,
        keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, currentValidNonce, deadline))
      )
    );

    require(owner == ecrecover(digest, v, r, s), 'INVALID_SIGNATURE');
    _nonces[owner] = currentValidNonce.add(1);
    _approve(owner, spender, value);
  }

  /**
   * @dev returns the revision of the implementation contract
   */
  function getRevision() internal override pure returns (uint256) {
    return REVISION;
  }

  /**
   * @dev Writes a snapshot before any operation involving transfer of value: _transfer, _mint and _burn
   * - On _transfer, it writes snapshots for both "from" and "to"
   * - On _mint, only for _to
   * - On _burn, only for _from
   * @param from the from address
   * @param to the to address
   * @param amount the amount to transfer
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    address votingFromDelegatee = _getDelegatee(from, _votingDelegates);
    address votingToDelegatee = _getDelegatee(to, _votingDelegates);

    _moveDelegatesByType(
      votingFromDelegatee,
      votingToDelegatee,
      amount,
      DelegationType.VOTING_POWER
    );

    address propPowerFromDelegatee = _getDelegatee(from, _propositionPowerDelegates);
    address propPowerToDelegatee = _getDelegatee(to, _propositionPowerDelegates);

    _moveDelegatesByType(
      propPowerFromDelegatee,
      propPowerToDelegatee,
      amount,
      DelegationType.PROPOSITION_POWER
    );

    // caching the monetaria governance address to avoid multiple state loads
    ITransferHook monetariaGovernance = _monetariaGovernance;
    if (monetariaGovernance != ITransferHook(address(0))) {
      monetariaGovernance.onTransfer(from, to, amount);
    }
  }

  function _getDelegationDataByType(DelegationType delegationType)
    internal
    override
    view
    returns (
      mapping(address => mapping(uint256 => Snapshot)) storage, //snapshots
      mapping(address => uint256) storage, //snapshots count
      mapping(address => address) storage //delegatees list
    )
  {
    if (delegationType == DelegationType.VOTING_POWER) {
      return (_votingSnapshots, _votingSnapshotsCounts, _votingDelegates);
    } else {
      return (
        _propositionPowerSnapshots,
        _propositionPowerSnapshotsCounts,
        _propositionPowerDelegates
      );
    }
  }

  /**
   * @dev Delegates power from signatory to `delegatee`
   * @param delegatee The address to delegate votes to
   * @param delegationType the type of delegation (VOTING_POWER, PROPOSITION_POWER)
   * @param nonce The contract state required to match the signature
   * @param expiry The time at which to expire the signature
   * @param v The recovery byte of the signature
   * @param r Half of the ECDSA signature pair
   * @param s Half of the ECDSA signature pair
   */
  function delegateByTypeBySig(
    address delegatee,
    DelegationType delegationType,
    uint256 nonce,
    uint256 expiry,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public {
    bytes32 structHash = keccak256(
      abi.encode(DELEGATE_BY_TYPE_TYPEHASH, delegatee, uint256(delegationType), nonce, expiry)
    );
    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', DOMAIN_SEPARATOR, structHash));
    address signatory = ecrecover(digest, v, r, s);
    require(signatory != address(0), 'INVALID_SIGNATURE');
    require(nonce == _nonces[signatory]++, 'INVALID_NONCE');
    require(block.timestamp <= expiry, 'INVALID_EXPIRATION');
    _delegateByType(signatory, delegatee, delegationType);
  }

  /**
   * @dev Delegates power from signatory to `delegatee`
   * @param delegatee The address to delegate votes to
   * @param nonce The contract state required to match the signature
   * @param expiry The time at which to expire the signature
   * @param v The recovery byte of the signature
   * @param r Half of the ECDSA signature pair
   * @param s Half of the ECDSA signature pair
   */
  function delegateBySig(
    address delegatee,
    uint256 nonce,
    uint256 expiry,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public {
    bytes32 structHash = keccak256(abi.encode(DELEGATE_TYPEHASH, delegatee, nonce, expiry));
    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', DOMAIN_SEPARATOR, structHash));
    address signatory = ecrecover(digest, v, r, s);
    require(signatory != address(0), 'INVALID_SIGNATURE');
    require(nonce == _nonces[signatory]++, 'INVALID_NONCE');
    require(block.timestamp <= expiry, 'INVALID_EXPIRATION');
    _delegateByType(signatory, delegatee, DelegationType.VOTING_POWER);
    _delegateByType(signatory, delegatee, DelegationType.PROPOSITION_POWER);
  }


  /**
   * @dev Update mining rate and supply at the start of the epoch 
          Any modifying mining call must also call this
   */
  function _update_mining_parameters() internal {
    uint256 _rate = rate;
    uint256 _start_epoch_supply = start_epoch_supply;

    start_epoch_time += RATE_REDUCTION_TIME;
    mining_epoch += 1;

    if (_rate == 0) {
      _rate = INITIAL_RATE;
    } else {
      _start_epoch_supply += _rate * RATE_REDUCTION_TIME;
      start_epoch_supply = _start_epoch_supply;
      _rate = _rate * RATE_DENOMINATOR / RATE_REDUCTION_COEFFICIENT;
    }
    rate = _rate;
  }

  /**
    @notice Update mining rate and supply at the start of the epoch
    @dev Callable by any address, but only once per epoch
         Total supply becomes slightly larger if this function is called late
   */
  function update_mining_parameters() external {
    require(block.timestamp >= start_epoch_time + RATE_REDUCTION_TIME); // dev: too soon!
    _update_mining_parameters();
  }

  /**
    @notice Get timestamp of the current mining epoch start
            while simultaneously updating mining parameters
    @return Timestamp of the epoch
   */
  function start_epoch_time_write() external returns (uint256) {
    uint256 _start_epoch_time = start_epoch_time;
    if (block.timestamp >= _start_epoch_time + RATE_REDUCTION_TIME){
      _update_mining_parameters();
      return start_epoch_time;
    } else {
      return _start_epoch_time;
    }
  }
  /**
    @notice Get timestamp of the next mining epoch start
            while simultaneously updating mining parameters
    @return Timestamp of the next epoch  
   */
  function future_epoch_time_write() external returns (uint256){
    uint256 _start_epoch_time = start_epoch_time;
    if (block.timestamp >= _start_epoch_time + RATE_REDUCTION_TIME){
      _update_mining_parameters();
      return start_epoch_time + RATE_REDUCTION_TIME;
    } else {
      return _start_epoch_time + RATE_REDUCTION_TIME;
    }
  }

  function _available_supply() internal view returns (uint256){
    return start_epoch_supply + (block.timestamp - start_epoch_time) * rate;
  }

  /**
    @notice Current number of tokens in existence (claimed or unclaimed)
   */
  function available_supply() external view returns (uint256){
    return _available_supply();
  }

  /**
    @notice How much supply is mintable from start timestamp till end timestamp
    @param start Start of the time interval (timestamp)
    @param end End of the time interval (timestamp)
    @return Tokens mintable from `start` till `end`
   */
  function mintable_in_timeframe(uint256 start, uint256 end) external view returns (uint256){
    require(start <= end);  // dev: start > end

    uint256 to_mint = 0;
    uint256 current_epoch_time = start_epoch_time;
    uint256 current_rate = rate;

    // Special case if end is in future (not yet minted) epoch
    if (end > current_epoch_time + RATE_REDUCTION_TIME) {
      current_epoch_time += RATE_REDUCTION_TIME;
      current_rate = current_rate * RATE_DENOMINATOR / RATE_REDUCTION_COEFFICIENT;
    }
    require(end <= current_epoch_time + RATE_REDUCTION_TIME);  // dev: too far in future

    for (uint i = 0; i < 999; i++) { // Monetaria will not work in 1000 years. Darn!
      if ( end >= current_epoch_time ) {
        uint256 current_end = end;
        if (current_end > current_epoch_time + RATE_REDUCTION_TIME) {
          current_end = current_epoch_time + RATE_REDUCTION_TIME;
        }

        uint256 current_start = start;
        if (current_start >= current_epoch_time + RATE_REDUCTION_TIME){
          break; // We should never get here but what if...
        } else if (current_start < current_epoch_time) {
          current_start = current_epoch_time;
        }

        to_mint += current_rate * (current_end - current_start);

        if (start >= current_epoch_time) {
          break;
        }
      }

      current_epoch_time -= RATE_REDUCTION_TIME;
      current_rate = current_rate * RATE_REDUCTION_COEFFICIENT / RATE_DENOMINATOR; // double-division with rounding made rate a bit less => good
      require(current_rate <= INITIAL_RATE); // This should never happen
    }
    return to_mint;
  }

  /**
    @notice Set the minter address
    @dev Only callable once, when minter has not yet been set
    @param _minter Address of the minter
   */
  function set_minter(address _minter) external {
    require(msg.sender == admin);  // dev: admin only
    require(minter == address(0)); // dev: can set the minter only once, at creation
    minter = _minter;
  }

  /**
    @notice Set the new admin.
    @dev After all is set up, admin only can change the token name
    @param _admin New admin address
   */
  function set_admin(address _admin) external {
    require(msg.sender == admin); // dev: admin only
    admin = _admin;
  }

  /**
    @notice Mint `_value` tokens and assign them to `_to`
    @dev Emits a Transfer event originating from 0x00
    @param _to The account that will receive the created tokens
    @param _value The amount that will be created
    @return bool success
   */
  function mint(address _to, uint256 _value) external returns (bool) {
    require(msg.sender == minter); //dev: minter only
    require(_to == address(0)); //dev: zero address

    if (block.timestamp >= start_epoch_time + RATE_REDUCTION_TIME){
      _update_mining_parameters();
    }

    require(totalSupply() <= _available_supply()); //dev: exceeds allowable mint amount

    _mint(_to, _value);

    return true;
  }
}
