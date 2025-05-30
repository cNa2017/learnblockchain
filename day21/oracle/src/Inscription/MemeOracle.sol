// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../UniswapV2/core/SimpleV2Factory.sol";
import "../UniswapV2/core/SimpleV2Pair.sol";
import "../UniswapV2/libraries/SimpleV2OracleLibrary.sol";
import "./Inscription.sol";
import "forge-std/console.sol";
/**
 * @title MemeOracle
 * @dev 用于监控 InscriptionToken (Meme) 价格的 TWAP 预言机合约
 */
contract MemeOracle is Ownable {
    using SimpleV2OracleLibrary for address;

    // 默认 TWAP 周期（24小时）
    uint32 public constant DEFAULT_PERIOD = 24 hours;
    // 最小更新间隔（防止过于频繁的更新）
    uint32 public constant MIN_UPDATE_INTERVAL = 1 minutes;
    
    // Uniswap V2 工厂合约地址
    address public immutable factory;
    // WETH 合约地址
    address public immutable WETH;
    // WETH 作为 ERC20 代币
    IERC20 public immutable wethToken;
    
    // 代币信息结构体
    struct TokenInfo {
        address pair;                  // Uniswap 交易对地址
        address token0;               // 交易对中的 token0 地址
        address token1;               // 交易对中的 token1 地址
        uint256 price0CumulativeLast; // 上次记录的 price0 累积值
        uint256 price1CumulativeLast; // 上次记录的 price1 累积值
        uint32 blockTimestampLast;    // 上次更新的区块时间戳
        uint256 price0Average;        // token0 的平均价格 (token1/token0)
        uint256 price1Average;        // token1 的平均价格 (token0/token1)
        bool initialized;             // 是否已初始化
    }
    
    // 代币地址 => 代币信息
    mapping(address => TokenInfo) public tokenInfos;
    
    // 已注册的代币地址列表
    address[] public registeredTokens;
    
    // 事件
    event TokenRegistered(address indexed token, address indexed pair, address token0, address token1);
    event PriceUpdated(address indexed token, uint256 price0Average, uint256 price1Average, uint32 period);
    event EmergencyPriceUpdate(address indexed token, uint256 spotPrice0, uint256 spotPrice1);

    constructor(address _factory, address _WETH) Ownable(msg.sender) {
        // 验证地址有效性
        require(_factory != address(0), "MemeOracle: INVALID_FACTORY");
        require(_WETH != address(0), "MemeOracle: INVALID_WETH");
        
        factory = _factory;
        WETH = _WETH;
        wethToken = IERC20(_WETH);
        
        // 验证工厂合约的有效性
        try SimpleV2Factory(_factory).allPairsLength() returns (uint256) {
            // 工厂合约有效
        } catch {
            revert("MemeOracle: INVALID_FACTORY_CONTRACT");
        }
        
        // 验证 WETH 合约的有效性（通过调用基本的 ERC20 函数）
        try wethToken.totalSupply() returns (uint256) {
            // WETH 合约有效
        } catch {
            revert("MemeOracle: INVALID_WETH_CONTRACT");
        }
    }

    /**
     * @dev 注册一个 Meme 代币进行价格监控
     * @param token Meme 代币地址
     */
    function registerToken(address token) external onlyOwner {
        require(token != address(0), "MemeOracle: INVALID_TOKEN");
        require(!tokenInfos[token].initialized, "MemeOracle: ALREADY_REGISTERED");
        require(token != WETH, "MemeOracle: CANNOT_REGISTER_WETH");
        
        // 验证是否为有效的 InscriptionToken
        try InscriptionToken(token).factory() returns (address tokenFactory) {
            require(tokenFactory != address(0), "MemeOracle: INVALID_INSCRIPTION_TOKEN");
        } catch {
            revert("MemeOracle: TOKEN_VALIDATION_FAILED");
        }
        
        // 获取 Uniswap 交易对
        address pair = SimpleV2Factory(factory).getPair(token, WETH);
        require(pair != address(0), "MemeOracle: PAIR_NOT_EXISTS");
        
        // 确保交易对有足够的流动性（参考 ExampleOracleSimple）
        (uint112 reserve0, uint112 reserve1,) = SimpleV2Pair(pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "MemeOracle: NO_RESERVES");
        
        // 确定代币在交易对中的位置
        address token0 = SimpleV2Pair(pair).token0();
        bool isToken0 = (token == token0);
        
        // 验证代币配对正确性
        address token1 = SimpleV2Pair(pair).token1();
        require(
            (isToken0 && token1 == WETH) || (!isToken0 && token0 == WETH),
            "MemeOracle: INVALID_PAIR_TOKENS"
        );
        
        // 获取当前累积价格和时间戳（统一使用这个时间戳）
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = 
            SimpleV2OracleLibrary.currentCumulativePrices(pair);
        
        // 初始化代币信息
        tokenInfos[token] = TokenInfo({
            pair: pair,
            token0: token0,
            token1: token1,
            price0CumulativeLast: price0Cumulative,
            price1CumulativeLast: price1Cumulative,
            blockTimestampLast: blockTimestamp,
            price0Average: 0,
            price1Average: 0,
            initialized: true
        });
        
        registeredTokens.push(token);
        
        emit TokenRegistered(token, pair, token0, token1);
    }

    /**
     * @dev 更新指定代币的 TWAP 价格
     * @param token 代币地址
     */
    function updatePrice(address token) external {
        TokenInfo storage info = tokenInfos[token];
        require(info.initialized, "MemeOracle: TOKEN_NOT_REGISTERED");
        
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = 
            SimpleV2OracleLibrary.currentCumulativePrices(info.pair);
        // console.log("ELAPSED", blockTimestamp,info.blockTimestampLast);
        uint32 timeElapsed = blockTimestamp - info.blockTimestampLast;
        console.log("Current timestamp:", blockTimestamp);
        console.log("Last timestamp:", info.blockTimestampLast);
        console.log("Time elapsed:", timeElapsed);
        console.log("Min interval required:", MIN_UPDATE_INTERVAL);
        require(timeElapsed >= MIN_UPDATE_INTERVAL, "MemeOracle: UPDATE_TOO_FREQUENT");
        
        // 计算两个方向的平均价格
        uint256 price0Average = SimpleV2OracleLibrary.getAveragePrice(
            info.price0CumulativeLast,
            price0Cumulative,
            timeElapsed
        );
        
        uint256 price1Average = SimpleV2OracleLibrary.getAveragePrice(
            info.price1CumulativeLast,
            price1Cumulative,
            timeElapsed
        );
        
        // 更新代币信息
        info.price0CumulativeLast = price0Cumulative;
        info.price1CumulativeLast = price1Cumulative;
        info.blockTimestampLast = blockTimestamp;
        info.price0Average = price0Average;
        info.price1Average = price1Average;

        console.log("--------------Price updated:", price0Average, price1Average, timeElapsed);
        emit PriceUpdated(token, price0Average, price1Average, timeElapsed);
    }

    /**
     * @dev 批量更新所有已注册代币的价格
     */
    function updateAllPrices() external {
        uint256 length = registeredTokens.length;
        for (uint256 i = 0; i < length; i++) {
            address token = registeredTokens[i];
            _updatePriceInternal(token);
        }
    }

    /**
     * @dev 内部更新价格函数，用于批量更新
     */
    function _updatePriceInternal(address token) internal {
        TokenInfo storage info = tokenInfos[token];
        if (!info.initialized) {
            return;
        }
        
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = 
            SimpleV2OracleLibrary.currentCumulativePrices(info.pair);
        
        uint32 timeElapsed = blockTimestamp - info.blockTimestampLast;
        if (timeElapsed < MIN_UPDATE_INTERVAL) {
            return;
        }
        
        // 计算两个方向的平均价格
        uint256 price0Average = SimpleV2OracleLibrary.getAveragePrice(
            info.price0CumulativeLast,
            price0Cumulative,
            timeElapsed
        );
        
        uint256 price1Average = SimpleV2OracleLibrary.getAveragePrice(
            info.price1CumulativeLast,
            price1Cumulative,
            timeElapsed
        );
        
        // 更新代币信息
        info.price0CumulativeLast = price0Cumulative;
        info.price1CumulativeLast = price1Cumulative;
        info.blockTimestampLast = blockTimestamp;
        info.price0Average = price0Average;
        info.price1Average = price1Average;
        
        emit PriceUpdated(token, price0Average, price1Average, timeElapsed);
    }

    /**
     * @dev 获取代币的 TWAP 价格（相对于 WETH）
     * @param token 代币地址
     * @return priceAverage TWAP 价格（以 WETH 计价）
     * @return lastUpdateTime 最后更新时间
     */
    function getPrice(address token) 
        external view returns (uint256 priceAverage, uint32 lastUpdateTime) {
        TokenInfo storage info = tokenInfos[token];
        require(info.initialized, "MemeOracle: TOKEN_NOT_REGISTERED");
        
        // 根据 WETH 在交易对中的位置返回相应的价格
        if (info.token0 == WETH) {
            // WETH 是 token0，返回 price0 (token1/token0)
            priceAverage = info.price0Average;
        } else if (info.token1 == WETH) {
            // WETH 是 token1，返回 price1 (token0/token1)
            priceAverage = info.price1Average;
        } else {
            revert("MemeOracle: PAIR_NOT_CONTAINS_WETH");
        }
        
        lastUpdateTime = info.blockTimestampLast;
    }

    /**
     * @dev 获取交易对的所有价格信息
     * @param token 代币地址
     * @return price0Average token0 的 TWAP 价格 (token1/token0)
     * @return price1Average token1 的 TWAP 价格 (token0/token1)
     * @return token0 交易对中的 token0 地址
     * @return token1 交易对中的 token1 地址
     * @return lastUpdateTime 最后更新时间
     */
    function getAllPriceInfo(address token) 
        external view returns (
            uint256 price0Average,
            uint256 price1Average,
            address token0,
            address token1,
            uint32 lastUpdateTime
        ) {
        TokenInfo storage info = tokenInfos[token];
        require(info.initialized, "MemeOracle: TOKEN_NOT_REGISTERED");
        
        price0Average = info.price0Average;
        price1Average = info.price1Average;
        token0 = info.token0;
        token1 = info.token1;
        lastUpdateTime = info.blockTimestampLast;
    }

    /**
     * @dev 获取特定代币相对于另一个代币的价格
     * @param tokenA 基础代币地址
     * @param tokenB 计价代币地址
     * @return price tokenA 相对于 tokenB 的价格
     */
    function getPriceOf(address tokenA, address tokenB) external view returns (uint256 price) {
        TokenInfo storage info = tokenInfos[tokenA];
        require(info.initialized, "MemeOracle: TOKEN_NOT_REGISTERED");
        
        if (info.token0 == tokenA && info.token1 == tokenB) {
            // tokenA 是 token0，tokenB 是 token1，返回 price1 (token0/token1)
            price = info.price1Average;
        } else if (info.token0 == tokenB && info.token1 == tokenA) {
            // tokenB 是 token0，tokenA 是 token1，返回 price0 (token1/token0)
            price = info.price0Average;
        } else {
            revert("MemeOracle: INVALID_TOKEN_PAIR");
        }
    }

    /**
     * @dev 获取代币的即时价格（当前区块）
     * @param token 代币地址
     * @return spotPrice 即时价格（以 WETH 计价）
     * @return currentTime 当前区块时间戳
     */
    function getSpotPrice(address token) 
        external view returns (uint256 spotPrice, uint32 currentTime) {
        TokenInfo storage info = tokenInfos[token];
        require(info.initialized, "MemeOracle: TOKEN_NOT_REGISTERED");
        
        (uint112 reserve0, uint112 reserve1,) = SimpleV2Pair(info.pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "MemeOracle: INSUFFICIENT_LIQUIDITY");
        
        if (info.token0 == WETH) {
            // spotPrice = reserve1 / reserve0 = WETH / Meme
            spotPrice = (uint256(reserve1) * 1e18) / reserve0;
        } else {
            // spotPrice = reserve0 / reserve1 = WETH / Meme  
            spotPrice = (uint256(reserve0) * 1e18) / reserve1;
        }
        
        currentTime = uint32(block.timestamp);
    }

    /**
     * @dev 将价格转换为代币数量
     * @param token 代币地址
     * @param wethAmount WETH 数量
     * @return tokenAmount 对应的代币数量
     * @return priceUpdateTime 价格最后更新时间
     */
    function consultPrice(address token, uint256 wethAmount) 
        external view returns (uint256 tokenAmount, uint32 priceUpdateTime) {
        TokenInfo storage info = tokenInfos[token];
        require(info.initialized, "MemeOracle: TOKEN_NOT_REGISTERED");
        
        uint256 priceAverage;
        // 根据 WETH 在交易对中的位置获取相应的价格
        if (info.token0 == WETH) {
            priceAverage = info.price0Average;
        } else if (info.token1 == WETH) {
            priceAverage = info.price1Average;
        } else {
            revert("MemeOracle: PAIR_NOT_CONTAINS_WETH");
        }
        
        require(priceAverage > 0, "MemeOracle: PRICE_NOT_INITIALIZED");
        
        // tokenAmount = wethAmount / priceAverage
        tokenAmount = (wethAmount * 1e18) / priceAverage;
        priceUpdateTime = info.blockTimestampLast;
    }

    /**
     * @dev 获取已注册代币的数量
     */
    function getRegisteredTokenCount() external view returns (uint256) {
        return registeredTokens.length;
    }

    /**
     * @dev 获取指定索引的已注册代币地址
     */
    function getRegisteredToken(uint256 index) external view returns (address) {
        require(index < registeredTokens.length, "MemeOracle: INDEX_OUT_OF_BOUNDS");
        return registeredTokens[index];
    }

    /**
     * @dev 检查代币是否已注册
     */
    function isTokenRegistered(address token) external view returns (bool) {
        return tokenInfos[token].initialized;
    }

    /**
     * @dev 紧急情况下更新即时价格（仅限 owner）
     * @param token 代币地址
     */
    function emergencyUpdateSpotPrice(address token) external onlyOwner {
        TokenInfo storage info = tokenInfos[token];
        require(info.initialized, "MemeOracle: TOKEN_NOT_REGISTERED");
        
        // 直接计算即时价格而不是调用 getSpotPrice
        (uint112 reserve0, uint112 reserve1,) = SimpleV2Pair(info.pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "MemeOracle: INSUFFICIENT_LIQUIDITY");
        
        uint256 spotPrice;
        if (info.token0 == WETH) {
            // spotPrice = reserve1 / reserve0 = WETH / Meme
            spotPrice = (uint256(reserve1) * 1e18) / reserve0;
        } else {
            // spotPrice = reserve0 / reserve1 = WETH / Meme  
            spotPrice = (uint256(reserve0) * 1e18) / reserve1;
        }
        
        info.price0Average = spotPrice;
        info.price1Average = spotPrice;
        info.blockTimestampLast = uint32(block.timestamp);
        
        emit EmergencyPriceUpdate(token, spotPrice, spotPrice);
    }

    /**
     * @dev 获取交易对的流动性信息
     * @param token 代币地址
     * @return reserve0 代币0的储备量
     * @return reserve1 代币1的储备量
     * @return lastUpdateTime 最后更新时间
     */
    function getPairReserves(address token) 
        external view returns (uint112 reserve0, uint112 reserve1, uint32 lastUpdateTime) {
        TokenInfo storage info = tokenInfos[token];
        require(info.initialized, "MemeOracle: TOKEN_NOT_REGISTERED");
        
        return SimpleV2Pair(info.pair).getReserves();
    }

    /**
     * @dev 获取交易对中 WETH 的储备量
     * @param token 代币地址
     * @return wethReserve WETH 储备量
     */
    function getWETHReserve(address token) external view returns (uint256 wethReserve) {
        TokenInfo storage info = tokenInfos[token];
        require(info.initialized, "MemeOracle: TOKEN_NOT_REGISTERED");
        
        (uint112 reserve0, uint112 reserve1,) = SimpleV2Pair(info.pair).getReserves();
        
        if (info.token0 == WETH) {
            // WETH 是 token1
            wethReserve = uint256(reserve1);
        } else {
            // WETH 是 token0
            wethReserve = uint256(reserve0);
        }
    }

    /**
     * @dev 获取交易对中代币的储备量
     * @param token 代币地址
     * @return tokenReserve 代币储备量
     */
    function getTokenReserve(address token) external view returns (uint256 tokenReserve) {
        TokenInfo storage info = tokenInfos[token];
        require(info.initialized, "MemeOracle: TOKEN_NOT_REGISTERED");
        
        (uint112 reserve0, uint112 reserve1,) = SimpleV2Pair(info.pair).getReserves();
        
        if (info.token0 == WETH) {
            // 代币是 token0
            tokenReserve = uint256(reserve0);
        } else {
            // 代币是 token1
            tokenReserve = uint256(reserve1);
        }
    }

    /**
     * @dev 检查价格更新是否可用（时间间隔是否足够）
     * @param token 代币地址
     * @return canUpdate 是否可以更新
     * @return timeUntilUpdate 距离下次可更新的时间（秒）
     */
    function canUpdatePrice(address token) 
        external view returns (bool canUpdate, uint32 timeUntilUpdate) {
        TokenInfo storage info = tokenInfos[token];
        require(info.initialized, "MemeOracle: TOKEN_NOT_REGISTERED");
        
        uint32 currentTime = uint32(block.timestamp);
        uint32 timeElapsed = currentTime - info.blockTimestampLast;
        
        if (timeElapsed >= MIN_UPDATE_INTERVAL) {
            canUpdate = true;
            timeUntilUpdate = 0;
        } else {
            canUpdate = false;
            timeUntilUpdate = MIN_UPDATE_INTERVAL - timeElapsed;
        }
    }

    /**
     * @dev 批量获取所有已注册代币的价格信息
     * @return tokens 代币地址数组
     * @return prices TWAP价格数组
     * @return spotPrices 即时价格数组
     * @return lastUpdates 最后更新时间数组
     */
    function getAllPrices() 
        external view 
        returns (
            address[] memory tokens,
            uint256[] memory prices,
            uint256[] memory spotPrices,
            uint32[] memory lastUpdates
        ) {
        uint256 length = registeredTokens.length;
        tokens = new address[](length);
        prices = new uint256[](length);
        spotPrices = new uint256[](length);
        lastUpdates = new uint32[](length);
        
        for (uint256 i = 0; i < length; i++) {
            address token = registeredTokens[i];
            tokens[i] = token;
            
            TokenInfo storage info = tokenInfos[token];
            prices[i] = info.price0Average;
            lastUpdates[i] = info.blockTimestampLast;
            
            // 计算即时价格
            try this.getSpotPrice(token) returns (uint256 spotPrice, uint32) {
                spotPrices[i] = spotPrice;
            } catch {
                spotPrices[i] = 0;
            }
        }
    }
} 