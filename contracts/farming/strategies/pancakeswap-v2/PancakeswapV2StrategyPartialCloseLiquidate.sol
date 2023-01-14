// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../../interfaces/IPancakeFactory.sol";
import "../../interfaces/IPancakePair.sol";

import "../../apis/pancake/IPancakeRouter02.sol";
import "../../interfaces/IStrategy.sol";
import "../../utils/SafeToken.sol";

contract PancakeswapV2StrategyPartialCloseLiquidate is ReentrancyGuardUpgradeable, IStrategy {
  using SafeToken for address;

  IPancakeFactory public factory;
  IPancakeRouter02 public router;

  /// @dev Create a new liquidate strategy instance.
  /// @param _router The PancakeSwap Router smart contract.
  function initialize(IPancakeRouter02 _router) public initializer {
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    factory = IPancakeFactory(_router.factory());
    router = _router;
  }

  /// @dev Execute worker strategy. Take LP token. Return  BaseToken.
  /// @param data Extra calldata information passed along to this strategy.
  function execute(
    address, /* user */
    uint256, /* debt */
    bytes calldata data
  ) external override nonReentrant {
    // 1. Find out what farming token we are dealing with.
    (address baseToken, address farmingToken, uint256 returnLpToken, uint256 minBaseToken) = abi.decode(
      data,
      (address, address, uint256, uint256)
    );
    IPancakePair lpToken = IPancakePair(factory.getPair(farmingToken, baseToken));
    require(
      lpToken.balanceOf(address(this)) >= returnLpToken,
      "PancakeswapV2StrategyPartialCloseLiquidate::execute:: insufficient LP amount recevied from worker"
    );
    // 2. Approve router to do their stuffs
    address(lpToken).safeApprove(address(router), type(uint256).max);
    farmingToken.safeApprove(address(router), type(uint256).max);
    // 3. Remove some LP back to BaseToken and farming tokens as we want to return some of the position.
    router.removeLiquidity(baseToken, farmingToken, returnLpToken, 0, 0, address(this), block.timestamp);
    // 4. Convert farming tokens to baseToken.
    address[] memory path = new address[](2);
    path[0] = farmingToken;
    path[1] = baseToken;
    router.swapExactTokensForTokens(farmingToken.myBalance(), 0, path, address(this), block.timestamp);
    // 5. Return all baseToken back to the original caller.
    uint256 balance = baseToken.myBalance();
    require(
      balance >= minBaseToken,
      "PancakeswapV2StrategyPartialCloseLiquidate::execute:: insufficient baseToken received"
    );
    SafeToken.safeTransfer(baseToken, msg.sender, balance);
    address(lpToken).safeTransfer(msg.sender, lpToken.balanceOf(address(this)));
    // 6. Reset approve for safety reason
    address(lpToken).safeApprove(address(router), 0);
    farmingToken.safeApprove(address(router), 0);
  }
}
