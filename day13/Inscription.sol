// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";

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
    function initialize(
        string memory symbol,
        uint256 _maxSupply,
        uint256 _perMint,
        uint256 _price,
        address _creator
    ) external initializer {
        factory = msg.sender;
        creator = _creator;
        maxSupply = _maxSupply;
        perMint = _perMint;
        price = _price;
        _tokenSymbol = symbol;
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
    // 平台费率 (1%)
    uint256 public constant PLATFORM_FEE_RATE = 1;
    // 基准费率 (100%)
    uint256 public constant BASE_RATE = 100;
    // 最大铸造成本限制，10^25 wei (约等于10^7 ether)
    // uint256 public constant MAX_MINT_COST = 10000000000000000000000000;
    
    // 实现合约地址
    address public immutable tokenImplementation;
    
    // 事件
    event InscriptionDeployed(address indexed token, address indexed creator, string symbol, uint256 maxSupply, uint256 perMint, uint256 price);
    event InscriptionMinted(address indexed token, address indexed minter, uint256 amount, uint256 paid);

    constructor() Ownable(msg.sender) {
        // 部署实现合约
        tokenImplementation = address(new InscriptionToken());
    }

    /**
     * @dev 部署新的Inscription代币
     * @param symbol 代币符号
     * @param maxSupply 最大供应量
     * @param perMint 每次铸造数量
     * @param price 每个代币价格(wei)
     * @return 新部署的代币地址
     */
    function deployInscription(
        string memory symbol,
        uint256 maxSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        require(maxSupply > 0, "Max supply must be positive");
        require(perMint > 0 && perMint <= maxSupply, "Invalid perMint amount");
        require(price >= 0, "Price cannot be negative");
        
        // 限制铸造成本，避免过高的价格设置
        uint256 mintCost = perMint * price;
        require(mintCost <= type(uint256).max, "Mint cost too high");
        
        // 防止价格溢出
        // require(perMint <= type(uint256).max / price, "Price calculation would overflow");

        // 使用Clones库部署代理合约
        address newToken = Clones.clone(tokenImplementation);
        
        // 初始化代币
        InscriptionToken(newToken).initialize(
            symbol,
            maxSupply,
            perMint,
            price,
            msg.sender
        );
        
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
        
        // 铸造代币
        token.mint(msg.sender, token.perMint());
        
        // 计算费用分配
        uint256 platformFee = (totalPrice * PLATFORM_FEE_RATE) / BASE_RATE;
        uint256 creatorFee = totalPrice - platformFee;
        
        // 分配费用
        (bool platformSuccess, ) = payable(owner()).call{value: platformFee}("");
        require(platformSuccess, "Platform fee transfer failed");
        
        (bool creatorSuccess, ) = payable(token.creator()).call{value: creatorFee}("");
        require(creatorSuccess, "Creator fee transfer failed");
        
        emit InscriptionMinted(tokenAddr, msg.sender, token.perMint(), totalPrice);
    }
} 