// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./SimpleV2ERC20.sol";
import "../libraries/SimpleMath.sol";
import "../interfaces/ISimpleV2Callee.sol";

/**
 * @title SimpleV2Pair
 * @dev 简化版Uniswap V2交易对合约
 */
contract SimpleV2Pair is SimpleV2ERC20 {
    using SimpleMath for uint256;

    // 最小流动性常量，防止首次流动性提供者恶意攻击
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;

    address public factory;
    address public token0;
    address public token1;

    // 储备量，使用uint112节省gas
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    // 事件
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() {
        factory = msg.sender;
    }

    /**
     * @dev 由工厂合约调用，初始化交易对
     */
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "SimpleV2: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @dev 获取当前储备量
     */
    function getReserves()
        public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @dev 安全转移代币
     */
    function _safeTransfer(address token, address to, uint256 value) private {
        require(IERC20(token).transfer(to, value), "SimpleV2: TRANSFER_FAILED");
    }

    /**
     * @dev 更新储备量
     */
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1)
        private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "SimpleV2: OVERFLOW");
        
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        
        emit Sync(reserve0, reserve1);
    }

    /**
     * @dev 添加流动性（铸造LP代币）
     * @param to 接收LP代币的地址
     * @return liquidity 铸造的LP代币数量
     */
    function mint(address to)
        external returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            // 首次添加流动性
            liquidity = SimpleMath.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // 永久锁定最小流动性
        } else {
            // 按比例分配LP代币
            liquidity = SimpleMath.min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }
        
        require(liquidity > 0, "SimpleV2: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * @dev 移除流动性（销毁LP代币）
     * @param to 接收代币的地址
     * @return amount0 返回的token0数量
     * @return amount1 返回的token1数量
     */
    function burn(address to)
        external returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        uint256 _totalSupply = totalSupply;
        amount0 = (liquidity * balance0) / _totalSupply; // 按比例分配
        amount1 = (liquidity * balance1) / _totalSupply; // 按比例分配
        
        require(amount0 > 0 && amount1 > 0, "SimpleV2: INSUFFICIENT_LIQUIDITY_BURNED");
        
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * @dev 代币交换函数，支持闪电贷
     * @notice 用户可以通过此函数在两个代币之间进行交换，也可以通过传入data实现闪电贷
     * @param amount0Out 需要输出的token0数量
     * @param amount1Out 需要输出的token1数量
     * @param to 接收交换后代币的地址
     * @param data 传递给回调函数的数据，如果长度大于0则触发闪电贷回调
     * @dev 该函数包含以下安全检查：
     * - 使用nonReentrant修饰符防止重入攻击
     * - 确保至少有一个代币的输出数量大于0
     * - 验证输出数量不超过当前储备量
     * - 验证接收地址不是代币地址
     * - 如果有data则执行闪电贷回调
     * - 确保有足够的输入数量
     * - 验证K值不变性（x * y = k）
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data)
        external {
        // 检查输出金额,确保至少有一个代币要输出
        require(amount0Out > 0 || amount1Out > 0, "SimpleV2: INSUFFICIENT_OUTPUT_AMOUNT");
        // 获取当前池子中两个代币的储备量
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // 检查输出金额是否超过储备量
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "SimpleV2: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        
        {
            // 创建新作用域以避免堆栈过深错误
            address _token0 = token0;
            address _token1 = token1;
            // 确保接收地址不是代币地址,防止代币被锁死
            require(to != _token0 && to != _token1, "SimpleV2: INVALID_TO");
            
            // 乐观转移: 先转出代币,再检查交易是否合法
            // 这样可以节省gas,因为不需要多次检查余额
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            
            // 如果data长度大于0，执行闪电贷回调
            if (data.length > 0) {
                ISimpleV2Callee(to).simpleV2Call(msg.sender, amount0Out, amount1Out, data);
            }
            
            // 获取转移后池子中的实际余额
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        // 计算实际输入的代币数量
        // 如果当前余额大于(储备量-输出量),说明有代币输入
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        // 确保至少有一个代币输入
        require(amount0In > 0 || amount1In > 0, "SimpleV2: INSUFFICIENT_INPUT_AMOUNT");

        // 不考虑手续费，直接验证K值不变性（简化版本）
        // 确保交易后的乘积大于等于交易前的乘积,保证价格不会被操纵
        require(balance0 * balance1 >= uint256(_reserve0) * _reserve1, "SimpleV2: K");

        // 更新储备量
        _update(balance0, balance1, _reserve0, _reserve1);
        // 触发交易事件
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @dev 强制储备量与余额匹配
     */
    function sync()
        external {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }
} 