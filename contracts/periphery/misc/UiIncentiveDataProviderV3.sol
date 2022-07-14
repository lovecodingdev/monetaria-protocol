// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {IPoolAddressesProvider} from '../../interfaces/IPoolAddressesProvider.sol';
import {IRewardsController} from '../rewards/interfaces/IRewardsController.sol';
import {IUiIncentiveDataProviderV3} from './interfaces/IUiIncentiveDataProviderV3.sol';
import {IPool} from '../../interfaces/IPool.sol';
import {IncentivizedERC20} from '../../protocol/token/base/IncentivizedERC20.sol';
import {UserConfig} from '../../protocol/libs/config/UserConfig.sol';
import {DataTypes} from '../../protocol/libs/types/DataTypes.sol';
import {IERC20Detailed} from '../../interfaces/IERC20Detailed.sol';
import {IEACAggregatorProxy} from './interfaces/IEACAggregatorProxy.sol';

contract UiIncentiveDataProviderV3 is IUiIncentiveDataProviderV3 {
  using UserConfig for DataTypes.UserConfigMap;

  constructor() {}

  function getFullReservesIncentiveData(IPoolAddressesProvider provider, address user)
    external
    view
    override
    returns (AggregatedReserveIncentiveData[] memory, UserReserveIncentiveData[] memory)
  {
    return (_getReservesIncentivesData(provider), _getUserReservesIncentivesData(provider, user));
  }

  function getReservesIncentivesData(IPoolAddressesProvider provider)
    external
    view
    override
    returns (AggregatedReserveIncentiveData[] memory)
  {
    return _getReservesIncentivesData(provider);
  }

  function _getReservesIncentivesData(IPoolAddressesProvider provider)
    private
    view
    returns (AggregatedReserveIncentiveData[] memory)
  {
    IPool pool = IPool(provider.getPool());
    address[] memory reserves = pool.getReservesList();
    AggregatedReserveIncentiveData[]
      memory reservesIncentiveData = new AggregatedReserveIncentiveData[](reserves.length);
    // Iterate through the reserves to get all the information from the (a/s/v) Tokens
    for (uint256 i = 0; i < reserves.length; i++) {
      AggregatedReserveIncentiveData memory reserveIncentiveData = reservesIncentiveData[i];
      reserveIncentiveData.underlyingAsset = reserves[i];

      DataTypes.ReserveData memory baseData = pool.getReserveData(reserves[i]);

      // Get mTokens rewards information
      // TODO: check that this is deployed correctly on contract and remove casting
      IRewardsController mTokenIncentiveController = IRewardsController(
        address(IncentivizedERC20(baseData.mTokenAddress).getIncentivesController())
      );
      RewardInfo[] memory aRewardsInformation;
      if (address(mTokenIncentiveController) != address(0)) {
        address[] memory mTokenRewardAddresses = mTokenIncentiveController.getRewardsByAsset(
          baseData.mTokenAddress
        );

        aRewardsInformation = new RewardInfo[](mTokenRewardAddresses.length);
        for (uint256 j = 0; j < mTokenRewardAddresses.length; ++j) {
          RewardInfo memory rewardInformation;
          rewardInformation.rewardTokenAddress = mTokenRewardAddresses[j];

          (
            rewardInformation.tokenIncentivesIndex,
            rewardInformation.emissionPerSecond,
            rewardInformation.incentivesLastUpdateTimestamp,
            rewardInformation.emissionEndTimestamp
          ) = mTokenIncentiveController.getRewardsData(
            baseData.mTokenAddress,
            rewardInformation.rewardTokenAddress
          );

          rewardInformation.precision = mTokenIncentiveController.getAssetDecimals(
            baseData.mTokenAddress
          );
          rewardInformation.rewardTokenDecimals = IERC20Detailed(
            rewardInformation.rewardTokenAddress
          ).decimals();
          rewardInformation.rewardTokenSymbol = IERC20Detailed(rewardInformation.rewardTokenAddress)
            .symbol();

          // Get price of reward token from Chainlink Proxy Oracle
          rewardInformation.rewardOracleAddress = mTokenIncentiveController.getRewardOracle(
            rewardInformation.rewardTokenAddress
          );
          rewardInformation.priceFeedDecimals = IEACAggregatorProxy(
            rewardInformation.rewardOracleAddress
          ).decimals();
          rewardInformation.rewardPriceFeed = IEACAggregatorProxy(
            rewardInformation.rewardOracleAddress
          ).latestAnswer();

          aRewardsInformation[j] = rewardInformation;
        }
      }

      reserveIncentiveData.aIncentiveData = IncentiveData(
        baseData.mTokenAddress,
        address(mTokenIncentiveController),
        aRewardsInformation
      );

      // Get vTokens rewards information
      IRewardsController vTokenIncentiveController = IRewardsController(
        address(IncentivizedERC20(baseData.variableDebtTokenAddress).getIncentivesController())
      );
      address[] memory vTokenRewardAddresses = vTokenIncentiveController.getRewardsByAsset(
        baseData.variableDebtTokenAddress
      );
      RewardInfo[] memory vRewardsInformation;

      if (address(vTokenIncentiveController) != address(0)) {
        vRewardsInformation = new RewardInfo[](vTokenRewardAddresses.length);
        for (uint256 j = 0; j < vTokenRewardAddresses.length; ++j) {
          RewardInfo memory rewardInformation;
          rewardInformation.rewardTokenAddress = vTokenRewardAddresses[j];

          (
            rewardInformation.tokenIncentivesIndex,
            rewardInformation.emissionPerSecond,
            rewardInformation.incentivesLastUpdateTimestamp,
            rewardInformation.emissionEndTimestamp
          ) = vTokenIncentiveController.getRewardsData(
            baseData.variableDebtTokenAddress,
            rewardInformation.rewardTokenAddress
          );

          rewardInformation.precision = vTokenIncentiveController.getAssetDecimals(
            baseData.variableDebtTokenAddress
          );
          rewardInformation.rewardTokenDecimals = IERC20Detailed(
            rewardInformation.rewardTokenAddress
          ).decimals();
          rewardInformation.rewardTokenSymbol = IERC20Detailed(rewardInformation.rewardTokenAddress)
            .symbol();

          // Get price of reward token from Chainlink Proxy Oracle
          rewardInformation.rewardOracleAddress = vTokenIncentiveController.getRewardOracle(
            rewardInformation.rewardTokenAddress
          );
          rewardInformation.priceFeedDecimals = IEACAggregatorProxy(
            rewardInformation.rewardOracleAddress
          ).decimals();
          rewardInformation.rewardPriceFeed = IEACAggregatorProxy(
            rewardInformation.rewardOracleAddress
          ).latestAnswer();

          vRewardsInformation[j] = rewardInformation;
        }
      }

      reserveIncentiveData.vIncentiveData = IncentiveData(
        baseData.variableDebtTokenAddress,
        address(vTokenIncentiveController),
        vRewardsInformation
      );

      // Get sTokens rewards information
      IRewardsController sTokenIncentiveController = IRewardsController(
        address(IncentivizedERC20(baseData.stableDebtTokenAddress).getIncentivesController())
      );
      address[] memory sTokenRewardAddresses = sTokenIncentiveController.getRewardsByAsset(
        baseData.stableDebtTokenAddress
      );
      RewardInfo[] memory sRewardsInformation;

      if (address(sTokenIncentiveController) != address(0)) {
        sRewardsInformation = new RewardInfo[](sTokenRewardAddresses.length);
        for (uint256 j = 0; j < sTokenRewardAddresses.length; ++j) {
          RewardInfo memory rewardInformation;
          rewardInformation.rewardTokenAddress = sTokenRewardAddresses[j];

          (
            rewardInformation.tokenIncentivesIndex,
            rewardInformation.emissionPerSecond,
            rewardInformation.incentivesLastUpdateTimestamp,
            rewardInformation.emissionEndTimestamp
          ) = sTokenIncentiveController.getRewardsData(
            baseData.stableDebtTokenAddress,
            rewardInformation.rewardTokenAddress
          );

          rewardInformation.precision = sTokenIncentiveController.getAssetDecimals(
            baseData.stableDebtTokenAddress
          );
          rewardInformation.rewardTokenDecimals = IERC20Detailed(
            rewardInformation.rewardTokenAddress
          ).decimals();
          rewardInformation.rewardTokenSymbol = IERC20Detailed(rewardInformation.rewardTokenAddress)
            .symbol();

          // Get price of reward token from Chainlink Proxy Oracle
          rewardInformation.rewardOracleAddress = sTokenIncentiveController.getRewardOracle(
            rewardInformation.rewardTokenAddress
          );
          rewardInformation.priceFeedDecimals = IEACAggregatorProxy(
            rewardInformation.rewardOracleAddress
          ).decimals();
          rewardInformation.rewardPriceFeed = IEACAggregatorProxy(
            rewardInformation.rewardOracleAddress
          ).latestAnswer();

          sRewardsInformation[j] = rewardInformation;
        }
      }

      reserveIncentiveData.sIncentiveData = IncentiveData(
        baseData.stableDebtTokenAddress,
        address(sTokenIncentiveController),
        sRewardsInformation
      );
    }

    return (reservesIncentiveData);
  }

  function getUserReservesIncentivesData(IPoolAddressesProvider provider, address user)
    external
    view
    override
    returns (UserReserveIncentiveData[] memory)
  {
    return _getUserReservesIncentivesData(provider, user);
  }

  function _getUserReservesIncentivesData(IPoolAddressesProvider provider, address user)
    private
    view
    returns (UserReserveIncentiveData[] memory)
  {
    IPool pool = IPool(provider.getPool());
    address[] memory reserves = pool.getReservesList();

    UserReserveIncentiveData[] memory userReservesIncentivesData = new UserReserveIncentiveData[](
      user != address(0) ? reserves.length : 0
    );

    for (uint256 i = 0; i < reserves.length; i++) {
      DataTypes.ReserveData memory baseData = pool.getReserveData(reserves[i]);

      // user reserve data
      userReservesIncentivesData[i].underlyingAsset = reserves[i];

      IRewardsController mTokenIncentiveController = IRewardsController(
        address(IncentivizedERC20(baseData.mTokenAddress).getIncentivesController())
      );
      if (address(mTokenIncentiveController) != address(0)) {
        // get all rewards information from the asset
        address[] memory mTokenRewardAddresses = mTokenIncentiveController.getRewardsByAsset(
          baseData.mTokenAddress
        );
        UserRewardInfo[] memory aUserRewardsInformation = new UserRewardInfo[](
          mTokenRewardAddresses.length
        );
        for (uint256 j = 0; j < mTokenRewardAddresses.length; ++j) {
          UserRewardInfo memory userRewardInformation;
          userRewardInformation.rewardTokenAddress = mTokenRewardAddresses[j];

          userRewardInformation.tokenIncentivesUserIndex = mTokenIncentiveController
            .getUserAssetIndex(
              user,
              baseData.mTokenAddress,
              userRewardInformation.rewardTokenAddress
            );

          userRewardInformation.userUnclaimedRewards = mTokenIncentiveController
            .getUserAccruedRewards(user, userRewardInformation.rewardTokenAddress);
          userRewardInformation.rewardTokenDecimals = IERC20Detailed(
            userRewardInformation.rewardTokenAddress
          ).decimals();
          userRewardInformation.rewardTokenSymbol = IERC20Detailed(
            userRewardInformation.rewardTokenAddress
          ).symbol();

          // Get price of reward token from Chainlink Proxy Oracle
          userRewardInformation.rewardOracleAddress = mTokenIncentiveController.getRewardOracle(
            userRewardInformation.rewardTokenAddress
          );
          userRewardInformation.priceFeedDecimals = IEACAggregatorProxy(
            userRewardInformation.rewardOracleAddress
          ).decimals();
          userRewardInformation.rewardPriceFeed = IEACAggregatorProxy(
            userRewardInformation.rewardOracleAddress
          ).latestAnswer();

          aUserRewardsInformation[j] = userRewardInformation;
        }

        userReservesIncentivesData[i].mTokenIncentivesUserData = UserIncentiveData(
          baseData.mTokenAddress,
          address(mTokenIncentiveController),
          aUserRewardsInformation
        );
      }

      // variable debt token
      IRewardsController vTokenIncentiveController = IRewardsController(
        address(IncentivizedERC20(baseData.variableDebtTokenAddress).getIncentivesController())
      );
      if (address(vTokenIncentiveController) != address(0)) {
        // get all rewards information from the asset
        address[] memory vTokenRewardAddresses = vTokenIncentiveController.getRewardsByAsset(
          baseData.variableDebtTokenAddress
        );
        UserRewardInfo[] memory vUserRewardsInformation = new UserRewardInfo[](
          vTokenRewardAddresses.length
        );
        for (uint256 j = 0; j < vTokenRewardAddresses.length; ++j) {
          UserRewardInfo memory userRewardInformation;
          userRewardInformation.rewardTokenAddress = vTokenRewardAddresses[j];

          userRewardInformation.tokenIncentivesUserIndex = vTokenIncentiveController
            .getUserAssetIndex(
              user,
              baseData.variableDebtTokenAddress,
              userRewardInformation.rewardTokenAddress
            );

          userRewardInformation.userUnclaimedRewards = vTokenIncentiveController
            .getUserAccruedRewards(user, userRewardInformation.rewardTokenAddress);
          userRewardInformation.rewardTokenDecimals = IERC20Detailed(
            userRewardInformation.rewardTokenAddress
          ).decimals();
          userRewardInformation.rewardTokenSymbol = IERC20Detailed(
            userRewardInformation.rewardTokenAddress
          ).symbol();

          // Get price of reward token from Chainlink Proxy Oracle
          userRewardInformation.rewardOracleAddress = vTokenIncentiveController.getRewardOracle(
            userRewardInformation.rewardTokenAddress
          );
          userRewardInformation.priceFeedDecimals = IEACAggregatorProxy(
            userRewardInformation.rewardOracleAddress
          ).decimals();
          userRewardInformation.rewardPriceFeed = IEACAggregatorProxy(
            userRewardInformation.rewardOracleAddress
          ).latestAnswer();

          vUserRewardsInformation[j] = userRewardInformation;
        }

        userReservesIncentivesData[i].vTokenIncentivesUserData = UserIncentiveData(
          baseData.variableDebtTokenAddress,
          address(mTokenIncentiveController),
          vUserRewardsInformation
        );
      }

      // stable debt toekn
      IRewardsController sTokenIncentiveController = IRewardsController(
        address(IncentivizedERC20(baseData.stableDebtTokenAddress).getIncentivesController())
      );
      if (address(sTokenIncentiveController) != address(0)) {
        // get all rewards information from the asset
        address[] memory sTokenRewardAddresses = sTokenIncentiveController.getRewardsByAsset(
          baseData.stableDebtTokenAddress
        );
        UserRewardInfo[] memory sUserRewardsInformation = new UserRewardInfo[](
          sTokenRewardAddresses.length
        );
        for (uint256 j = 0; j < sTokenRewardAddresses.length; ++j) {
          UserRewardInfo memory userRewardInformation;
          userRewardInformation.rewardTokenAddress = sTokenRewardAddresses[j];

          userRewardInformation.tokenIncentivesUserIndex = sTokenIncentiveController
            .getUserAssetIndex(
              user,
              baseData.stableDebtTokenAddress,
              userRewardInformation.rewardTokenAddress
            );

          userRewardInformation.userUnclaimedRewards = sTokenIncentiveController
            .getUserAccruedRewards(user, userRewardInformation.rewardTokenAddress);
          userRewardInformation.rewardTokenDecimals = IERC20Detailed(
            userRewardInformation.rewardTokenAddress
          ).decimals();
          userRewardInformation.rewardTokenSymbol = IERC20Detailed(
            userRewardInformation.rewardTokenAddress
          ).symbol();

          // Get price of reward token from Chainlink Proxy Oracle
          userRewardInformation.rewardOracleAddress = sTokenIncentiveController.getRewardOracle(
            userRewardInformation.rewardTokenAddress
          );
          userRewardInformation.priceFeedDecimals = IEACAggregatorProxy(
            userRewardInformation.rewardOracleAddress
          ).decimals();
          userRewardInformation.rewardPriceFeed = IEACAggregatorProxy(
            userRewardInformation.rewardOracleAddress
          ).latestAnswer();

          sUserRewardsInformation[j] = userRewardInformation;
        }

        userReservesIncentivesData[i].sTokenIncentivesUserData = UserIncentiveData(
          baseData.stableDebtTokenAddress,
          address(mTokenIncentiveController),
          sUserRewardsInformation
        );
      }
    }

    return (userReservesIncentivesData);
  }
}
