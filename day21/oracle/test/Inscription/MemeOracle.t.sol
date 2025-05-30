// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 导入核心合约
import "../../src/Inscription/Inscription.sol";
import "../../src/Inscription/MemeOracle.sol";

// 导入 UniswapV2 相关合约
import "../../src/UniswapV2/core/SimpleV2Factory.sol";
import "../../src/UniswapV2/core/SimpleV2Pair.sol";
import "../../src/UniswapV2/core/WETH.sol";
import "../../src/UniswapV2/periphery/SimpleV2Router.sol";

/**
 * @title MemeOracleTest
 * @dev 测试 MemeOracle 合约的 TWAP 价格监控功能
 */
contract MemeOracleTest is Test {
    // 合约实例
    InscriptionFactory public factory;
    MemeOracle public oracle;
    SimpleV2Factory public uniswapFactory;
    SimpleV2Router public router;
    WETH public weth;
    
    // 测试代币
    InscriptionToken public memeToken;
    address public memeTokenAddress;
    
    // 测试账户
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    
    // 测试常量
    uint256 constant INITIAL_ETH_BALANCE = 100 ether;
    uint256 constant MEME_MAX_SUPPLY = 1000000e18; // 100万枚
    uint256 constant MEME_PER_MINT = 1e18;        // 每次铸造1枚
    uint256 constant MEME_PRICE = 1;             // 每枚 1 wei

    // 接收 ETH 的函数
    receive() external payable {}

    function setUp() public {
        // 设置测试账户
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        // 给测试账户分配 ETH
        vm.deal(owner, INITIAL_ETH_BALANCE);
        vm.deal(user1, INITIAL_ETH_BALANCE);
        vm.deal(user2, INITIAL_ETH_BALANCE);
        vm.deal(user3, INITIAL_ETH_BALANCE);
        
        // 部署 WETH
        weth = new WETH();
        
        // 部署 Uniswap V2 工厂和路由器
        uniswapFactory = new SimpleV2Factory();
        router = new SimpleV2Router(address(uniswapFactory), address(weth));
        
        // 部署 InscriptionFactory
        factory = new InscriptionFactory(
            address(router),
            address(uniswapFactory), 
            address(weth)
        );
        
        // 部署 MemeOracle
        oracle = new MemeOracle(address(uniswapFactory), address(weth));
        
        console.log("Setup completed:");
        console.log("WETH:", address(weth));
        console.log("UniswapFactory:", address(uniswapFactory));
        console.log("Router:", address(router));
        console.log("InscriptionFactory:", address(factory));
        console.log("MemeOracle:", address(oracle));
    }

    function test_deployMemeToken() public {
        // 部署 Meme 代币
        memeTokenAddress = factory.deployInscription(
            "MEME1",
            MEME_MAX_SUPPLY,
            MEME_PER_MINT,
            MEME_PRICE
        );
        
        memeToken = InscriptionToken(memeTokenAddress);
        
        
        // 验证代币基本信息
        assertEq(memeToken.symbol(), "MEME1");
        assertEq(memeToken.maxSupply(), MEME_MAX_SUPPLY);
        assertEq(memeToken.perMint(), MEME_PER_MINT);
        assertEq(memeToken.price(), MEME_PRICE);
        
        console.log("Meme token deployed:", memeTokenAddress);
        
    }

    function test_createLiquidityAndRegisterToken() public {
        // 先部署代币
        test_deployMemeToken();
        
        // 用户铸造代币并创建流动性
        uint256 mintCost = memeToken.calcMintCost();
        console.log("Mint cost:", mintCost);
        
        // 用户1铸造代币多次，累积足够的平台费用来创建流动性
        vm.startPrank(user1);
        for (uint256 i = 0; i < 10; i++) {
            factory.mintInscription{value: mintCost}(memeTokenAddress);
        }
        vm.stopPrank();

        
        // 检查是否有交易对创建
        address pair = uniswapFactory.getPair(memeTokenAddress, address(weth));
        console.log("Pair address:", pair);
        
        if (pair != address(0)) {
            // 注册代币到预言机
            oracle.registerToken(memeTokenAddress);
            console.log("Token registered to oracle");
            
            // 验证注册状态
            assertTrue(oracle.isTokenRegistered(memeTokenAddress));
            assertEq(oracle.getRegisteredTokenCount(), 1);
            assertEq(oracle.getRegisteredToken(0), memeTokenAddress);
        } else {
            console.log("Pair not created yet, need more trading activity");
        }
    }

    function test_simulateMultipleTradesAndTWAP() public {
        // 先创建流动性和注册代币
        test_createLiquidityAndRegisterToken();
        
        address pair = uniswapFactory.getPair(memeTokenAddress, address(weth));
        if (pair == address(0)) {
            console.log("No pair exists, skipping TWAP test");
            return;
        }
        
        console.log("=== Starting TWAP simulation ===");
        
        // 获取初始价格
        (uint256 initialSpotPrice,) = oracle.getSpotPrice(memeTokenAddress);
        console.log("Initial spot price:", initialSpotPrice);
        
        // 模拟多个时间点的交易
        _simulateTradeAtTime(1 hours, user1, 1 ether, true);   // 1小时后，买入
        _simulateTradeAtTime(2 hours, user2, 0.5 ether, true); // 2小时后，买入
        _simulateTradeAtTime(4 hours, user3, 2 ether, false);  // 4小时后，卖出
        _simulateTradeAtTime(6 hours, user1, 0.8 ether, true); // 6小时后，买入
        _simulateTradeAtTime(8 hours, user2, 1.5 ether, false); // 8小时后，卖出
        _simulateTradeAtTime(12 hours, user3, 1 ether, true);   // 12小时后，买入
        _simulateTradeAtTime(18 hours, user1, 0.3 ether, false); // 18小时后，卖出
        _simulateTradeAtTime(24 hours, user2, 2.5 ether, true);  // 24小时后，买入
        
        console.log("=== TWAP simulation completed ===");
    }

    function _simulateTradeAtTime(uint256 timeOffset, address trader, uint256 ethAmount, bool buyMeme) internal {
        // 前进时间
        vm.warp(block.timestamp + timeOffset);
        console.log("Time advanced to:", block.timestamp);
        
        // 更新预言机价格
        try oracle.updatePrice(memeTokenAddress) {
            (uint256 twapPrice, uint32 lastUpdate) = oracle.getPrice(memeTokenAddress);
            console.log("TWAP price updated:", twapPrice, "at time:", lastUpdate);
        } catch {
            console.log("TWAP price update failed (first time is expected)");
        }
        
        // 获取即时价格
        (uint256 spotPrice,) = oracle.getSpotPrice(memeTokenAddress);
        console.log("Current spot price:", spotPrice);
        
        // 执行交易
        vm.startPrank(trader);
        
        if (buyMeme) {
            console.log("User buying meme with", ethAmount, "ETH");
            _buyMemeTokens(trader, ethAmount);
        } else {
            console.log("User selling meme tokens worth", ethAmount, "ETH");
            _sellMemeTokens(trader, ethAmount);
        }
        
        vm.stopPrank();
        
        // 获取交易后的价格
        (uint256 newSpotPrice,) = oracle.getSpotPrice(memeTokenAddress);
        console.log("New spot price after trade:", newSpotPrice);
        console.log("Price change:", newSpotPrice > spotPrice ? "+" : "-", 
                   newSpotPrice > spotPrice ? newSpotPrice - spotPrice : spotPrice - newSpotPrice);
        console.log("---");
    }

    function _buyMemeTokens(address buyer, uint256 ethAmount) internal {
        // 将 ETH 转换为 WETH
        weth.deposit{value: ethAmount}();
        
        // 授权路由器使用 WETH
        IERC20(address(weth)).approve(address(router), ethAmount);
        
        // 通过 Uniswap 购买 Meme 代币
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = memeTokenAddress;
        
        try router.swapExactTokensForTokens(
            ethAmount,
            0, // 最小输出设为0
            path,
            buyer,
            block.timestamp + 300 // 使用当前时间戳 + 5分钟
        ) {
            console.log("Buy trade successful");
        } catch {
            console.log("Buy trade failed");
        }
    }

    function _sellMemeTokens(address seller, uint256 ethValueEquivalent) internal {
        // 获取当前价格来计算需要卖出的代币数量
        (uint256 spotPrice,) = oracle.getSpotPrice(memeTokenAddress);
        uint256 memeAmount = (ethValueEquivalent * 1e18) / spotPrice;
        
        uint256 sellerBalance = IERC20(memeTokenAddress).balanceOf(seller);
        if (sellerBalance < memeAmount) {
            console.log("Insufficient meme token balance, using available:", sellerBalance);
            memeAmount = sellerBalance;
        }
        
        if (memeAmount == 0) {
            console.log("No meme tokens to sell");
            return;
        }
        
        // 授权路由器使用 Meme 代币
        IERC20(memeTokenAddress).approve(address(router), memeAmount);
        
        // 通过 Uniswap 卖出 Meme 代币
        address[] memory path = new address[](2);
        path[0] = memeTokenAddress;
        path[1] = address(weth);
        
        try router.swapExactTokensForTokens(
            memeAmount,
            0, // 最小输出设为0
            path,
            seller,
            block.timestamp + 300 // 使用当前时间戳 + 5分钟
        ) {
            console.log("Sell trade successful, sold:", memeAmount);
        } catch {
            console.log("Sell trade failed");
        }
    }

    function test_priceConsultation() public {
        // 先完成完整的交易模拟
        test_simulateMultipleTradesAndTWAP();
        
        address pair = uniswapFactory.getPair(memeTokenAddress, address(weth));
        if (pair == address(0)) {
            console.log("No pair exists, skipping consultation test");
            return;
        }
        
        console.log("=== Testing price consultation ===");
        
        // 测试价格咨询功能
        uint256 wethAmount = 1 ether;
        
        try oracle.consultPrice(memeTokenAddress, wethAmount) returns (uint256 tokenAmount, uint32) {
            console.log("Consultation: 1 WETH =", tokenAmount, "MEME tokens");
            
            (uint256 twapPrice,) = oracle.getPrice(memeTokenAddress);
            uint256 expectedAmount = (wethAmount * 1e18) / twapPrice;
            
            assertEq(tokenAmount, expectedAmount, "Consultation result mismatch");
        } catch {
            console.log("Price consultation failed - TWAP may not be initialized");
        }
    }

    function test_batchPriceUpdate() public {
        // 部署多个 Meme 代币
        address meme1 = factory.deployInscription("MEME1", MEME_MAX_SUPPLY, MEME_PER_MINT, MEME_PRICE);
        address meme2 = factory.deployInscription("MEME2", MEME_MAX_SUPPLY, MEME_PER_MINT, MEME_PRICE);
        
        // 为每个代币创建流动性（简化处理）
        uint256 mintCost = MEME_PER_MINT * MEME_PRICE;
        
        // 为 MEME1 创建流动性
        vm.startPrank(user1);
        for (uint256 i = 0; i < 10; i++) {
            factory.mintInscription{value: mintCost}(meme1);
        }
        vm.stopPrank();
        
        // 为 MEME2 创建流动性
        vm.startPrank(user2);
        for (uint256 i = 0; i < 10; i++) {
            factory.mintInscription{value: mintCost}(meme2);
        }
        vm.stopPrank();
        
        // 注册代币到预言机
        address pair1 = uniswapFactory.getPair(meme1, address(weth));
        address pair2 = uniswapFactory.getPair(meme2, address(weth));
        
        if (pair1 != address(0)) {
            oracle.registerToken(meme1);
            console.log("MEME1 registered");
        }
        
        if (pair2 != address(0)) {
            oracle.registerToken(meme2);
            console.log("MEME2 registered");
        }
        
        // 前进时间
        vm.warp(block.timestamp + 1 hours);
        
        // 批量更新价格
        console.log("Updating all prices...");
        oracle.updateAllPrices();
        
        console.log("Batch update completed");
        assertGe(oracle.getRegisteredTokenCount(), 1);
    }

    function test_emergencyPriceUpdate() public {
        // 先创建基本设置
        test_createLiquidityAndRegisterToken();
        
        address pair = uniswapFactory.getPair(memeTokenAddress, address(weth));
        if (pair == address(0)) {
            console.log("No pair exists, skipping emergency test");
            return;
        }
        
        console.log("=== Testing emergency price update ===");
        
        // 获取当前即时价格
        (uint256 spotPrice,) = oracle.getSpotPrice(memeTokenAddress);
        console.log("Current spot price:", spotPrice);
        
        // 执行紧急价格更新
        oracle.emergencyUpdateSpotPrice(memeTokenAddress);
        
        // 验证价格已更新
        (uint256 twapPrice,) = oracle.getPrice(memeTokenAddress);
        assertEq(twapPrice, spotPrice, "Emergency price update failed");
        
        console.log("Emergency update successful, TWAP price:", twapPrice);
    }

    function test_priceAccuracy() public {
        // 完成基本设置
        test_createLiquidityAndRegisterToken();
        
        address pair = uniswapFactory.getPair(memeTokenAddress, address(weth));
        if (pair == address(0)) {
            console.log("No pair exists, skipping accuracy test");
            return;
        }
        (uint256 twapPrice1Original,uint32 time1Original) = oracle.getPrice(memeTokenAddress);
        console.log("TWAP twapPrice1Original:", twapPrice1Original,time1Original);
        
        (uint256 spotPrice0,uint32 time0) = oracle.getSpotPrice(memeTokenAddress);
        console.log("Spot price after trade 0:", spotPrice0,time0);
        // 前进时间并执行交易（确保足够的时间间隔）
        vm.warp(block.timestamp + 5 minutes); // 使用5分钟，远超最小间隔
        
        // 手动同步交易对时间戳，确保交易对的时间戳与当前时间一致
        // SimpleV2Pair(pair).sync();

        vm.startPrank(user1);
        _buyMemeTokens(user1, 0.1 ether);
        vm.stopPrank();
        
        (uint256 spotPrice1,uint32 time1) = oracle.getSpotPrice(memeTokenAddress);
        console.log("Spot price after trade 1:", spotPrice1,time1);
        
        // 更新 TWAP
        oracle.updatePrice(memeTokenAddress);
        (uint256 twapPrice1,uint32 time2) = oracle.getPrice(memeTokenAddress);
        console.log("TWAP price 1:", twapPrice1,time2);
        
        // 再次前进时间并交易（确保足够的时间间隔）
        vm.warp(block.timestamp + 10 minutes); // 再增加5分钟
        console.log("Time advanced to:", block.timestamp);
        // 在交易前先手动同步时间戳，这样交易后时间戳会被更新
 
        vm.startPrank(user2);
        _buyMemeTokens(user2, 0.2 ether);
        vm.stopPrank();

        // 更新 TWAP
        oracle.updatePrice(memeTokenAddress);

        
        (uint256 spotPrice2,uint32 time3) = oracle.getSpotPrice(memeTokenAddress);
        console.log("Spot price after trade 2:", spotPrice2,time3);
        vm.warp(block.timestamp + 15 minutes); // 再增加5分钟
        
        // 更新 TWAP
        oracle.updatePrice(memeTokenAddress);
        (uint256 finalTwapPrice,uint32 time4) = oracle.getPrice(memeTokenAddress);
        console.log("Final TWAP price:", finalTwapPrice,time4);
        
        // 验证 TWAP 价格的合理性
        assertTrue(finalTwapPrice > 0, "TWAP price should be positive");
    }

    // 测试边缘情况
    function test_edgeCases() public {
        test_deployMemeToken();
        
        console.log("=== Testing edge cases ===");
        
        // 测试未注册代币
        vm.expectRevert("MemeOracle: TOKEN_NOT_REGISTERED");
        oracle.getPrice(memeTokenAddress);
        
        // 测试重复注册
        address pair = uniswapFactory.getPair(memeTokenAddress, address(weth));
        if (pair != address(0)) {
            oracle.registerToken(memeTokenAddress);
            
            vm.expectRevert("MemeOracle: ALREADY_REGISTERED");
            oracle.registerToken(memeTokenAddress);
        }
        
        console.log("Edge case tests passed");
    }
} 