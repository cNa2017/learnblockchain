// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SimpleMath
 * @dev 简化的数学运算库
 */
library SimpleMath {
    /**
     * @dev 返回两个数的最小值
     */
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    /**
     * @dev 使用巴比伦方法计算平方根
     * @param y 输入值
     * @return z 平方根结果
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
} 