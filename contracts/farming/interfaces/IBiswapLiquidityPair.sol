// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./ISwapPairLike.sol";
interface IBiswapLiquidityPair is ISwapPairLike {
  function swapFee() external view returns (uint32);
}
