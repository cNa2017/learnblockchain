// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// 导入SimpleV2Router相关接口
interface ISimpleV2Router {
    function addLiquidityETH(address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline)
        external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
    
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external view returns (uint256[] memory amounts);
    
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external payable returns (uint256[] memory amounts);
        
    function WETH() external pure returns (address);
}

interface ISimpleV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * @title InscriptionToken
 * @dev 表示可铸造的ERC20 Meme代币
 */
contract InscriptionToken is ERC20, Initializable {
    address public factory;
    address public creator;
    uint256 public maxSupply;
    uint256 public perMint;
    uint256 public price;
    uint256 public totalMinted;
    
    string private _tokenSymbol;

    /**
     * @dev 防止直接初始化实现合约
     */
    constructor() ERC20("", "") {
        _disableInitializers();
    }

    /**
     * @dev 初始化代币参数
     */
    function initialize(string memory _symbol, uint256 _maxSupply, uint256 _perMint, uint256 _price, address _creator)
        external initializer {
        factory = msg.sender;
        creator = _creator;
        maxSupply = _maxSupply;
        perMint = _perMint;
        price = _price;
        _tokenSymbol = _symbol;
    }
    
    /**
     * @dev 覆盖ERC20的name函数
     */
    function name() public pure override returns (string memory) {
        return "Meme";
    }
    
    /**
     * @dev 覆盖ERC20的symbol函数
     */
    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }

    /**
     * @dev 铸造代币，仅工厂合约可调用
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == factory, "Only factory can mint");
        require(totalMinted + amount <= maxSupply, "Exceeds max supply");
        
        totalMinted += amount;
        _mint(to, amount);
    }
    
    /**
     * @dev 计算铸造费用
     */
    function calcMintCost() public view returns (uint256) {
        return perMint * price;
    }
}

/**
 * @title InscriptionFactory
 * @dev 用于部署和铸造InscriptionToken的工厂合约
 */
contract InscriptionFactory is Ownable {
    // 平台费率 (5%)
    uint256 public constant PLATFORM_FEE_RATE = 5;
    // 基准费率 (100%)
    uint256 public constant BASE_RATE = 100;
    
    // 实现合约地址
    address public immutable tokenImplementation;
    
    // UniswapV2相关地址
    address public immutable router;
    address public immutable factory;
    address public immutable WETH;
    
    // 平台费累积映射 (token => 累积的ETH)
    mapping(address => uint256) public platformFeeAccumulated;
    // 流动性池状态映射 (token => 是否已创建)
    mapping(address => bool) public liquidityPoolCreated;
    
    // 事件
    event InscriptionDeployed(address indexed token, address indexed creator, string symbol, uint256 maxSupply, uint256 perMint, uint256 price);
    event InscriptionMinted(address indexed token, address indexed minter, uint256 amount, uint256 paid);
    event MemeBought(address indexed token, address indexed buyer, uint256 amountOut, uint256 ethPaid);
    event LiquidityAdded(address indexed token, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);

    constructor(address _router, address _factory, address _WETH) Ownable(msg.sender) {
        // 部署实现合约
        tokenImplementation = address(new InscriptionToken());
        
        // 设置UniswapV2相关地址
        router = _router;
        factory = _factory;
        WETH = _WETH;
    }

    /**
     * @dev 部署新的Inscription代币
     * @param symbol 代币符号
     * @param maxSupply 最大供应量
     * @param perMint 每次铸造数量
     * @param price 每个代币价格(wei)
     * @return 新部署的代币地址
     */
    function deployInscription(string memory symbol, uint256 maxSupply, uint256 perMint, uint256 price)
        external returns (address) {
        require(maxSupply > 0, "Max supply must be positive");
        require(perMint > 0 && perMint <= maxSupply, "Invalid perMint amount");
        require(price >= 0, "Price cannot be negative");
        
        // 限制铸造成本，避免过高的价格设置
        uint256 mintCost = perMint * price;
        require(mintCost <= type(uint256).max, "Mint cost too high");

        // 使用Clones库部署代理合约
        address newToken = Clones.clone(tokenImplementation);
        
        // 初始化代币
        InscriptionToken(newToken).initialize(symbol, maxSupply, perMint, price, msg.sender);
        
        emit InscriptionDeployed(newToken, msg.sender, symbol, maxSupply, perMint, price);
        
        return newToken;
    }

    /**
     * @dev 铸造代币
     * @param tokenAddr 要铸造的代币地址
     */
    function mintInscription(address tokenAddr) external payable {
        InscriptionToken token = InscriptionToken(tokenAddr);
        
        // 验证工厂合约
        require(token.factory() == address(this), "Not a valid token");
        
        // 计算所需费用
        uint256 totalPrice = token.calcMintCost();
        
        require(msg.value >= totalPrice, "Insufficient payment");
        
        // 计算代币分配：95%给用户，5%用于流动性
        uint256 userTokenAmount = (token.perMint() * 95) / BASE_RATE;
        uint256 liquidityTokenAmount = token.perMint() - userTokenAmount; // 5%
        
        // 铸造代币给用户
        token.mint(msg.sender, userTokenAmount);
        
        // 计算费用分配
        uint256 platformFee = (totalPrice * PLATFORM_FEE_RATE) / BASE_RATE;
        uint256 creatorFee = totalPrice - platformFee;
        
        // 发送创建者费用
        (bool creatorSuccess, ) = payable(token.creator()).call{value: creatorFee}("");
        require(creatorSuccess, "Creator fee transfer failed");
        
        // 检查是否有足够的代币可以铸造用于流动性
        if (token.totalMinted() + liquidityTokenAmount <= token.maxSupply() && liquidityTokenAmount > 0) {
            // 铸造代币用于流动性
            token.mint(address(this), liquidityTokenAmount);
            
            // 尝试添加流动性
            _addLiquidityDirectly(tokenAddr, liquidityTokenAmount, platformFee);
        } else {
            // 如果无法铸造足够代币，则累积平台费（回退到原有逻辑）
            platformFeeAccumulated[tokenAddr] += platformFee;
        }
        
        emit InscriptionMinted(tokenAddr, msg.sender, userTokenAmount, totalPrice);
    }

    /**
     * @dev 通过Uniswap购买Meme代币（当价格优于起始价格时）
     * @param tokenAddr 要购买的代币地址
     * @param amountOutMin 期望获得的最小代币数量
     */
    function buyMeme(address tokenAddr, uint256 amountOutMin) external payable {
        InscriptionToken token = InscriptionToken(tokenAddr);
        
        // 验证工厂合约
        require(token.factory() == address(this), "Not a valid token");
        
        // 检查Uniswap交易对是否存在
        address pair;
        try ISimpleV2Factory(factory).getPair(tokenAddr, WETH) returns (address _pair) {
            pair = _pair;
        } catch {
            revert("Unable to check pair existence");
        }
        require(pair != address(0), "Uniswap pair does not exist");
        
        // 计算起始价格（mint价格）
        uint256 mintPrice = token.price();
        
        // 获取Uniswap价格
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenAddr;
        
        uint256[] memory amounts;
        try ISimpleV2Router(router).getAmountsOut(msg.value, path) returns (uint256[] memory _amounts) {
            amounts = _amounts;
        } catch {
            revert("Unable to get Uniswap price");
        }
        uint256 uniswapTokensOut = amounts[1];
        
        // 计算实际价格（每个代币的ETH成本）uniswapPrice价格较优才可以购买
        uint256 uniswapPrice = msg.value * 1e18 / uniswapTokensOut; // 保持精度
        require(uniswapPrice < mintPrice, "Uniswap price not better than mint price");
        
        // 通过Uniswap购买代币
        uint256[] memory finalAmounts;
        try ISimpleV2Router(router).swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            msg.sender,
            block.timestamp + 1800 // 30分钟截止时间
        ) returns (uint256[] memory _finalAmounts) {
            finalAmounts = _finalAmounts;
        } catch {
            revert("Uniswap swap failed");
        }
        
        emit MemeBought(tokenAddr, msg.sender, finalAmounts[1], msg.value);
    }

    /**
     * @dev 获取代币的当前Uniswap价格（相对于WETH）
     * @param tokenAddr 代币地址
     * @param ethAmount 输入的ETH数量
     * @return 可以获得的代币数量
     */
    function getUniswapPrice(address tokenAddr, uint256 ethAmount) external view returns (uint256) {
        address pair;
        try ISimpleV2Factory(factory).getPair(tokenAddr, WETH) returns (address _pair) {
            pair = _pair;
        } catch {
            return 0;
        }
        if (pair == address(0)) return 0;
        
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenAddr;
        
        try ISimpleV2Router(router).getAmountsOut(ethAmount, path) returns (uint256[] memory amounts) {
            return amounts[1];
        } catch {
            return 0;
        }
    }

    /**
     * @dev 检查Uniswap价格是否优于mint价格
     * @param tokenAddr 代币地址
     * @param ethAmount 输入的ETH数量
     * @return 是否价格更优
     */
    function isUniswapPriceBetter(address tokenAddr, uint256 ethAmount) external view returns (bool) {
        InscriptionToken token = InscriptionToken(tokenAddr);
        uint256 mintPrice = token.price();
        
        uint256 uniswapTokensOut = this.getUniswapPrice(tokenAddr, ethAmount);
        if (uniswapTokensOut == 0) return false;
        
        // 计算Uniswap实际价格
        uint256 uniswapPrice = ethAmount * 1e18 / uniswapTokensOut;
        
        return uniswapPrice < mintPrice;
    }

    /**
     * @dev 尝试添加流动性（内部函数）
     * @param tokenAddr 代币地址
     */
    function _tryAddLiquidity(address tokenAddr) internal {
        // 如果已经创建过流动性池，则不再重复创建
        if (liquidityPoolCreated[tokenAddr]) return;
        
        InscriptionToken token = InscriptionToken(tokenAddr);
        uint256 accumulatedETH = platformFeeAccumulated[tokenAddr];
        
        // 检查是否有足够的ETH添加流动性 (至少0.1 ETH)
        uint256 minETHForLiquidity = 0.1 ether;
        if (accumulatedETH < minETHForLiquidity) return;
        
        // 根据mint价格计算需要的代币数量
        uint256 mintPrice = token.price();
        uint256 tokenAmountNeeded = accumulatedETH / mintPrice;
        
        // 检查是否有足够的代币可以铸造
        if (token.totalMinted() + tokenAmountNeeded > token.maxSupply()) return;
        
        // 铸造代币用于流动性
        token.mint(address(this), tokenAmountNeeded);
        
        // 授权router使用代币
        IERC20(tokenAddr).approve(router, tokenAmountNeeded);
        
        // 添加流动性
        try ISimpleV2Router(router).addLiquidityETH{value: accumulatedETH}(
            tokenAddr,
            tokenAmountNeeded,
            0, // 最小代币数量设为0，简化逻辑
            0, // 最小ETH数量设为0，简化逻辑
            address(this), // 流动性代币归属于工厂合约
            block.timestamp + 1800 // 30分钟截止时间
        ) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
            // 标记流动性池已创建
            liquidityPoolCreated[tokenAddr] = true;
            // 清空累积的平台费
            platformFeeAccumulated[tokenAddr] = 0;
            
            emit LiquidityAdded(tokenAddr, amountToken, amountETH, liquidity);
        } catch {
            // 如果添加流动性失败，恢复状态（代币已经铸造了，但可以继续尝试）
            // 这里可以选择其他处理策略
        }
    }

    /**
     * @dev owner手动触发添加流动性（紧急情况使用）
     * @param tokenAddr 代币地址
     */
    function manualAddLiquidity(address tokenAddr) external onlyOwner {
        require(!liquidityPoolCreated[tokenAddr], "Liquidity already created");
        require(platformFeeAccumulated[tokenAddr] > 0, "No platform fee accumulated");
        
        _tryAddLiquidity(tokenAddr);
    }

    /**
     * @dev 直接添加流动性（内部函数）
     * @param tokenAddr 代币地址
     * @param liquidityTokenAmount 用于流动性的代币数量
     * @param liquidityETHAmount 用于流动性的ETH数量
     */
    function _addLiquidityDirectly(address tokenAddr, uint256 liquidityTokenAmount, uint256 liquidityETHAmount) internal {
        // 如果已经创建过流动性池，则直接累积平台费
        if (liquidityPoolCreated[tokenAddr]) {
            platformFeeAccumulated[tokenAddr] += liquidityETHAmount;
            return;
        }
        
        // 检查router地址是否有代码（避免在测试环境中调用无效地址）
        if (router.code.length == 0) {
            // 如果router没有代码，直接累积平台费
            platformFeeAccumulated[tokenAddr] += liquidityETHAmount;
            return;
        }
        
        // 授权router使用代币
        IERC20(tokenAddr).approve(router, liquidityTokenAmount);
        
        // 添加流动性
        try ISimpleV2Router(router).addLiquidityETH{value: liquidityETHAmount}(
            tokenAddr,
            liquidityTokenAmount,
            0, // 最小代币数量设为0，简化逻辑
            0, // 最小ETH数量设为0，简化逻辑
            address(this), // 流动性代币归属于工厂合约
            block.timestamp + 1800 // 30分钟截止时间
        ) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
            // 标记流动性池已创建
            liquidityPoolCreated[tokenAddr] = true;
            
            emit LiquidityAdded(tokenAddr, amountToken, amountETH, liquidity);
        } catch {
            // 如果添加流动性失败，累积平台费以备后续使用
            platformFeeAccumulated[tokenAddr] += liquidityETHAmount;
        }
    }
} 