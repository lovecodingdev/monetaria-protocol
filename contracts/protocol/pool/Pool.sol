// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IPool} from '../../interfaces/IPool.sol';
import {PoolStorage} from './PoolStorage.sol';

contract Pool is PoolStorage, IPool{

}