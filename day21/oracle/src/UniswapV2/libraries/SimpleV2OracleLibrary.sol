// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../core/SimpleV2Pair.sol";

/**
 * @title SimpleV2OracleLibrary
 * @dev 简化版 Uniswap V2 价格预言机库
 */
library SimpleV2OracleLibrary {
    // 价格精度因子（与 SimpleV2Pair 中的常量保持一致）
    uint256 constant PRICE_PRECISION = 1e18;
    
    /**
     * @dev 获取当前累积价格
     * @param pair 交易对地址
     * @return price0Cumulative token0的累积价格
     * @return price1Cumulative token1的累积价格
     * @return blockTimestamp 当前区块时间戳
     */
    function currentCumulativePrices(address pair)
        internal view returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) {
        return SimpleV2Pair(pair).getCurrentCumulativePrices();
    }

    /**
     * @dev 计算平均价格
     * @param priceCumulativeStart 开始时的累积价格
     * @param priceCumulativeEnd 结束时的累积价格
     * @param timeElapsed 时间间隔（秒）
     * @return priceAverage 平均价格（带 PRICE_PRECISION 精度）
     */
    function getAveragePrice(uint256 priceCumulativeStart, uint256 priceCumulativeEnd, uint32 timeElapsed)
        internal pure returns (uint256 priceAverage) {
        require(timeElapsed > 0, "SimpleV2OracleLibrary: PERIOD_NOT_ELAPSED");
        // 平均价格 = (累积价格差) / 时间间隔
        priceAverage = (priceCumulativeEnd - priceCumulativeStart) / timeElapsed;
    }

    /**
     * @dev 将平均价格转换为代币数量
     * @param priceAverage 平均价格（带 PRICE_PRECISION 精度）
     * @param amountIn 输入代币数量
     * @return amountOut 输出代币数量
     */
    function priceToAmount(uint256 priceAverage, uint256 amountIn)
        internal pure returns (uint256 amountOut) {
        // amountOut = amountIn * priceAverage / PRICE_PRECISION
        amountOut = (amountIn * priceAverage) / PRICE_PRECISION;
    }
} 