// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISimpleV2Callee
 * @dev 闪电贷回调接口
 */
interface ISimpleV2Callee {
    /**
     * @dev 闪电贷回调函数
     * @param sender 发起swap的地址
     * @param amount0 token0的数量
     * @param amount1 token1的数量
     * @param data 传递给回调的数据
     */
    function simpleV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
} 