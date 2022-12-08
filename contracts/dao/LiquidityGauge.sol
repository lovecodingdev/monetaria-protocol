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

import {MNTToken} from './MNTToken.sol';
import {VotingEscrow} from './VotingEscrow.sol';

interface VotingEscrowBoost{
  function adjusted_balance_of(address _account) external view returns(uint256);
}

interface Controller {
  function period() external view returns(int128);
  function period_write() external returns(int128);
  function period_timestamp(int128 p) external view returns(uint256);
  function gauge_relative_weight(address addr, uint256 time) external view returns(uint256);
  function voting_escrow() external view returns(address);
  function checkpoint() external;
  function checkpoint_gauge(address addr) external;
}

interface Minter{
  function token() external view returns(address);
  function controller() external view returns(address);
  function minted(address user, address gauge) external view returns(uint256);
}

/**
 * @title Liquidity Gauge
 * @author Monetaria
 * @notice Implementation of the Liquidity Gauge
 */
contract LiquidityGauge is EIP712 {
  using Address for address;

  event Deposit (
    address indexed provider,
    uint256 value
  );
  event Withdraw (
    address indexed provider,
    uint256 value
  );
  event UpdateLiquidityLimit (
    address user,
    uint256 original_balance,
    uint256 original_supply,
    uint256 working_balance,
    uint256 working_supply
  );
  event CommitOwnership (
    address admin
  );
  event ApplyOwnership (
    address admin
  );
  event Transfer (
    address indexed _from,
    address indexed _to,
    uint256 _value
  );
  event Approval(
    address indexed _owner, 
    address indexed _spender, 
    uint256 _value
  );
  struct Reward {
    address token;
    address distributor;
    uint256 period_finish;
    uint256 rate;
    uint256 last_update;
    uint256 integral;
  }

  // keccak256("isValidSignature(bytes32,bytes)")[:4] << 224
  bytes32 constant ERC1271_MAGIC_VAL = 0x1626ba7e00000000000000000000000000000000000000000000000000000000;
  bytes32 constant EIP712_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
  bytes32 constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
  string constant VERSION = "v1.0.0";

  uint256 constant MAX_REWARDS = 8;
  uint256 constant TOKENLESS_PRODUCTION = 40;
  uint256 constant WEEK = 604800;

  address constant MINTER = 0xd061D61a4d941c39E5453435B6345Dc261C2fcE0;
  address constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
  address constant VOTING_ESCROW = 0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2;
  address constant GAUGE_CONTROLLER = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB;
  address constant VEBOOST_PROXY = 0x8E0c00ed546602fD9927DF742bbAbF726D5B0d16;


  string private NAME;
  string private SYMBOL;
  bytes32 immutable _DOMAIN_SEPARATOR;

  address immutable LP_TOKEN;

  mapping(address => uint256) public nonces;

  uint256 public future_epoch_time;

  mapping(address => uint256) public balanceOf;
  uint256 public totalSupply;
  mapping(address => mapping(address => uint256)) allowance;

  mapping(address => uint256) working_balances;
  uint256 public working_supply;

  // For tracking external rewards
  uint256 public reward_count;
  address[MAX_REWARDS] public reward_tokens;

  mapping(address => Reward) public reward_data;

  // claimant -> default reward receiver
  mapping(address => address) public rewards_receiver;

  // reward token -> claiming address -> integral
  mapping(address => mapping(address => uint256)) public reward_integral_for;

  // user -> [uint128 claimable amount][uint128 claimed amount]
  mapping(address => mapping(address => uint256)) claim_data;

  address public admin;
  address public future_admin;
  bool public is_killed;

  // 1e18 * ∫(rate(t) / totalSupply(t) dt) from (last_action) till checkpoint
  mapping(address => uint256) public integrate_inv_supply_of;
  mapping(address => uint256) public integrate_checkpoint_of;

  // ∫(balance * rate(t) / totalSupply(t) dt) from 0 till checkpoint
  // Units: rate * t = already number of coins per address to issue
  mapping(address => uint256) public integrate_fraction;

  uint256 public inflation_rate;

  // The goal is to be able to calculate ∫(rate * balance / totalSupply dt) from 0 till checkpoint
  // All values are kept in units of being multiplied by 1e18
  int128 public period;
  uint256[100000000000000000000000000000] public period_timestamp;

  // 1e18 * ∫(rate(t) / totalSupply(t) dt) from 0 till checkpoint
  uint256[100000000000000000000000000000] integrate_inv_supply;  // bump epoch when rate() changes

  /**
    @notice Contract constructor
    @param _lp_token Liquidity Pool contract address
    @param _admin Admin who can kill the gauge
   */
  constructor(address _lp_token, address _admin) EIP712("Monetaria", "1") {
    admin = _admin;

    period_timestamp[0] = block.timestamp;
    inflation_rate = MNTToken(CRV).rate();
    future_epoch_time = MNTToken(CRV).future_epoch_time_write();

    string memory lp_symbol = ERC20(_lp_token).symbol();
    string memory name = string.concat("Curve.fi ", lp_symbol, " Gauge Deposit");

    NAME = name;
    SYMBOL = string.concat(lp_symbol, "-gauge");
    _DOMAIN_SEPARATOR = keccak256(
        abi.encode(EIP712_TYPEHASH, keccak256(bytes(name)), keccak256(bytes(VERSION)), block.chainid, address(this))
    );

    LP_TOKEN = _lp_token;
  }

  function integrate_checkpoint() external view returns(uint256){
    return period_timestamp[uint256(int256(period))];
  }

  /**
    @notice Calculate limits which depend on the amount of CRV token per-user.
            Effectively it calculates working balances to apply amplification
            of CRV production by CRV
    @param addr User address
    @param l User's amount of liquidity (LP tokens)
    @param L Total amount of liquidity (LP tokens)
   */
  function _update_liquidity_limit(address addr, uint256 l, uint256 L) internal {
    // To be called after totalSupply is updated
    uint256 voting_balance = VotingEscrowBoost(VEBOOST_PROXY).adjusted_balance_of(addr);
    uint256 voting_total = ERC20(VOTING_ESCROW).totalSupply();

    uint256 lim = l * TOKENLESS_PRODUCTION / 100;
    if (voting_total > 0) {
      lim += L * voting_balance / voting_total * (100 - TOKENLESS_PRODUCTION) / 100;
    }

    lim = l < lim ? l : lim;
    uint256 old_bal = working_balances[addr];
    working_balances[addr] = lim;
    uint256 _working_supply = working_supply + lim - old_bal;
    working_supply = _working_supply;

    emit UpdateLiquidityLimit(addr, l, L, lim, _working_supply);
  }

  /**
    @notice Claim pending rewards and checkpoint rewards for a user
   */
  function _checkpoint_rewards(address _user, uint256 _total_supply, bool _claim, address _receiver) internal {
    uint256 user_balance = 0;
    address receiver = _receiver;
    if (_user != address(0)){
      user_balance = balanceOf[_user];
      if (_claim && _receiver == address(0)) {
        // if receiver is not explicitly declared, check if a default receiver is set
        receiver = rewards_receiver[_user];
        if (receiver == address(0)) {
          // if no default receiver is set, direct claims to the user
          receiver = _user;
        }
      }
    }

    uint256 _reward_count = reward_count;
    for (uint i = 0; i < MAX_REWARDS; i++) {
      if (i == _reward_count){
        break;
      }
      address token = reward_tokens[i];

      uint256 integral = reward_data[token].integral;
      uint256 last_update = Math.min(block.timestamp, reward_data[token].period_finish);
      uint256 duration = last_update - reward_data[token].last_update;
      if (duration != 0) {
        reward_data[token].last_update = last_update;
        if (_total_supply != 0) {
          integral += duration * reward_data[token].rate * 10**18 / _total_supply;
          reward_data[token].integral = integral;
        }
      }

      if (_user != address(0)) {
        uint256 integral_for = reward_integral_for[token][_user];
        uint256 new_claimable = 0;

        if (integral_for < integral) {
          reward_integral_for[token][_user] = integral;
          new_claimable = user_balance * (integral - integral_for) / 10**18;
        }

        uint256 _claim_data = claim_data[_user][token];
        uint256 total_claimable = (_claim_data >> 128) + new_claimable; // shift(claim_data, -128)
        if (total_claimable > 0) {
          uint256 total_claimed = _claim_data % 2**128;
          if (_claim) {
            // response: Bytes[32] = raw_call(
            //     token,
            //     concat(
            //         method_id("transfer(address,uint256)"),
            //         convert(receiver, bytes32),
            //         convert(total_claimable, bytes32),
            //     ),
            //     max_outsize=32,
            // )
            // (bool success, bytes memory response) = token.call{value: msg.value}(
            //   abi.encodeWithSignature(
            //     "transfer(address,uint256)", 
            //     receiver, 
            //     total_claimable
            //   )
            // );
            // if (success) {
            //   require(response.length > 0);
            // }
            require(ERC20(token).transfer(receiver, total_claimable));

            claim_data[_user][token] = total_claimed + total_claimable;
          }else if (new_claimable > 0) {
            claim_data[_user][token] = total_claimed + (total_claimable << 128);
          }
        }
      }
    }
  }

  /**
    @notice Checkpoint for a user
    @param addr User address  
   */
  function _checkpoint(address addr) internal {
    int128 _period = period;
    uint256 _period_time = period_timestamp[uint256(int256(_period))];
    uint256 _integrate_inv_supply = integrate_inv_supply[uint256(int256(_period))];
    uint256 rate = inflation_rate;
    uint256 new_rate = rate;
    uint256 prev_future_epoch = future_epoch_time;
    if (prev_future_epoch >= _period_time) {
      future_epoch_time = MNTToken(CRV).future_epoch_time_write();
      new_rate = MNTToken(CRV).rate();
      inflation_rate = new_rate;
    }

    if (is_killed) {
      // Stop distributing inflation as soon as killed
      rate = 0;
    }

    // Update integral of 1/supply
    if (block.timestamp > _period_time) {
      uint256 _working_supply = working_supply;
      Controller(GAUGE_CONTROLLER).checkpoint_gauge(address(this));
      uint256 prev_week_time = _period_time;
      uint256 week_time = Math.min((_period_time + WEEK) / WEEK * WEEK, block.timestamp);

      for(int i = 0; i < 500; i ++){
        uint256 dt = week_time - prev_week_time;
        uint256 w = Controller(GAUGE_CONTROLLER).gauge_relative_weight(address(this), prev_week_time / WEEK * WEEK);

        if (_working_supply > 0) {
          if (prev_future_epoch >= prev_week_time && prev_future_epoch < week_time){
            // If we went across one or multiple epochs, apply the rate
            // of the first epoch until it ends, and then the rate of
            // the last epoch.
            // If more than one epoch is crossed - the gauge gets less,
            // but that'd meen it wasn't called for more than 1 year
            _integrate_inv_supply += rate * w * (prev_future_epoch - prev_week_time) / _working_supply;
            rate = new_rate;
            _integrate_inv_supply += rate * w * (week_time - prev_future_epoch) / _working_supply;
          }else{
            _integrate_inv_supply += rate * w * dt / _working_supply;
          }
          // On precisions of the calculation
          // rate ~= 10e18
          // last_weight > 0.01 * 1e18 = 1e16 (if pool weight is 1%)
          // _working_supply ~= TVL * 1e18 ~= 1e26 ($100M for example)
          // The largest loss is at dt = 1
          // Loss is 1e-9 - acceptable
        }
        if (week_time == block.timestamp) {
          break;
        }
        prev_week_time = week_time;
        week_time = Math.min(week_time + WEEK, block.timestamp);
      }
    }

    _period += 1;
    period = _period;
    period_timestamp[uint256(int256(_period))] = block.timestamp;
    integrate_inv_supply[uint256(int256(_period))] = _integrate_inv_supply;

    // Update user-specific integrals
    uint256 _working_balance = working_balances[addr];
    integrate_fraction[addr] += _working_balance * (_integrate_inv_supply - integrate_inv_supply_of[addr]) / 10 ** 18;
    integrate_inv_supply_of[addr] = _integrate_inv_supply;
    integrate_checkpoint_of[addr] = block.timestamp;
  }

  /**
    @notice Record a checkpoint for `addr`
    @param addr User address
    @return bool success
   */
  function user_checkpoint(address addr) external returns(bool) {
    require(msg.sender == addr || msg.sender == MINTER); // dev: unauthorized
    _checkpoint(addr);
    _update_liquidity_limit(addr, balanceOf[addr], totalSupply);
    return true;
  }

  /**
    @notice Get the number of claimable tokens per user
    @dev This function should be manually changed to "view" in the ABI
    @return uint256 number of claimable tokens per user
   */
  function claimable_tokens(address addr) external returns(uint256){
    _checkpoint(addr);
    return integrate_fraction[addr] - Minter(MINTER).minted(addr, address(this));
  }

  /**
    @notice Get the number of already-claimed reward tokens for a user
    @param _addr Account to get reward amount for
    @param _token Token to get reward amount for
    @return uint256 Total amount of `_token` already claimed by `_addr`
   */
  function claimed_reward(address _addr, address _token) external view returns(uint256){
    return claim_data[_addr][_token] % 2**128;
  }

  /**
    @notice Get the number of claimable reward tokens for a user
    @param _user Account to get reward amount for
    @param _reward_token Token to get reward amount for
    @return uint256 Claimable reward token amount
   */
  function claimable_reward(address _user, address _reward_token) external view returns(uint256){
    uint256 integral = reward_data[_reward_token].integral;
    uint256 total_supply = totalSupply;
    if (total_supply != 0) {
      uint256 last_update = Math.min(block.timestamp, reward_data[_reward_token].period_finish);
      uint256 duration = last_update - reward_data[_reward_token].last_update;
      integral += (duration * reward_data[_reward_token].rate * 10**18 / total_supply);
    }

    uint256 integral_for = reward_integral_for[_reward_token][_user];
    uint256 new_claimable = balanceOf[_user] * (integral - integral_for) / 10**18;

    return (claim_data[_user][_reward_token] >> 128) + new_claimable;
  }

  /**
    @notice Set the default reward receiver for the caller.
    @dev When set to ZERO_ADDRESS, rewards are sent to the caller
    @param _receiver Receiver address for any rewards claimed via `claim_rewards`
   */
  function set_rewards_receiver(address _receiver) external {
    rewards_receiver[msg.sender] = _receiver;
  }

  /**
    @notice Claim available reward tokens for `_addr`
    @param _addr Address to claim for
    @param _receiver Address to transfer rewards to - if set to
                     ZERO_ADDRESS, uses the default reward receiver
                     for the caller
   */
  // @nonreentrant('lock')  
  function _claim_rewards(address _addr, address _receiver ) private {
    if (_receiver != address(0)) {
      require(_addr == msg.sender); // dev: cannot redirect when claiming for another user
    }
    _checkpoint_rewards(_addr, totalSupply, true, _receiver);
  }

  function claim_rewards() external {
    _claim_rewards(msg.sender, address(0));
  }

  function claim_rewards(address _addr) external {
    _claim_rewards(_addr, address(0));
  }

  function claim_rewards(address _addr, address _receiver) external {
    _claim_rewards(_addr, _receiver);
  }

  /**
    @notice Kick `addr` for abusing their boost
    @dev Only if either they had another voting event, or their voting escrow lock expired
    @param addr Address to kick
   */
  function kick(address addr) external {
    uint256 t_last = integrate_checkpoint_of[addr];
    uint256 t_ve = VotingEscrow(VOTING_ESCROW).user_point_history__ts(
      addr, VotingEscrow(VOTING_ESCROW).user_point_epoch(addr)
    );
    uint256 _balance = balanceOf[addr];

    require(ERC20(VOTING_ESCROW).balanceOf(addr) == 0 || t_ve > t_last); // dev: kick not allowed
    require(working_balances[addr] > _balance * TOKENLESS_PRODUCTION / 100); // dev: kick not needed

    _checkpoint(addr);
    _update_liquidity_limit(addr, balanceOf[addr], totalSupply);
  }

  /**
    @notice Deposit `_value` LP tokens
    @dev Depositting also claims pending reward tokens
    @param _value Number of tokens to deposit
    @param _addr Address to deposit for
   */
  // @nonreentrant('lock')
  function _deposit(uint256 _value, address _addr, bool _claim_rewards_) private {
    _checkpoint(_addr);

    if (_value != 0) {
      bool is_rewards = reward_count != 0;
      uint256 total_supply = totalSupply;
      if (is_rewards) {
        _checkpoint_rewards(_addr, total_supply, _claim_rewards_, address(0));
      }

      total_supply += _value;
      uint256 new_balance = balanceOf[_addr] + _value;
      balanceOf[_addr] = new_balance;
      totalSupply = total_supply;

      _update_liquidity_limit(_addr, new_balance, total_supply);

      ERC20(LP_TOKEN).transferFrom(msg.sender, address(this), _value);
    }

    emit Deposit(_addr, _value);
    emit Transfer(address(0), _addr, _value);
  }

  function deposit(uint256 _value) external {
    _deposit(_value, msg.sender, false);
  }

  function deposit(uint256 _value, address _addr) external {
    _deposit(_value, _addr, false);
  }

  function deposit(uint256 _value, address _addr, bool _claim_rewards_) external {
    _deposit(_value, _addr, _claim_rewards_);
  }

  /**
    @notice Withdraw `_value` LP tokens
    @dev Withdrawing also claims pending reward tokens
    @param _value Number of tokens to withdraw
   */
  // @nonreentrant('lock')
  function _withdraw(uint256 _value, bool _claim_rewards_) private {
    _checkpoint(msg.sender);

    if (_value != 0) {
      bool is_rewards = reward_count != 0;
      uint256 total_supply = totalSupply;
      if (is_rewards) {
        _checkpoint_rewards(msg.sender, total_supply, _claim_rewards_, address(0));
      }

      total_supply -= _value;
      uint256 new_balance = balanceOf[msg.sender] - _value;
      balanceOf[msg.sender] = new_balance;
      totalSupply = total_supply;

      _update_liquidity_limit(msg.sender, new_balance, total_supply);

      ERC20(LP_TOKEN).transfer(msg.sender, _value);
    }

    emit Withdraw(msg.sender, _value);
    emit Transfer(msg.sender, address(0), _value);
  }

  function withdraw(uint256 _value) external {
    _withdraw(_value, false);
  }

  function withdraw(uint256 _value, bool _claim_rewards_) external {
    _withdraw(_value, _claim_rewards_);
  }

  function _transfer(address _from, address _to, uint256 _value) internal {
    _checkpoint(_from);
    _checkpoint(_to);

    if (_value != 0) {
      uint256 total_supply = totalSupply;
      bool is_rewards = reward_count != 0;
      if (is_rewards) {
        _checkpoint_rewards(_from, total_supply, false, address(0));
      }
      uint256 new_balance = balanceOf[_from] - _value;
      balanceOf[_from] = new_balance;
      _update_liquidity_limit(_from, new_balance, total_supply);

      if (is_rewards) {
        _checkpoint_rewards(_to, total_supply, false, address(0));
      }
      new_balance = balanceOf[_to] + _value;
      balanceOf[_to] = new_balance;
      _update_liquidity_limit(_to, new_balance, total_supply);
    }

    emit Transfer(_from, _to, _value);
  }

  /**
    @notice Transfer token for a specified address
    @dev Transferring claims pending reward tokens for the sender and receiver
    @param _to The address to transfer to.
    @param _value The amount to be transferred.
   */
  // @nonreentrant('lock')
  function transfer(address _to, uint256 _value) external returns(bool) {
    _transfer(msg.sender, _to, _value);

    return true;
  }

  /**
    @notice Transfer tokens from one address to another.
    @dev Transferring claims pending reward tokens for the sender and receiver
    @param _from address The address which you want to send tokens from
    @param _to address The address which you want to transfer to
    @param _value uint256 the amount of tokens to be transferred
   */
  // @nonreentrant('lock')
  function transferFrom(address _from, address _to, uint256 _value) external returns(bool) {
    uint256 _allowance = allowance[_from][msg.sender];
    if (_allowance != type(uint256).max) {
      allowance[_from][msg.sender] = _allowance - _value;
    }

    _transfer(_from, _to, _value);

    return true;
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

  /**
    @notice Approve the passed address to transfer the specified amount of
            tokens on behalf of msg.sender
    @dev Beware that changing an allowance via this method brings the risk
         that someone may use both the old and new allowance by unfortunate
         transaction ordering. This may be mitigated with the use of
         {incraseAllowance} and {decreaseAllowance}.
         https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    @param _spender The address which will transfer the funds
    @param _value The amount of tokens that may be transferred
    @return bool success
   */  
  function approve(address _spender, uint256 _value) external returns(bool) {
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

  /**
    @notice Set the active reward contract
   */
  function add_reward(address _reward_token, address _distributor) external {
    require(msg.sender == admin); // dev: only owner

    uint256 reward_count = reward_count;
    require(reward_count < MAX_REWARDS);
    require(reward_data[_reward_token].distributor == address(0));

    reward_data[_reward_token].distributor = _distributor;
    reward_tokens[reward_count] = _reward_token;
    reward_count = reward_count + 1;
  }


  function set_reward_distributor(address _reward_token, address _distributor) external {
    address current_distributor = reward_data[_reward_token].distributor;

    require(msg.sender == current_distributor || msg.sender == admin);
    require(current_distributor != address(0));
    require(_distributor != address(0));

    reward_data[_reward_token].distributor = _distributor;
  }

  // @nonreentrant("lock")
  function deposit_reward_token(address _reward_token, uint256 _amount) external payable {
    require(msg.sender == reward_data[_reward_token].distributor);

    _checkpoint_rewards(address(0), totalSupply, false, address(0));

    // (bool success, bytes memory response)  = _reward_token.call{value: msg.value}(
    //   abi.encodeWithSignature(
    //     "transferFrom(address,address,uint256)", 
    //     msg.sender,
    //     address(this),
    //     _amount
    //   )
    // );
    // if (success) {
    //   require(response.length > 0);
    // }
    require(ERC20(_reward_token).transferFrom(msg.sender, address(this), _amount));

    uint256 period_finish = reward_data[_reward_token].period_finish;
    if (block.timestamp >= period_finish) {
      reward_data[_reward_token].rate = _amount / WEEK;
    }else{
      uint256 remaining = period_finish - block.timestamp;
      uint256 leftover = remaining * reward_data[_reward_token].rate;
      reward_data[_reward_token].rate = (_amount + leftover) / WEEK;
    }

    reward_data[_reward_token].last_update = block.timestamp;
    reward_data[_reward_token].period_finish = block.timestamp + WEEK;
  }

  /**
    @notice Set the killed status for this contract
    @dev When killed, the gauge always yields a rate of 0 and so cannot mint CRV
    @param _is_killed Killed status to set
   */
  function set_killed(bool _is_killed) external {
    require(msg.sender == admin);

    is_killed = _is_killed;
  }


  /**
    @notice Transfer ownership of GaugeController to `addr`
    @param addr Address to have ownership transferred to
   */
  function commit_transfer_ownership(address addr) external {
    require (msg.sender == admin); // dev: admin only

    future_admin = addr;
    emit CommitOwnership(addr);
  }

  /**
    @notice Accept a pending ownership transfer
   */
  function accept_transfer_ownership() external {
    address _admin = future_admin;
    require(msg.sender == _admin); // dev: future admin only

    admin = _admin;
    emit ApplyOwnership(_admin);
  }

  /**
    @notice Get the name for this gauge token
   */
  function name() external view returns(string memory){
    return NAME;
  }

  /**
    @notice Get the symbol for this gauge token
   */
  function symbol() external view returns(string memory){
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
    @notice Query the lp token used for this gauge
   */
  function lp_token() external view returns(address) {
    return LP_TOKEN;
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
}