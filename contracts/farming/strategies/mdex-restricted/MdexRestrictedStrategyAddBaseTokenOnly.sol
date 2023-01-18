// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../apis/mdex/IMdexFactory.sol";
import "../../apis/mdex/IMdexRouter.sol";
import "../../interfaces/IPancakePair.sol";
import "../../interfaces/IMdexSwapMining.sol";

import "../../interfaces/IStrategy.sol";
import "../../interfaces/IWorker.sol";

import "../../utils/SafeToken.sol";
import "../../utils/MyMath.sol";

contract MdexRestrictedStrategyAddBaseTokenOnly is OwnableUpgradeable, ReentrancyGuardUpgradeable, IStrategy {
  using SafeToken for address;
  using SafeMath for uint256;

  /// @notice Events
  event SetWorkerOk(address indexed caller, address worker, bool isOk);
  event WithdrawTradingRewards(address indexed caller, address to, uint256 amount);

  IMdexFactory public factory;
  IMdexRouter public router;
  address public mdx;
  mapping(address => bool) public okWorkers;

  /// @notice require that only allowed workers are able to do the rest of the method call
  modifier onlyWhitelistedWorkers() {
    require(okWorkers[msg.sender], "MdexRestrictedStrategyAddBaseTokenOnly::onlyWhitelistedWorkers:: bad worker");
    _;
  }

  /// @dev Create a new add Token only strategy instance.
  /// @param _router The WaultSwap Router smart contract.
  /// @param _mdx The address of mdex token.
  function initialize(IMdexRouter _router, address _mdx) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    factory = IMdexFactory(_router.factory());
    router = _router;
    mdx = _mdx;
  }

  /// @dev Execute worker strategy. Take BaseToken. Return LP tokens.
  /// @param data Extra calldata information passed along to this strategy.
  function execute(
    address, /* user */
    uint256, /* debt */
    bytes calldata data
  ) external override onlyWhitelistedWorkers nonReentrant {
    // 1. Find out what farming token we are dealing with and min additional LP tokens.
    uint256 minLPAmount = abi.decode(data, (uint256));
    IWorker worker = IWorker(msg.sender);
    address baseToken = worker.baseToken();
    address farmingToken = worker.farmingToken();
    IPancakePair lpToken = IPancakePair(factory.getPair(farmingToken, baseToken));
    // 2. Get trading fee of the pair from Mdex
    uint256 fee = factory.getPairFees(address(lpToken));
    // 3. Approve router to do their stuffs
    baseToken.safeApprove(address(router), type(uint256).max);
    farmingToken.safeApprove(address(router), type(uint256).max);
    // 4. Compute the optimal amount of baseToken to be converted to farmingToken.
    uint256 balance = baseToken.myBalance();
    (uint256 r0, uint256 r1, ) = lpToken.getReserves();
    uint256 rIn = lpToken.token0() == baseToken ? r0 : r1;
    // find how many baseToken need to be converted to farmingToken
    uint256 aIn = _calculateAIn(fee, rIn, balance);

    // 5. Convert that portion of baseToken to farmingToken.
    address[] memory path = new address[](2);
    path[0] = baseToken;
    path[1] = farmingToken;
    router.swapExactTokensForTokens(aIn, 0, path, address(this), block.timestamp);
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
    require(
      moreLPAmount >= minLPAmount,
      "MdexRestrictedStrategyAddBaseTokenOnly::execute:: insufficient LP tokens received"
    );
    address(lpToken).safeTransfer(msg.sender, lpToken.balanceOf(address(this)));
    // 7. Reset approval for safety reason
    baseToken.safeApprove(address(router), 0);
    farmingToken.safeApprove(address(router), 0);
  }

  function setWorkersOk(address[] calldata workers, bool isOk) external onlyOwner {
    for (uint256 idx = 0; idx < workers.length; idx++) {
      okWorkers[workers[idx]] = isOk;
      emit SetWorkerOk(msg.sender, workers[idx], isOk);
    }
  }

  /// @dev Formula for calculating one-sided optimal swap. Return the amount that needs to be swapped.
  /// @param fee trading fee of the pair.
  /// @param rIn reserve of baseToken in the pair.
  /// @param balance balance of baseToken from worker.
  function _calculateAIn(
    uint256 fee,
    uint256 rIn,
    uint256 balance
  ) internal pure returns (uint256) {
    uint256 feeDenom = 10000;
    uint256 feeConstantA = feeDenom.mul(2).sub(fee); // 2-f
    uint256 feeConstantB = feeDenom.sub(fee).mul(4).mul(feeDenom); // 4(1-f)
    uint256 feeConstantC = feeConstantA**2; // (2-f)^2
    uint256 nominator = MyMath.sqrt(rIn.mul(balance.mul(feeConstantB).add(rIn.mul(feeConstantC)))).sub(
      rIn.mul(feeConstantA)
    );
    uint256 denominator = feeDenom.sub(fee).mul(2); // 1-f
    return nominator / denominator;
  }

  /// @dev Withdraw trading all reward.
  /// @param to The address to transfer trading reward to.
  function withdrawTradingRewards(address to) external onlyOwner {
    uint256 mdxBalanceBefore = mdx.myBalance();
    IMdexSwapMining(router.swapMining()).takerWithdraw();
    uint256 mdxBalanceAfter = mdx.myBalance().sub(mdxBalanceBefore);
    mdx.safeTransfer(to, mdxBalanceAfter);
    emit WithdrawTradingRewards(msg.sender, to, mdxBalanceAfter);
  }

  /// @dev Get trading rewards by pIds.
  /// @param pIds pool ids to retrieve reward amount. [0, 1, 5, 4]
  function getMiningRewards(uint256[] calldata pIds) external view returns (uint256) {
    address swapMiningAddress = router.swapMining();
    uint256 totalReward;
    for (uint256 index = 0; index < pIds.length; index++) {
      (uint256 reward, ) = IMdexSwapMining(swapMiningAddress).getUserReward(pIds[index]);
      totalReward = totalReward.add(reward);
    }
    return totalReward;
  }
}
