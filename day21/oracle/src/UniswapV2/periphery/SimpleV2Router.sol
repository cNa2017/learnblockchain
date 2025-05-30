// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../core/SimpleV2Factory.sol";
import "../core/SimpleV2Pair.sol";
// import "../core/WETH.sol";
import "../libraries/SimpleMath.sol";

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function transfer(address to, uint256 value) external returns (bool);
}

/**
 * @title SimpleV2Router
 * @dev 简化版Uniswap V2路由器，提供便利的交互接口
 */
contract SimpleV2Router {
    using SafeERC20 for IERC20;
    using SimpleMath for uint256;

    address public immutable factory;
    address public immutable WETH;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "SimpleV2Router: EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    /**
     * @dev 给定输入数量，计算输出数量（不考虑手续费）
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public pure returns (uint256 amountOut) {
        require(amountIn > 0, "SimpleV2Router: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "SimpleV2Router: INSUFFICIENT_LIQUIDITY");
        // 简化版本：不考虑手续费的恒定乘积公式
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    /**
     * @dev 给定输出数量，计算所需输入数量
     */
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public pure returns (uint256 amountIn) {
        require(amountOut > 0, "SimpleV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "SimpleV2Router: INSUFFICIENT_LIQUIDITY");
        // 简化版本：不考虑手续费
        amountIn = (reserveIn * amountOut) / (reserveOut - amountOut) + 1;
    }

    /**
     * @dev 获取输出数组
     */
    /**
     * @dev 计算多跳兑换的输出金额数组
     * @param amountIn 输入代币数量
     * @param path 交易路径数组，包含代币地址序列
     * @return amounts 返回每一跳的代币数量数组
     * 
     * 详细说明:
     * 1. 验证交易路径至少包含2个代币地址
     * 2. 创建与路径长度相同的数组存储每一跳的代币数量
     * 3. 第一个数量为输入金额
     * 4. 遍历路径，计算每一跳的输出金额:
     *    - 获取当前交易对的储备金
     *    - 根据储备金和输入金额计算输出金额
     *    - 将输出金额作为下一跳的输入金额
     */
    function getAmountsOut(uint256 amountIn, address[] memory path)
        public view returns (uint256[] memory amounts) {
        // 检查路径长度至少为2
        require(path.length >= 2, "SimpleV2Router: INVALID_PATH");
        
        // 初始化金额数组
        amounts = new uint256[](path.length);
        // 设置初始输入金额
        amounts[0] = amountIn;
        
        // 遍历计算每一跳的输出金额
        for (uint256 i; i < path.length - 1; i++) {
            // 获取当前交易对的储备金
            (uint256 reserveIn, uint256 reserveOut) = getReserves(path[i], path[i + 1]);
            // 计算当前跳的输出金额
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @dev 获取输入数组
     */
    function getAmountsIn(uint256 amountOut, address[] memory path)
        public view returns (uint256[] memory amounts) {
        require(path.length >= 2, "SimpleV2Router: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @dev 获取储备量
     */
    function getReserves(address tokenA, address tokenB)
        public view returns (uint256 reserveA, uint256 reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        address pair = SimpleV2Factory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "SimpleV2Router: PAIR_NOT_EXISTS");
        
        (uint256 reserve0, uint256 reserve1,) = SimpleV2Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @dev 排序代币地址
     */
    function sortTokens(address tokenA, address tokenB)
        internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "SimpleV2Router: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "SimpleV2Router: ZERO_ADDRESS");
    }

    /**
     * @dev 添加流动性
     */
    /**
     * @dev 添加流动性
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址  
     * @param amountADesired 期望添加的代币A数量
     * @param amountBDesired 期望添加的代币B数量
     * @param amountAMin 最小接受的代币A数量
     * @param amountBMin 最小接受的代币B数量
     * @param to 接收流动性代币的地址
     * @param deadline 交易截止时间
     * @return amountA 实际添加的代币A数量
     * @return amountB 实际添加的代币B数量
     * @return liquidity 铸造的流动性代币数量
     */
    function addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)
        external ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // 创建交易对（如果不存在）
        address pair = SimpleV2Factory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = SimpleV2Factory(factory).createPair(tokenA, tokenB);
        }

        // 计算最优添加数量
        (amountA, amountB) = _calculateLiquidityAmounts(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        // 转移代币到交易对
        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);
        
        // 铸造流动性代币
        liquidity = SimpleV2Pair(pair).mint(to);
    }

    /**
     * @dev 移除流动性
     */
    function removeLiquidity(address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)
        public ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = SimpleV2Factory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "SimpleV2Router: PAIR_NOT_EXISTS");
        
        // 转移LP代币到交易对
        IERC20(pair).safeTransferFrom(msg.sender, pair, liquidity);
        
        // 销毁LP代币获取基础代币
        (uint256 amount0, uint256 amount1) = SimpleV2Pair(pair).burn(to);
        (address token0,) = sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        
        require(amountA >= amountAMin, "SimpleV2Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "SimpleV2Router: INSUFFICIENT_B_AMOUNT");
    }

    /**
     * @dev 精确输入交换
     */
    /**
     * @dev 精确输入代币交换
     * @param amountIn 输入代币的确切数量
     * @param amountOutMin 期望获得的最小输出代币数量
     * @param path 交易路径，path[0]是输入代币，path[path.length-1]是输出代币
     * @param to 接收输出代币的地址
     * @param deadline 交易截止时间戳
     * @return amounts 交易路径上每一步的代币数量数组
     */
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "SimpleV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            SimpleV2Factory(factory).getPair(path[0], path[1]),
            amounts[0]
        );
        
        _swap(amounts, path, to);
    }

    /**
     * @dev 精确输出交换
     */
    /**
     * @dev 精确输出代币交换
     * @param amountOut 期望获得的确切输出代币数量
     * @param amountInMax 愿意支付的最大输入代币数量
     * @param path 交易路径，path[0]是输入代币，path[path.length-1]是输出代币
     * @param to 接收输出代币的地址
     * @param deadline 交易截止时间戳
     * @return amounts 交易路径上每一步的代币数量数组
     */
    function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint256 deadline)
        external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= amountInMax, "SimpleV2Router: EXCESSIVE_INPUT_AMOUNT");
        
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            SimpleV2Factory(factory).getPair(path[0], path[1]),
            amounts[0]
        );
        
        _swap(amounts, path, to);
    }

    /**
     * @dev 内部交换函数
     */
    /**
     * @dev 内部交换函数,执行代币交换的核心逻辑
     * @param amounts 交易路径上每一步的代币数量数组
     * @param path 交易路径,包含代币地址序列
     * @param _to 最终接收代币的地址
     * 
     * 详细说明:
     * 1. 遍历交易路径,对每一跳执行:
     *    - 确定输入和输出代币
     *    - 排序代币地址获取token0
     *    - 计算当前跳的输出数量
     *    - 确定接收地址(中间跳为下一个交易对,最后一跳为_to)
     * 2. 调用交易对合约的swap函数执行实际交换
     * 3. amount0Out和amount1Out根据输入输出代币顺序确定
     */
    function _swap(uint256[] memory amounts, address[] memory path, address _to)
        internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = 
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? SimpleV2Factory(factory).getPair(output, path[i + 2]) : _to;
            SimpleV2Pair(SimpleV2Factory(factory).getPair(input, output)).swap(
                amount0Out,
                amount1Out,
                to,
                new bytes(0)
            );
        }
    }

    /**
     * @dev 计算最优流动性添加数量
     */
    function _calculateLiquidityAmounts(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin)
        internal view returns (uint256 amountA, uint256 amountB) {
        address pair = SimpleV2Factory(factory).getPair(tokenA, tokenB);
        
        if (pair == address(0)) {
            // 新交易对，直接使用期望数量
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            // 现有交易对，按比例计算
            (uint256 reserveA, uint256 reserveB) = getReserves(tokenA, tokenB);
            
            // 如果储备量为0，说明是首次添加流动性
            if (reserveA == 0 && reserveB == 0) {
                (amountA, amountB) = (amountADesired, amountBDesired);
            } else {
                uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
                
                if (amountBOptimal <= amountBDesired) {
                    require(amountBOptimal >= amountBMin, "SimpleV2Router: INSUFFICIENT_B_AMOUNT");
                    (amountA, amountB) = (amountADesired, amountBOptimal);
                } else {
                    uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                    assert(amountAOptimal <= amountADesired);
                    require(amountAOptimal >= amountAMin, "SimpleV2Router: INSUFFICIENT_A_AMOUNT");
                    (amountA, amountB) = (amountAOptimal, amountBDesired);
                }
            }
        }
    }

    // ================= ETH相关函数 =================

    /**
     * @dev 添加ETH流动性
     * @param token 代币地址
     * @param amountTokenDesired 期望添加的代币数量
     * @param amountTokenMin 最小接受的代币数量
     * @param amountETHMin 最小接受的ETH数量
     * @param to 接收流动性代币的地址
     * @param deadline 交易截止时间
     * @return amountToken 实际添加的代币数量
     * @return amountETH 实际添加的ETH数量
     * @return liquidity 铸造的流动性代币数量
     */
    function addLiquidityETH(address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline)
        external payable ensure(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = SimpleV2Factory(factory).getPair(token, WETH);
        if (pair == address(0)) {
            pair = SimpleV2Factory(factory).createPair(token, WETH);
        }
        IERC20(token).safeTransferFrom(msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = SimpleV2Pair(pair).mint(to);
        // 退还多余的ETH
        if (msg.value > amountETH) payable(msg.sender).transfer(msg.value - amountETH);
    }

    /**
     * @dev 移除ETH流动性
     * @param token 代币地址
     * @param liquidity 要移除的流动性数量
     * @param amountTokenMin 最小接受的代币数量
     * @param amountETHMin 最小接受的ETH数量
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @return amountToken 返回的代币数量
     * @return amountETH 返回的ETH数量
     */
    function removeLiquidityETH(address token, uint256 liquidity, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline)
        external ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        IERC20(token).safeTransfer(to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        payable(to).transfer(amountETH);
    }

    /**
     * @dev 使用精确ETH交换代币
     * @param amountOutMin 期望获得的最小代币数量
     * @param path 交易路径，必须以WETH开始
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @return amounts 交易路径上每一步的代币数量数组
     */
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WETH, "SimpleV2Router: INVALID_PATH");
        amounts = getAmountsOut(msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "SimpleV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(SimpleV2Factory(factory).getPair(path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    /**
     * @dev 使用代币交换精确ETH
     * @param amountOut 期望获得的确切ETH数量
     * @param amountInMax 愿意支付的最大代币数量
     * @param path 交易路径，必须以WETH结束
     * @param to 接收ETH的地址
     * @param deadline 交易截止时间
     * @return amounts 交易路径上每一步的代币数量数组
     */
    function swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint256 deadline)
        external ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "SimpleV2Router: INVALID_PATH");
        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= amountInMax, "SimpleV2Router: EXCESSIVE_INPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(
            msg.sender, SimpleV2Factory(factory).getPair(path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        payable(to).transfer(amounts[amounts.length - 1]);
    }

    /**
     * @dev 使用精确代币交换ETH
     * @param amountIn 输入代币的确切数量
     * @param amountOutMin 期望获得的最小ETH数量
     * @param path 交易路径，必须以WETH结束
     * @param to 接收ETH的地址
     * @param deadline 交易截止时间
     * @return amounts 交易路径上每一步的代币数量数组
     */
    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "SimpleV2Router: INVALID_PATH");
        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "SimpleV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(
            msg.sender, SimpleV2Factory(factory).getPair(path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        payable(to).transfer(amounts[amounts.length - 1]);
    }

    /**
     * @dev 使用ETH交换精确代币
     * @param amountOut 期望获得的确切代币数量
     * @param path 交易路径，必须以WETH开始
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @return amounts 交易路径上每一步的代币数量数组
     */
    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WETH, "SimpleV2Router: INVALID_PATH");
        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= msg.value, "SimpleV2Router: EXCESSIVE_INPUT_AMOUNT");
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(SimpleV2Factory(factory).getPair(path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // 退还多余的ETH
        if (msg.value > amounts[0]) payable(msg.sender).transfer(msg.value - amounts[0]);
    }

    /**
     * @dev 内部函数：添加流动性计算（支持ETH）
     */
    function _addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin)
        internal view returns (uint256 amountA, uint256 amountB) {
        // 创建交易对（如果不存在）
        address pair = SimpleV2Factory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            (uint256 reserveA, uint256 reserveB) = getReserves(tokenA, tokenB);
            if (reserveA == 0 && reserveB == 0) {
                (amountA, amountB) = (amountADesired, amountBDesired);
            } else {
                uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
                if (amountBOptimal <= amountBDesired) {
                    require(amountBOptimal >= amountBMin, "SimpleV2Router: INSUFFICIENT_B_AMOUNT");
                    (amountA, amountB) = (amountADesired, amountBOptimal);
                } else {
                    uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                    assert(amountAOptimal <= amountADesired);
                    require(amountAOptimal >= amountAMin, "SimpleV2Router: INSUFFICIENT_A_AMOUNT");
                    (amountA, amountB) = (amountAOptimal, amountBDesired);
                }
            }
        }
    }

    /**
     * @dev 接收ETH
     */
    receive() external payable {
        assert(msg.sender == WETH); // 只接受来自WETH合约的ETH
    }
} 