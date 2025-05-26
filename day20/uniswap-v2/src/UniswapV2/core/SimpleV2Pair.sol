// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./SimpleV2ERC20.sol";
import "../libraries/SimpleMath.sol";

/**
 * @title SimpleV2Pair
 * @dev 简化版Uniswap V2交易对合约
 */
contract SimpleV2Pair is SimpleV2ERC20, ReentrancyGuard {
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
        external nonReentrant returns (uint256 liquidity) {
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
        external nonReentrant returns (uint256 amount0, uint256 amount1) {
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
     * @dev 代币交换
     * @param amount0Out 输出token0数量
     * @param amount1Out 输出token1数量
     * @param to 接收代币的地址
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata)
        external nonReentrant {
        require(amount0Out > 0 || amount1Out > 0, "SimpleV2: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "SimpleV2: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "SimpleV2: INVALID_TO");
            
            // 乐观转移
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "SimpleV2: INSUFFICIENT_INPUT_AMOUNT");

        // 不考虑手续费，直接验证K值不变性（简化版本）
        require(balance0 * balance1 >= uint256(_reserve0) * _reserve1, "SimpleV2: K");

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @dev 强制储备量与余额匹配
     */
    function sync()
        external nonReentrant {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }
} 