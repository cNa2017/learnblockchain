// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/ISimpleV2Callee.sol";
import "../core/SimpleV2Pair.sol";
import "../core/SimpleV2Factory.sol";
import "../periphery/SimpleV2Router.sol";

/**
 * @title RealFlashSwapArbitrage
 * @dev 真实的闪电贷套利合约，在两个不同的工厂/池子间进行套利
 */
contract RealFlashSwapArbitrage is ISimpleV2Callee {
    using SafeERC20 for IERC20;

    address public immutable factoryA;
    address public immutable factoryB;
    address public immutable routerA;
    address public immutable routerB;
    address public owner;

    // 事件
    event ArbitrageExecuted(
        address indexed borrowToken,
        address indexed repayToken,
        uint256 borrowAmount,
        uint256 repayAmount,
        uint256 profit,
        address executor
    );

    event ArbitrageOpportunityFound(
        address indexed tokenA,
        address indexed tokenB,
        uint256 priceA,
        uint256 priceB,
        uint256 priceDiff
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "RealFlashSwapArbitrage: FORBIDDEN");
        _;
    }

    constructor(address _factoryA, address _factoryB, address _routerA, address _routerB) {
        factoryA = _factoryA;
        factoryB = _factoryB;
        routerA = _routerA;
        routerB = _routerB;
        owner = msg.sender;
    }

    /**
     * @dev 检查套利机会
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @return hasOpportunity 是否存在套利机会
     * @return borrowFromA 是否应该从池子A借贷
     * @return expectedProfit 预期利润
     */
    function checkArbitrageOpportunity(address tokenA, address tokenB)
        external view returns (bool hasOpportunity, bool borrowFromA, uint256 expectedProfit) {
        
        // 检查两个池子是否都存在
        address pairA = SimpleV2Factory(factoryA).getPair(tokenA, tokenB);
        address pairB = SimpleV2Factory(factoryB).getPair(tokenA, tokenB);
        
        if (pairA == address(0) || pairB == address(0)) {
            return (false, false, 0);
        }

        // 尝试两个方向的套利：
        // 方向1：从A借tokenA，在B换tokenB，还给A
        // 方向2：从B借tokenA，在A换tokenB，还给B
        
        (bool profitableA, uint256 profitA) = _simulateArbitrage(tokenA, tokenB, true);  // 从A借贷
        (bool profitableB, uint256 profitB) = _simulateArbitrage(tokenA, tokenB, false); // 从B借贷
        
        if (profitableA && profitableB) {
            // 选择利润更高的方向
            if (profitA >= profitB) {
                return (true, true, profitA);
            } else {
                return (true, false, profitB);
            }
        } else if (profitableA) {
            return (true, true, profitA);
        } else if (profitableB) {
            return (true, false, profitB);
        } else {
            return (false, false, 0);
        }
    }

    /**
     * @dev 模拟套利过程
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址  
     * @param borrowFromA 是否从池子A借贷
     * @return profitable 是否有利润
     * @param expectedProfit 预期利润
     */
    function _simulateArbitrage(address tokenA, address tokenB, bool borrowFromA) 
        internal view returns (bool profitable, uint256 expectedProfit) {
        
        // 设置一个测试借贷金额（相对较小以避免过大滑点）
        uint256 testBorrowAmount = 10 * 1e18; // 10个代币作为测试，避免过大滑点
        
        try this._simulateArbitrageInternal(tokenA, tokenB, testBorrowAmount, borrowFromA) 
            returns (uint256 profit) {
            if (profit > 0) {
                return (true, profit);
            }
        } catch {
            // 如果模拟失败，说明不可行
        }
        
        return (false, 0);
    }

    /**
     * @dev 内部模拟套利过程（external以便try-catch调用）
     */
    function _simulateArbitrageInternal(address tokenA, address tokenB, uint256 borrowAmount, bool borrowFromA) 
        external view returns (uint256 profit) {
        
        // 选择路由器
        address payable swapRouter = borrowFromA ? payable(routerB) : payable(routerA);
        address payable borrowRouter = borrowFromA ? payable(routerA) : payable(routerB);
        
        // 步骤1：模拟用借出的tokenA换取tokenB
        address[] memory swapPath = new address[](2);
        swapPath[0] = tokenA;
        swapPath[1] = tokenB;
        
        uint256[] memory swapAmountsOut = SimpleV2Router(swapRouter).getAmountsOut(borrowAmount, swapPath);
        uint256 tokenBReceived = swapAmountsOut[1];
        
        // 步骤2：计算还款需要多少tokenB
        address[] memory repayPath = new address[](2);
        repayPath[0] = tokenB;
        repayPath[1] = tokenA;
        
        uint256[] memory repayAmountsIn = SimpleV2Router(borrowRouter).getAmountsIn(borrowAmount, repayPath);
        uint256 tokenBRequired = repayAmountsIn[0];
        
        // 步骤3：计算利润
        if (tokenBReceived > tokenBRequired) {
            profit = tokenBReceived - tokenBRequired;
        } else {
            profit = 0;
        }
        
        return profit;
    }

    /**
     * @dev 执行套利
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @param borrowAmount 借贷数量
     * @param borrowFromA 是否从池子A借贷
     */
    function executeArbitrage(address tokenA, address tokenB, uint256 borrowAmount, bool borrowFromA)
        external onlyOwner {
        // 检查套利机会
        (bool hasOpportunity, bool shouldBorrowFromA,) = this.checkArbitrageOpportunity(tokenA, tokenB);
        require(hasOpportunity, "RealFlashSwapArbitrage: NO_ARBITRAGE_OPPORTUNITY");
        require(borrowFromA == shouldBorrowFromA, "RealFlashSwapArbitrage: WRONG_BORROW_DIRECTION");

        // 选择借贷的工厂和池子
        address borrowFactory = borrowFromA ? factoryA : factoryB;
        address borrowPair = SimpleV2Factory(borrowFactory).getPair(tokenA, tokenB);
        require(borrowPair != address(0), "RealFlashSwapArbitrage: BORROW_PAIR_NOT_EXISTS");

        // 构造回调数据
        bytes memory data = abi.encode(
            tokenA,
            tokenB,
            borrowAmount,
            borrowFromA,
            msg.sender
        );

        // 确定借贷的代币和数量
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        uint256 amount0Out = 0;
        uint256 amount1Out = 0;

        // 假设我们借贷tokenA
        if (tokenA == token0) {
            amount0Out = borrowAmount;
        } else {
            amount1Out = borrowAmount;
        }

        // 发起闪电贷
        SimpleV2Pair(borrowPair).swap(amount0Out, amount1Out, address(this), data);
    }

    /**
     * @dev 闪电贷回调函数
     */
    function simpleV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data)
        external override {
        // 解码回调数据
        (
            address tokenA,
            address tokenB,
            uint256 borrowAmount,
            bool borrowFromA,
            address executor
        ) = abi.decode(data, (address, address, uint256, bool, address));

        // 验证调用者
        address borrowFactory = borrowFromA ? factoryA : factoryB;
        address borrowPair = SimpleV2Factory(borrowFactory).getPair(tokenA, tokenB);
        require(msg.sender == borrowPair, "RealFlashSwapArbitrage: INVALID_CALLER");
        require(sender == address(this), "RealFlashSwapArbitrage: INVALID_SENDER");

        // 确定借出的代币和数量
        uint256 borrowedAmount = amount0 > 0 ? amount0 : amount1;
        address borrowToken = amount0 > 0 ? SimpleV2Pair(borrowPair).token0() : SimpleV2Pair(borrowPair).token1();
        address repayToken = borrowToken == tokenA ? tokenB : tokenA;
        require(borrowedAmount == borrowAmount, "RealFlashSwapArbitrage: WRONG_BORROW_AMOUNT");

        // 执行套利
        uint256 profit = _executeOptimizedArbitrage(
            borrowToken,
            repayToken,
            borrowedAmount,
            borrowFromA,
            borrowPair
        );

        // 将利润转给执行者
        if (profit > 0) {
            IERC20(repayToken).safeTransfer(executor, profit);
        }

        emit ArbitrageExecuted(borrowToken, repayToken, borrowedAmount, borrowedAmount, profit, executor);
    }

    /**
     * @dev 执行优化的套利逻辑
     * @param borrowToken 借出的代币
     * @param repayToken 需要还款的代币
     * @param borrowedAmount 借出的数量
     * @param borrowFromA 是否从池子A借贷
     * @param borrowPair 借贷的池子地址
     */
    function _executeOptimizedArbitrage(address borrowToken, address repayToken, uint256 borrowedAmount, bool borrowFromA, address borrowPair)
        internal returns (uint256 profit) {
        
        // 选择交换的工厂和路由器（与借贷工厂相反）
        address swapFactory = borrowFromA ? factoryB : factoryA;
        address payable swapRouter = borrowFromA ? payable(routerB) : payable(routerA);
        
        // 确保交换工厂的池子存在
        address swapPair = SimpleV2Factory(swapFactory).getPair(borrowToken, repayToken);
        require(swapPair != address(0), "RealFlashSwapArbitrage: SWAP_PAIR_NOT_EXISTS");

        // 第一步：在交换工厂用借出的代币换取还款代币
        address[] memory swapPath = new address[](2);
        swapPath[0] = borrowToken;
        swapPath[1] = repayToken;

        IERC20(borrowToken).approve(swapRouter, borrowedAmount);
        
        SimpleV2Router(swapRouter).swapExactTokensForTokens(
            borrowedAmount,
            0, // 最小输出设为0（生产环境中应该设置滑点保护）
            swapPath,
            address(this),
            block.timestamp + 300
        );

        // 第二步：计算需要还给借贷池子的确切数量 - 使用getAmountsIn
        address[] memory repayPath = new address[](2);
        repayPath[0] = repayToken;
        repayPath[1] = borrowToken;
        
        address payable borrowRouter = borrowFromA ? payable(routerA) : payable(routerB);
        uint256[] memory amountsIn = SimpleV2Router(borrowRouter).getAmountsIn(borrowedAmount, repayPath);
        uint256 requiredRepayAmount = amountsIn[0]; // 需要的repayToken数量
        
        // 检查是否有足够的代币还款
        uint256 repayTokenReceived = IERC20(repayToken).balanceOf(address(this));
        require(repayTokenReceived > requiredRepayAmount, "RealFlashSwapArbitrage: INSUFFICIENT_RECEIVED_FOR_REPAY");

        // 第三步：还款给借贷池子
        IERC20(repayToken).safeTransfer(borrowPair, requiredRepayAmount);

        // 第四步：计算利润
        uint256 remainingBalance = IERC20(repayToken).balanceOf(address(this));
        profit = remainingBalance;

        return profit;
    }

    /**
     * @dev 获取代币对在指定工厂中的价格
     */
    function _getPrice(address factory, address payable router, address tokenA, address tokenB)
        internal view returns (uint256 price, bool valid) {
        address pair = SimpleV2Factory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            return (0, false);
        }

        try SimpleV2Router(router).getReserves(tokenA, tokenB) returns (uint256 reserveA, uint256 reserveB) {
            if (reserveA > 0 && reserveB > 0) {
                price = (reserveB * 1e18) / reserveA; // tokenA的价格，以tokenB计价
                valid = true;
            }
        } catch {
            valid = false;
        }
    }

    /**
     * @dev 排序代币地址
     */
    function _sortTokens(address tokenA, address tokenB)
        internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "RealFlashSwapArbitrage: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "RealFlashSwapArbitrage: ZERO_ADDRESS");
    }

    /**
     * @dev 紧急提取函数
     */
    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(owner, balance);
        }
    }

    /**
     * @dev 更改所有者
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "RealFlashSwapArbitrage: INVALID_ADDRESS");
        owner = newOwner;
    }

    /**
     * @dev 批量检查多个代币对的套利机会
     */
    function batchCheckArbitrageOpportunities(address[] calldata tokensA, address[] calldata tokensB)
        external view returns (
            bool[] memory hasOpportunities,
            bool[] memory borrowFromAs,
            uint256[] memory expectedProfits
        ) {
        require(tokensA.length == tokensB.length, "RealFlashSwapArbitrage: ARRAY_LENGTH_MISMATCH");
        
        uint256 length = tokensA.length;
        hasOpportunities = new bool[](length);
        borrowFromAs = new bool[](length);
        expectedProfits = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            (hasOpportunities[i], borrowFromAs[i], expectedProfits[i]) = 
                this.checkArbitrageOpportunity(tokensA[i], tokensB[i]);
        }
    }
} 