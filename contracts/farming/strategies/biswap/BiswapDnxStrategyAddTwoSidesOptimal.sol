// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../../interfaces/ISwapFactoryLike.sol";
import "../../interfaces/IBiswapLiquidityPair.sol";
import "../../interfaces/IBiswapRouter02.sol";
import "../../interfaces/IStrategy.sol";
import "../../interfaces/IVault.sol";
import "../../interfaces/IWorker03.sol";

import "../../utils/SafeToken.sol";
import "../../utils/MyMath.sol";

contract BiswapDnxStrategyAddTwoSidesOptimal is OwnableUpgradeable, ReentrancyGuardUpgradeable, IStrategy {
  using SafeToken for address;
  using SafeMath for uint256;

  event LogSetWorkerOk(address[] indexed workers, bool isOk);

  ISwapFactoryLike public factory;
  IBiswapRouter02 public router;
  IVault public vault;

  mapping(address => bool) public okWorkers;

  /// @notice require that only allowed workers are able to do the rest of the method call
  modifier onlyWhitelistedWorkers() {
    require(okWorkers[msg.sender], "bad worker");
    _;
  }

  /// @dev Create a new add two-side optimal strategy instance.
  /// @param _router The WaultSwap Router smart contract.
  function initialize(IBiswapRouter02 _router, IVault _vault) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    factory = ISwapFactoryLike(_router.factory());
    router = _router;
    vault = _vault;
  }

  /// @dev Compute optimal deposit amount
  /// @param amtA amount of token A desired to deposit
  /// @param amtB amonut of token B desired to deposit
  /// @param resA amount of token A in reserve
  /// @param resB amount of token B in reserve
  function optimalDeposit(
    uint256 amtA,
    uint256 amtB,
    uint256 resA,
    uint256 resB,
    uint256 fee
  ) internal pure returns (uint256 swapAmt, bool isReversed) {
    if (amtA.mul(resB) >= amtB.mul(resA)) {
      swapAmt = _optimalDepositA(amtA, amtB, resA, resB, fee);
      isReversed = false;
    } else {
      swapAmt = _optimalDepositA(amtB, amtA, resB, resA, fee);
      isReversed = true;
    }
  }

  /// @dev Compute optimal deposit amount helper
  /// @param amtA amount of token A desired to deposit
  /// @param amtB amonut of token B desired to deposit
  /// @param resA amount of token A in reserve
  /// @param resB amount of token B in reserve
  function _optimalDepositA(
    uint256 amtA,
    uint256 amtB,
    uint256 resA,
    uint256 resB,
    uint256 fee
  ) internal pure returns (uint256) {
    require(amtA.mul(resB) >= amtB.mul(resA), "Reversed");
    // Biswap fee use 1000 fee denominator
    uint256 a = uint256(1000).sub(fee);
    uint256 b = uint256(2000).sub(fee).mul(resA);
    uint256 _c = (amtA.mul(resB)).sub(amtB.mul(resA));
    uint256 c = _c.mul(1000).div(amtB.add(resB)).mul(resA);

    uint256 d = a.mul(c).mul(4);
    uint256 e = MyMath.sqrt(b.mul(b).add(d));

    uint256 numerator = e.sub(b);
    uint256 denominator = a.mul(2);

    return numerator.div(denominator);
  }

  /// @dev Execute worker strategy. Take BaseToken + FarmingToken. Return LP tokens.
  /// @param data Extra calldata information passed along to this strategy.
  function execute(
    address, /* user */
    uint256,
    /* debt */
    bytes calldata data
  ) external override onlyWhitelistedWorkers nonReentrant {
    // 1. Find out what farming token we are dealing with.
    (uint256 farmingTokenAmount, uint256 minLPAmount) = abi.decode(data, (uint256, uint256));
    IWorker03 worker = IWorker03(msg.sender);
    address baseToken = worker.baseToken();
    address farmingToken = worker.farmingToken();
    IBiswapLiquidityPair lpToken = IBiswapLiquidityPair(address(worker.lpToken()));
    // 2. Approve router to do their stuffs
    baseToken.safeApprove(address(router), type(uint256).max);
    farmingToken.safeApprove(address(router), type(uint256).max);
    // 3. Compute the optimal amount of BaseToken and FarmingToken to be converted.
    vault.requestFunds(farmingToken, farmingTokenAmount);
    uint256 baseTokenBalance = baseToken.myBalance();
    uint256 swapAmt;
    bool isReversed;
    uint256 fee = lpToken.swapFee();
    {
      (uint256 r0, uint256 r1, ) = lpToken.getReserves();
      (uint256 baseTokenReserve, uint256 farmingTokenReserve) = lpToken.token0() == baseToken ? (r0, r1) : (r1, r0);
      (swapAmt, isReversed) = optimalDeposit(
        baseTokenBalance,
        farmingToken.myBalance(),
        baseTokenReserve,
        farmingTokenReserve,
        fee
      );
      // 4. Convert between BaseToken and farming tokens
      address[] memory path = new address[](2);
      (path[0], path[1]) = isReversed ? (farmingToken, baseToken) : (baseToken, farmingToken);
      // 5. Swap according to path
      if (swapAmt > 0) {
        (uint256 reserveIn, uint256 reserveOut) = isReversed
          ? (farmingTokenReserve, baseTokenReserve)
          : (baseTokenReserve, farmingTokenReserve);
        uint256 amountOut = router.getAmountOut(swapAmt, reserveIn, reserveOut, fee);
        if (amountOut > 0) router.swapExactTokensForTokens(swapAmt, 0, path, address(this), block.timestamp);
      }
    }

    // 6. Mint more LP tokens and return all LP tokens to the sender.
    (, , uint256 moreLPAmount) = router.addLiquidity(
      baseToken,
      farmingToken,
      baseToken.myBalance(),
      farmingToken.myBalance(),
      0,
      0,
      address(this),
      block.timestamp
    );
    require(moreLPAmount >= minLPAmount, "insufficient LP tokens received");
    address(lpToken).safeTransfer(msg.sender, lpToken.balanceOf(address(this)));
    // 7. Reset approve to 0 for safety reason
    farmingToken.safeApprove(address(router), 0);
    baseToken.safeApprove(address(router), 0);
  }

  function setWorkersOk(address[] calldata workers, bool isOk) external onlyOwner {
    for (uint256 idx = 0; idx < workers.length; idx++) {
      okWorkers[workers[idx]] = isOk;
    }
    emit LogSetWorkerOk(workers, isOk);
  }
}