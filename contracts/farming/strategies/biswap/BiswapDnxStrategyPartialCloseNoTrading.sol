// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../interfaces/ISwapFactoryLike.sol";
import "../../interfaces/IBiswapLiquidityPair.sol";
import "../../interfaces/IBiswapRouter02.sol";

import "../../interfaces/IStrategy.sol";
import "../../interfaces/IWorker.sol";

import "../../utils/SafeToken.sol";

contract BiswapDnxStrategyPartialCloseNoTrading is OwnableUpgradeable, ReentrancyGuardUpgradeable, IStrategy {
  using SafeToken for address;
  using SafeMath for uint256;

  ISwapFactoryLike public factory;
  IBiswapRouter02 public router;

  mapping(address => bool) public okWorkers;
  mapping(address => bool) public okDeltaNeutralVaults;

  event BiswapDnxStrategyStrategyPartialCloseNoTradingEvent(
    address indexed baseToken,
    address indexed farmToken,
    uint256 amounToLiquidate
  );

  /// @notice require that only allowed workers are able to do the rest of the method call
  modifier onlyWhitelistedWorkers() {
    require(okWorkers[msg.sender], "bad worker");
    _;
  }

  /// @dev Create a new withdraw minimize trading strategy instance.
  /// @param _router The Biswap Router smart contract.
  function initialize(IBiswapRouter02 _router) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    factory = ISwapFactoryLike(_router.factory());
    router = _router;
  }

  /// @dev Execute worker strategy. Take LP tokens. Return farming token + base token.
  /// However, some base token will be deducted to pay the debt
  /// @param data Extra calldata information passed along to this strategy.
  function execute(
    address, /*user*/
    uint256, /*debt*/
    bytes calldata data
  ) external override onlyWhitelistedWorkers nonReentrant {
    // 1. Decode variables from extra data & load required variables.
    (uint256 maxLpTokenToLiquidate, address _deltaNeutralVault) = abi.decode(data, (uint256, address));
    require(okDeltaNeutralVaults[_deltaNeutralVault], "bad target");

    IWorker worker = IWorker(msg.sender);
    address baseToken = worker.baseToken();
    address farmingToken = worker.farmingToken();
    IBiswapLiquidityPair lpToken = IBiswapLiquidityPair(factory.getPair(farmingToken, baseToken));
    uint256 lpTokenToLiquidate = Math.min(address(lpToken).myBalance(), maxLpTokenToLiquidate);
    // 2. Approve router to do their stuffs.
    address(lpToken).safeApprove(address(router), type(uint256).max);

    // 3. Remove all liquidity back to base token and farming token.
    router.removeLiquidity(baseToken, farmingToken, lpTokenToLiquidate, 0, 0, address(this), block.timestamp);

    // 4. Return remaining LP token back to the original caller.
    if (lpToken.balanceOf(address(this)) > 0) {
      address(lpToken).safeTransfer(msg.sender, lpToken.balanceOf(address(this)));
    }

    // 5. Return base token back to the delta neutral vault.
    baseToken.safeTransfer(_deltaNeutralVault, baseToken.myBalance());

    // 6. Return farming token back to the delta neutral vault.
    farmingToken.safeTransfer(_deltaNeutralVault, farmingToken.myBalance());

    // 7. Reset approval for safety reason.
    address(lpToken).safeApprove(address(router), 0);

    emit BiswapDnxStrategyStrategyPartialCloseNoTradingEvent(baseToken, farmingToken, lpTokenToLiquidate);
  }

  function setWorkersOk(address[] calldata workers, bool isOk) external onlyOwner {
    uint256 length = workers.length;
    for (uint256 idx = 0; idx < length; idx++) {
      okWorkers[workers[idx]] = isOk;
    }
  }

  function setDeltaNeutralVaultsOk(address[] calldata deltaNeutralVaults, bool isOk) external onlyOwner {
    uint256 length = deltaNeutralVaults.length;
    for (uint256 idx = 0; idx < length; idx++) {
      okDeltaNeutralVaults[deltaNeutralVaults[idx]] = isOk;
    }
  }
}
