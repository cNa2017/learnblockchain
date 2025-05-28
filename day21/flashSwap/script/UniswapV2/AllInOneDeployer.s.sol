// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// 导入需要部署的合约
import "../../src/UniswapV2/core/SimpleV2Factory.sol";
import "../../src/UniswapV2/core/SimpleV2Pair.sol";
import "../../src/UniswapV2/periphery/SimpleV2Router.sol";
import "../../src/UniswapV2/core/WETH.sol";
import "../../src/UniswapV2/test-tokens/TestTokenA.sol";
import "../../src/UniswapV2/test-tokens/TestTokenB.sol";
import "../../src/UniswapV2/flash-swap/RealFlashSwapArbitrage.sol";

/**
 * @title AllInOneDeployer
 * @dev 精简版部署+套利合约 - 保留核心套利功能，最小化字节码
 */
contract AllInOneDeployer {
    // 部署的合约实例
    SimpleV2Factory public factoryA;
    SimpleV2Factory public factoryB;
    SimpleV2Router public routerA;
    SimpleV2Router public routerB;
    WETH public wethA;
    WETH public wethB;
    TestTokenA public tokenA;
    TestTokenB public tokenB;
    RealFlashSwapArbitrage public realArbitrage;

    // 交易对地址
    address public pairA_AB;
    address public pairB_AB;

    // 部署者地址
    address public deployer;
    bool public initialized;

    // 常量
    uint256 public constant INITIAL_LIQUIDITY_A = 1000 * 10**18;
    uint256 public constant INITIAL_LIQUIDITY_B_FACTORY_A = 2000 * 10**18;
    uint256 public constant INITIAL_LIQUIDITY_B_FACTORY_B = 1500 * 10**18;
    uint256 public constant MIN_PROFIT_THRESHOLD = 0.001 * 10**18;

    /**
     * @dev 构造函数 - 只部署核心基础设施
     */
    constructor() {
        deployer = msg.sender;
        wethA = new WETH();
        wethB = new WETH();
        factoryA = new SimpleV2Factory();
        factoryB = new SimpleV2Factory();
        routerA = new SimpleV2Router(address(factoryA), address(wethA));
        routerB = new SimpleV2Router(address(factoryB), address(wethB));
    }

    /**
     * @dev 完成所有部署和初始化
     */
    function initializeLiquidity() external {
        require(msg.sender == deployer && !initialized, "Access denied or already initialized");
        
        // 部署代币
        tokenA = new TestTokenA();
        tokenB = new TestTokenB();
        tokenA.mint(deployer, INITIAL_LIQUIDITY_A * 5);
        tokenB.mint(deployer, INITIAL_LIQUIDITY_B_FACTORY_A * 5);

        // 部署套利合约
        realArbitrage = new RealFlashSwapArbitrage(
            address(factoryA), address(factoryB), address(routerA), address(routerB)
        );

        // 创建交易对
        pairA_AB = factoryA.createPair(address(tokenA), address(tokenB));
        pairB_AB = factoryB.createPair(address(tokenA), address(tokenB));

        // 授权和添加流动性
        tokenA.approve(address(routerA), type(uint256).max);
        tokenB.approve(address(routerA), type(uint256).max);
        tokenA.approve(address(routerB), type(uint256).max);
        tokenB.approve(address(routerB), type(uint256).max);

        routerA.addLiquidity(
            address(tokenA), address(tokenB),
            INITIAL_LIQUIDITY_A, INITIAL_LIQUIDITY_B_FACTORY_A,
            0, 0, deployer, block.timestamp + 300
        );
        
        routerB.addLiquidity(
            address(tokenA), address(tokenB),
            INITIAL_LIQUIDITY_A, INITIAL_LIQUIDITY_B_FACTORY_B,
            0, 0, deployer, block.timestamp + 300
        );

        initialized = true;
    }

    /**
     * @dev 检查套利机会
     */
    function checkArbitrageOpportunity() external view returns (bool hasOpportunity, bool borrowFromA, uint256 expectedProfit) {
        return realArbitrage.checkArbitrageOpportunity(address(tokenA), address(tokenB));
    }

    /**
     * @dev 自动执行套利 - 核心功能
     */
    function autoExecuteArbitrage() external {
        require(msg.sender == deployer, "Only deployer");
        
        (bool hasOpportunity, bool borrowFromA, uint256 expectedProfit) = 
            realArbitrage.checkArbitrageOpportunity(address(tokenA), address(tokenB));

        console.log("hasOpportunity", hasOpportunity);
        console.log("borrowFromA", borrowFromA);
        console.log("expectedProfit", expectedProfit);
        if (!hasOpportunity || expectedProfit < MIN_PROFIT_THRESHOLD) return;
        
        uint256 borrowAmount = _calculateBorrowAmount(expectedProfit);

        console.log("executeArbitrage.borrowAmount", borrowAmount);
        realArbitrage.executeArbitrage(address(tokenA), address(tokenB), borrowAmount, borrowFromA);
        console.log("executeArbitrage success");
    }

    /**
     * @dev 手动执行套利
     */
    function executeArbitrage(uint256 borrowAmount, bool borrowFromA) external {
        require(msg.sender == deployer, "Only deployer");
        realArbitrage.executeArbitrage(address(tokenA), address(tokenB), borrowAmount, borrowFromA);
    }

    /**
     * @dev 计算借贷金额
     */
    function _calculateBorrowAmount(uint256 expectedProfit) internal pure returns (uint256) {
        if (expectedProfit >= 10 * 10**18) return 100 * 10**18;
        if (expectedProfit >= 1 * 10**18) return 50 * 10**18;
        if (expectedProfit >= 0.1 * 10**18) return 10 * 10**18;
        if (expectedProfit >= 0.01 * 10**18) return 1 * 10**18;
        return 0.1 * 10**18;
    }

    /**
     * @dev 获取所有地址
     */
    function getAllAddresses() external view returns (
        address _factoryA, address _factoryB, address _routerA, address _routerB,
        address _wethA, address _wethB, address _tokenA, address _tokenB,
        address _pairA_AB, address _pairB_AB, address _realArbitrage
    ) {
        return (
            address(factoryA), address(factoryB), address(routerA), address(routerB),
            address(wethA), address(wethB), address(tokenA), address(tokenB),
            pairA_AB, pairB_AB, address(realArbitrage)
        );
    }

    /**
     * @dev 转移套利合约所有权
     */
    function transferArbitrageOwnership(address newOwner) external {
        require(msg.sender == deployer && newOwner != address(0), "Access denied or invalid address");
        realArbitrage.transferOwnership(newOwner);
    }

    /**
     * @dev 获取状态
     */
    function getStatus() external view returns (bool _initialized, address _arbitrage) {
        return (initialized, address(realArbitrage));
    }
}

/**
 * @title DeployAllInOne
 * @dev 精简部署脚本 - 最小化字节码
 * 使用方法：
 * forge script --keystore key/cnaWalletKeySet --rpc-url sepolia --broadcast script/UniswapV2/AllInOneDeployer.s.sol:DeployAllInOne
 */
contract DeployAllInOne is Script {
    AllInOneDeployer public deployer;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        require(deployerAddress.balance > 0.02 ether, "Insufficient ETH balance");
        
        vm.startBroadcast(deployerPrivateKey);

        // 部署核心基础设施
        deployer = new AllInOneDeployer();
        
        // 完成系统初始化
        deployer.initializeLiquidity();
        
        deployer.autoExecuteArbitrage();

        vm.stopBroadcast();

        console.log("AllInOneDeployer deployed at:", address(deployer));
        console.log("System initialized:", deployer.initialized());
    }
} 