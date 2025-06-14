// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "../../src/UniswapV2/core/SimpleV2Factory.sol";
import "../../src/UniswapV2/core/WETH.sol";
import "../../src/UniswapV2/periphery/SimpleV2Router.sol";
import "../../src/UniswapV2/test-tokens/TestTokenA.sol";
import "../../src/UniswapV2/test-tokens/TestTokenB.sol";
import "../../src/UniswapV2/test-tokens/TestTokenC.sol";

/**
 * @title DeploySimpleUniswapV2
 * @dev 部署简化版Uniswap V2的所有合约，包括ETH功能
 */
contract DeploySimpleUniswapV2 is Script {
    SimpleV2Factory public factory;
    SimpleV2Router public router;
    WETH public weth;
    TestTokenA public tokenA;
    TestTokenB public tokenB;
    TestTokenC public tokenC;

    function run() external {
        // 尝试从环境变量获取私钥，如果没有则使用默认测试私钥
        uint256 deployerPrivateKey;
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            // 使用Anvil默认测试私钥
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署工厂合约
        factory = new SimpleV2Factory();
        console.log("SimpleV2Factory deployed at:", address(factory));

        // 2. 部署WETH合约
        weth = new WETH();
        console.log("WETH deployed at:", address(weth));

        // 3. 部署路由器合约
        router = new SimpleV2Router(address(factory), address(weth));
        console.log("SimpleV2Router deployed at:", address(router));

        // 4. 部署测试代币
        tokenA = new TestTokenA();
        console.log("TestTokenA deployed at:", address(tokenA));
        console.log("TestTokenA name:", tokenA.name());
        console.log("TestTokenA symbol:", tokenA.symbol());

        tokenB = new TestTokenB();
        console.log("TestTokenB deployed at:", address(tokenB));
        console.log("TestTokenB name:", tokenB.name());
        console.log("TestTokenB symbol:", tokenB.symbol());

        tokenC = new TestTokenC();
        console.log("TestTokenC deployed at:", address(tokenC));
        console.log("TestTokenC name:", tokenC.name());
        console.log("TestTokenC symbol:", tokenC.symbol());

        // 5. 创建交易对（包括ETH交易对）
        console.log("\n=== Creating Pairs ===");
        
        address pairAB = factory.createPair(address(tokenA), address(tokenB));
        console.log("TokenA-TokenB pair created at:", pairAB);

        address pairAC = factory.createPair(address(tokenA), address(tokenC));
        console.log("TokenA-TokenC pair created at:", pairAC);

        address pairBC = factory.createPair(address(tokenB), address(tokenC));
        console.log("TokenB-TokenC pair created at:", pairBC);

        // 创建ETH交易对
        address pairETHA = factory.createPair(address(weth), address(tokenA));
        console.log("WETH-TokenA pair created at:", pairETHA);

        address pairETHB = factory.createPair(address(weth), address(tokenB));
        console.log("WETH-TokenB pair created at:", pairETHB);

        address pairETHC = factory.createPair(address(weth), address(tokenC));
        console.log("WETH-TokenC pair created at:", pairETHC);

        console.log("Total pairs created:", factory.allPairsLength());

        // 6. 给一些测试地址铸造代币
        console.log("\n=== Minting Test Tokens ===");
        
        address[] memory testUsers = new address[](3);
        testUsers[0] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Hardhat测试账户2
        testUsers[1] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Hardhat测试账户3
        testUsers[2] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Hardhat测试账户4

        for (uint256 i = 0; i < testUsers.length; i++) {
            if (testUsers[i] != address(0)) {
                tokenA.mint(testUsers[i], 1000000 * 10**18);
                tokenB.mint(testUsers[i], 1000000 * 10**18);
                tokenC.mint(testUsers[i], 1000000 * 10**18);
                console.log("Minted tokens to:", testUsers[i]);
            }
        }

        // 7. 添加初始流动性（包括ETH流动性）
        console.log("\n=== Adding Initial Liquidity ===");
        
        // 批准路由器使用代币
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenC.approve(address(router), type(uint256).max);

        // 添加 TokenA-TokenB 流动性 (1:2 比例)
        (, , uint256 liquidityAB) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 * 10**18,    // 1000 TokenA
            2000 * 10**18,    // 2000 TokenB
            0,
            0,
            deployer,
            block.timestamp + 300
        );
        console.log("Added TokenA-TokenB liquidity, LP tokens:", liquidityAB);

        // 添加 TokenA-TokenC 流动性 (1:1 比例)
        (, , uint256 liquidityAC) = router.addLiquidity(
            address(tokenA),
            address(tokenC),
            1000 * 10**18,    // 1000 TokenA
            1000 * 10**18,    // 1000 TokenC
            0,
            0,
            deployer,
            block.timestamp + 300
        );
        console.log("Added TokenA-TokenC liquidity, LP tokens:", liquidityAC);

        // 添加 TokenB-TokenC 流动性 (3:1 比例)
        (, , uint256 liquidityBC) = router.addLiquidity(
            address(tokenB),
            address(tokenC),
            3000 * 10**18,    // 3000 TokenB
            1000 * 10**18,    // 1000 TokenC
            0,
            0,
            deployer,
            block.timestamp + 300
        );
        console.log("Added TokenB-TokenC liquidity, LP tokens:", liquidityBC);

        // 添加 ETH-TokenA 流动性
        (, , uint256 liquidityETHA) = router.addLiquidityETH{value: 1 ether}(
            address(tokenA),
            1000 * 10**18,
            0,
            0,
            deployer,
            block.timestamp + 300
        );
        console.log("Added ETH-TokenA liquidity, LP tokens:", liquidityETHA);

        // 添加 ETH-TokenB 流动性
        (, , uint256 liquidityETHB) = router.addLiquidityETH{value: 2 ether}(
            address(tokenB),
            2000 * 10**18,
            0,
            0,
            deployer,
            block.timestamp + 300
        );
        console.log("Added ETH-TokenB liquidity, LP tokens:", liquidityETHB);

        // 添加 ETH-TokenC 流动性
        (, , uint256 liquidityETHC) = router.addLiquidityETH{value: 1.5 ether}(
            address(tokenC),
            1500 * 10**18,
            0,
            0,
            deployer,
            block.timestamp + 300
        );
        console.log("Added ETH-TokenC liquidity, LP tokens:", liquidityETHC);

        vm.stopBroadcast();

        // 8. 输出部署总结
        console.log("\n=== Deployment Summary ===");
        console.log("Factory:", address(factory));
        console.log("WETH:", address(weth));
        console.log("Router:", address(router));
        console.log("TokenA:", address(tokenA));
        console.log("TokenB:", address(tokenB));
        console.log("TokenC:", address(tokenC));
        console.log("Pair AB:", factory.getPair(address(tokenA), address(tokenB)));
        console.log("Pair AC:", factory.getPair(address(tokenA), address(tokenC)));
        console.log("Pair BC:", factory.getPair(address(tokenB), address(tokenC)));
        console.log("Pair ETH-A:", factory.getPair(address(weth), address(tokenA)));
        console.log("Pair ETH-B:", factory.getPair(address(weth), address(tokenB)));
        console.log("Pair ETH-C:", factory.getPair(address(weth), address(tokenC)));

        console.log("\n=== Usage Examples ===");
        console.log("1. Swap TokenA for TokenB:");
        console.log("   router.swapExactTokensForTokens(amount, 0, [tokenA, tokenB], to, deadline)");
        
        console.log("2. Add liquidity:");
        console.log("   router.addLiquidity(tokenA, tokenB, amountA, amountB, minA, minB, to, deadline)");
        
        console.log("3. Multi-hop swap A->B->C:");
        console.log("   router.swapExactTokensForTokens(amount, 0, [tokenA, tokenB, tokenC], to, deadline)");

        console.log("\n=== ETH Trading Examples ===");
        console.log("4. Swap ETH for TokenA:");
        console.log("   router.swapExactETHForTokens{value: ethAmount}(minTokens, [weth, tokenA], to, deadline)");
        
        console.log("5. Swap TokenA for ETH:");
        console.log("   router.swapExactTokensForETH(tokenAmount, minEth, [tokenA, weth], to, deadline)");
        
        console.log("6. Add ETH liquidity:");
        console.log("   router.addLiquidityETH{value: ethAmount}(token, tokenAmount, minToken, minEth, to, deadline)");
        
        console.log("7. Multi-hop ETH->TokenA->TokenB:");
        console.log("   router.swapExactETHForTokens{value: ethAmount}(minTokens, [weth, tokenA, tokenB], to, deadline)");

        // 9. 保存地址到文件（可选）
        _saveDeploymentAddresses();
        
        // 10. 演示价格计算
        _demonstrateCalculations();
    }

    /**
     * @dev 将部署的合约地址保存到文件中
     */
    function _saveDeploymentAddresses() internal {
        string memory deploymentInfo = string.concat(
            "# Simple Uniswap V2 Deployment Addresses\n\n",
            "Factory: ", vm.toString(address(factory)), "\n",
            "WETH: ", vm.toString(address(weth)), "\n",
            "Router: ", vm.toString(address(router)), "\n",
            "TokenA: ", vm.toString(address(tokenA)), "\n",
            "TokenB: ", vm.toString(address(tokenB)), "\n",
            "TokenC: ", vm.toString(address(tokenC)), "\n",
            "Pair AB: ", vm.toString(factory.getPair(address(tokenA), address(tokenB))), "\n",
            "Pair AC: ", vm.toString(factory.getPair(address(tokenA), address(tokenC))), "\n",
            "Pair BC: ", vm.toString(factory.getPair(address(tokenB), address(tokenC))), "\n",
            "Pair ETH-A: ", vm.toString(factory.getPair(address(weth), address(tokenA))), "\n",
            "Pair ETH-B: ", vm.toString(factory.getPair(address(weth), address(tokenB))), "\n",
            "Pair ETH-C: ", vm.toString(factory.getPair(address(weth), address(tokenC))), "\n"
        );

        // vm.writeFile("deployment-addresses.md", deploymentInfo);
        // console.log("\nDeployment addresses saved to deployment-addresses.md");
    }

    /**
     * @dev 演示基本交换功能和ETH相关计算
     */
    function _demonstrateCalculations() internal view {
        console.log("\n=== Swap Demonstration ===");
        
        // 演示如何计算输出
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint256 amountIn = 100 * 10**18;
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);
        
        console.log("Swapping 100 TokenA for TokenB:");
        console.log("Input TokenA:", amounts[0]);
        console.log("Output TokenB:", amounts[1]);
        
        // 演示多跳交换
        address[] memory multiPath = new address[](3);
        multiPath[0] = address(tokenA);
        multiPath[1] = address(tokenB);
        multiPath[2] = address(tokenC);
        
        uint256[] memory multiAmounts = router.getAmountsOut(amountIn, multiPath);
        
        console.log("\nMulti-hop swap 100 TokenA -> TokenB -> TokenC:");
        console.log("Input TokenA:", multiAmounts[0]);
        console.log("Intermediate TokenB:", multiAmounts[1]);
        console.log("Output TokenC:", multiAmounts[2]);

        // 演示ETH相关计算
        console.log("\n=== ETH Price Calculations ===");
        
        // ETH to TokenA
        address[] memory pathETHToA = new address[](2);
        pathETHToA[0] = address(weth);
        pathETHToA[1] = address(tokenA);
        
        uint256 ethAmount = 0.1 ether;
        uint256[] memory amountsETHToA = router.getAmountsOut(ethAmount, pathETHToA);
        console.log("0.1 ETH can buy TokenA:", amountsETHToA[1]);
        
        // TokenA to ETH
        address[] memory pathAToETH = new address[](2);
        pathAToETH[0] = address(tokenA);
        pathAToETH[1] = address(weth);
        
        uint256 tokenAmount = 100 * 10**18;
        uint256[] memory amountsAToETH = router.getAmountsOut(tokenAmount, pathAToETH);
        console.log("100 TokenA can buy ETH:", amountsAToETH[1]);
        
        // 多跳：ETH -> TokenA -> TokenB
        address[] memory pathETHToB = new address[](3);
        pathETHToB[0] = address(weth);
        pathETHToB[1] = address(tokenA);
        pathETHToB[2] = address(tokenB);
        
        uint256[] memory amountsETHToB = router.getAmountsOut(ethAmount, pathETHToB);
        console.log("0.1 ETH -> TokenA -> TokenB final amount:", amountsETHToB[2]);
    }

    /**
     * @dev 演示基本交换功能
     */
    function demonstrateSwap() external view {
        console.log("\n=== Swap Demonstration ===");
        
        // 演示如何计算输出
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint256 amountIn = 100 * 10**18;
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);
        
        console.log("Swapping 100 TokenA for TokenB:");
        console.log("Input TokenA:", amounts[0]);
        console.log("Output TokenB:", amounts[1]);
        
        // 演示多跳交换
        address[] memory multiPath = new address[](3);
        multiPath[0] = address(tokenA);
        multiPath[1] = address(tokenB);
        multiPath[2] = address(tokenC);
        
        uint256[] memory multiAmounts = router.getAmountsOut(amountIn, multiPath);
        
        console.log("\nMulti-hop swap 100 TokenA -> TokenB -> TokenC:");
        console.log("Input TokenA:", multiAmounts[0]);
        console.log("Intermediate TokenB:", multiAmounts[1]);
        console.log("Output TokenC:", multiAmounts[2]);
    }
} 