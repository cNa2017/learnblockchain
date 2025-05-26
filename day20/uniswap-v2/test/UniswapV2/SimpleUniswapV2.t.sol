// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../../src/UniswapV2/core/SimpleV2Factory.sol";
import "../../src/UniswapV2/core/SimpleV2Pair.sol";
import "../../src/UniswapV2/periphery/SimpleV2Router.sol";
import "../../src/UniswapV2/test-tokens/TestTokenA.sol";
import "../../src/UniswapV2/test-tokens/TestTokenB.sol";
import "../../src/UniswapV2/test-tokens/TestTokenC.sol";

/**
 * @title SimpleUniswapV2Test
 * @dev 测试简化版Uniswap V2的所有功能
 */
contract SimpleUniswapV2Test is Test {
    SimpleV2Factory public factory;
    SimpleV2Router public router;
    TestTokenA public tokenA;
    TestTokenB public tokenB;
    TestTokenC public tokenC;
    
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 length);

    function setUp() public {
        // 部署工厂合约
        factory = new SimpleV2Factory();
        
        // 部署路由器合约
        router = new SimpleV2Router(address(factory));
        
        // 部署测试代币
        tokenA = new TestTokenA();
        tokenB = new TestTokenB();
        tokenC = new TestTokenC();
        
        // 给用户铸造代币
        tokenA.mint(user1, 1000000 * 10**18);
        tokenB.mint(user1, 1000000 * 10**18);
        tokenC.mint(user1, 1000000 * 10**18);
        
        tokenA.mint(user2, 1000000 * 10**18);
        tokenB.mint(user2, 1000000 * 10**18);
        tokenC.mint(user2, 1000000 * 10**18);
        
        tokenA.mint(user3, 1000000 * 10**18);
        tokenB.mint(user3, 1000000 * 10**18);
        tokenC.mint(user3, 1000000 * 10**18);
        
        console.log("Setup completed");
        console.log("Factory address:", address(factory));
        console.log("Router address:", address(router));
        console.log("TokenA address:", address(tokenA));
        console.log("TokenB address:", address(tokenB));
        console.log("TokenC address:", address(tokenC));
    }

    function test_CreatePair() public {
        // 创建交易对前检查
        assertEq(factory.allPairsLength(), 0);
        assertEq(factory.getPair(address(tokenA), address(tokenB)), address(0));
        
        // 创建交易对
        address pair = factory.createPair(address(tokenA), address(tokenB));
        
        // 验证交易对创建
        assertEq(factory.allPairsLength(), 1);
        assertEq(factory.getPair(address(tokenA), address(tokenB)), pair);
        assertEq(factory.getPair(address(tokenB), address(tokenA)), pair);
        assertEq(factory.allPairs(0), pair);
        
        // 验证交易对初始化
        SimpleV2Pair pairContract = SimpleV2Pair(pair);
        assertEq(pairContract.factory(), address(factory));
        assertEq(pairContract.token0(), address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB));
        assertEq(pairContract.token1(), address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA));
        
        console.log("Pair created successfully at:", pair);
    }

    function test_CannotCreateDuplicatePair() public {
        // 创建第一个交易对
        factory.createPair(address(tokenA), address(tokenB));
        
        // 尝试创建重复交易对应该失败
        vm.expectRevert("SimpleV2: PAIR_EXISTS");
        factory.createPair(address(tokenA), address(tokenB));
        
        vm.expectRevert("SimpleV2: PAIR_EXISTS");
        factory.createPair(address(tokenB), address(tokenA));
        
        console.log("Duplicate pair creation properly prevented");
    }

    function test_AddLiquidity() public {
        vm.startPrank(user1);
        
        // 批准代币
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 2000 * 10**18;
        
        // 添加流动性
        (uint256 actualAmountA, uint256 actualAmountB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            amountA * 95 / 100, // 5% slippage
            amountB * 95 / 100,
            user1,
            block.timestamp + 300
        );
        
        // 验证流动性添加
        assertEq(actualAmountA, amountA);
        assertEq(actualAmountB, amountB);
        assertTrue(liquidity > 0);
        
        // 获取交易对地址
        address pair = factory.getPair(address(tokenA), address(tokenB));
        assertTrue(pair != address(0));
        
        // 验证LP代币余额
        assertEq(SimpleV2Pair(pair).balanceOf(user1), liquidity);
        
        // 验证储备量
        (uint112 reserve0, uint112 reserve1,) = SimpleV2Pair(pair).getReserves();
        assertTrue(reserve0 > 0 && reserve1 > 0);
        
        vm.stopPrank();
        
        console.log("Liquidity added successfully");
        console.log("Amount A:", actualAmountA);
        console.log("Amount B:", actualAmountB);
        console.log("LP tokens:", liquidity);
    }

    function test_RemoveLiquidity() public {
        // 先添加流动性
        test_AddLiquidity();
        
        vm.startPrank(user1);
        
        address pair = factory.getPair(address(tokenA), address(tokenB));
        uint256 liquidity = SimpleV2Pair(pair).balanceOf(user1);
        
        // 批准LP代币
        SimpleV2Pair(pair).approve(address(router), liquidity);
        
        uint256 balanceABefore = tokenA.balanceOf(user1);
        uint256 balanceBBefore = tokenB.balanceOf(user1);
        
        // 移除流动性
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0, // 最小接受数量
            0,
            user1,
            block.timestamp + 300
        );
        
        // 验证代币返回
        assertGt(amountA, 0);
        assertGt(amountB, 0);
        assertEq(tokenA.balanceOf(user1), balanceABefore + amountA);
        assertEq(tokenB.balanceOf(user1), balanceBBefore + amountB);
        
        // 验证LP代币销毁
        assertEq(SimpleV2Pair(pair).balanceOf(user1), 0);
        
        vm.stopPrank();
        
        console.log("Liquidity removed successfully");
        console.log("Returned A:", amountA);
        console.log("Returned B:", amountB);
    }

    function test_SwapExactTokensForTokens() public {
        // 先添加流动性
        test_AddLiquidity();
        
        vm.startPrank(user2);
        
        // 批准代币
        tokenA.approve(address(router), type(uint256).max);
        
        uint256 amountIn = 100 * 10**18;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint256 balanceBBefore = tokenB.balanceOf(user2);
        
        // 执行交换
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0, // 最小输出为0（仅测试）
            path,
            user2,
            block.timestamp + 300
        );
        
        // 验证交换结果
        assertEq(amounts[0], amountIn);
        assertGt(amounts[1], 0);
        assertEq(tokenB.balanceOf(user2), balanceBBefore + amounts[1]);
        
        vm.stopPrank();
        
        console.log("Swap executed successfully");
        console.log("Input amount:", amounts[0]);
        console.log("Output amount:", amounts[1]);
    }

    function test_SwapTokensForExactTokens() public {
        // 先添加流动性
        test_AddLiquidity();
        
        vm.startPrank(user2);
        
        // 批准代币
        tokenA.approve(address(router), type(uint256).max);
        
        uint256 amountOut = 50 * 10**18;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint256 balanceABefore = tokenA.balanceOf(user2);
        uint256 balanceBBefore = tokenB.balanceOf(user2);
        
        // 执行交换
        uint256[] memory amounts = router.swapTokensForExactTokens(
            amountOut,
            type(uint256).max, // 最大输入（仅测试）
            path,
            user2,
            block.timestamp + 300
        );
        
        // 验证交换结果
        assertGt(amounts[0], 0);
        assertEq(amounts[1], amountOut);
        assertEq(tokenA.balanceOf(user2), balanceABefore - amounts[0]);
        assertEq(tokenB.balanceOf(user2), balanceBBefore + amounts[1]);
        
        vm.stopPrank();
        
        console.log("Exact output swap executed successfully");
        console.log("Input amount:", amounts[0]);
        console.log("Output amount:", amounts[1]);
    }

    function test_MultiHopSwap() public {
        // 创建多个交易对并添加流动性
        vm.startPrank(user1);
        
        // 批准所有代币
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenC.approve(address(router), type(uint256).max);
        
        // 创建 A-B 交易对
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 * 10**18,
            1000 * 10**18,
            0, 0, user1, block.timestamp + 300
        );
        
        // 创建 B-C 交易对
        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            1000 * 10**18,
            1000 * 10**18,
            0, 0, user1, block.timestamp + 300
        );
        
        vm.stopPrank();
        
        // 执行多跳交换 A -> B -> C
        vm.startPrank(user3);
        tokenA.approve(address(router), type(uint256).max);
        
        uint256 amountIn = 100 * 10**18;
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        
        uint256 balanceCBefore = tokenC.balanceOf(user3);
        
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            user3,
            block.timestamp + 300
        );
        
        // 验证多跳交换
        assertEq(amounts[0], amountIn);
        assertGt(amounts[1], 0);
        assertGt(amounts[2], 0);
        assertEq(tokenC.balanceOf(user3), balanceCBefore + amounts[2]);
        
        vm.stopPrank();
        
        console.log("Multi-hop swap executed successfully");
        console.log("A -> B -> C");
        console.log("Input A:", amounts[0]);
        console.log("Intermediate B:", amounts[1]);
        console.log("Output C:", amounts[2]);
    }

    function test_GetAmountOut() public {
        uint256 amountIn = 100;
        uint256 reserveIn = 1000;
        uint256 reserveOut = 2000;
        
        uint256 amountOut = router.getAmountOut(amountIn, reserveIn, reserveOut);
        
        // 简化公式：amountOut = (amountIn * reserveOut) / (reserveIn + amountIn)
        uint256 expectedAmountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        
        assertEq(amountOut, expectedAmountOut);
        
        console.log("Amount out calculation verified");
    }

    function test_GetAmountIn() public {
        uint256 amountOut = 100;
        uint256 reserveIn = 1000;
        uint256 reserveOut = 2000;
        
        uint256 amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut);
        
        // 简化公式：amountIn = (reserveIn * amountOut) / (reserveOut - amountOut) + 1
        uint256 expectedAmountIn = (reserveIn * amountOut) / (reserveOut - amountOut) + 1;
        
        assertEq(amountIn, expectedAmountIn);
        
        console.log("Amount in calculation verified");
    }

    function test_RevertConditions() public {
        // 测试创建相同代币交易对失败
        vm.expectRevert("SimpleV2: IDENTICAL_ADDRESSES");
        factory.createPair(address(tokenA), address(tokenA));
        
        // 测试零地址
        vm.expectRevert("SimpleV2: ZERO_ADDRESS");
        factory.createPair(address(0), address(tokenA));
        
        console.log("Revert conditions tested successfully");
    }

    function test_PairDirectMint() public {
        // 创建交易对
        address pair = factory.createPair(address(tokenA), address(tokenB));
        
        vm.startPrank(user1);
        
        // 直接向交易对转移代币
        tokenA.transfer(pair, 1000 * 10**18);
        tokenB.transfer(pair, 2000 * 10**18);
        
        // 调用mint函数
        uint256 liquidity = SimpleV2Pair(pair).mint(user1);
        
        assertGt(liquidity, 0);
        assertEq(SimpleV2Pair(pair).balanceOf(user1), liquidity);
        
        vm.stopPrank();
        
        console.log("Direct pair mint successful");
        console.log("Liquidity minted:", liquidity);
    }

    function test_PairDirectBurn() public {
        // 先执行直接mint
        test_PairDirectMint();
        
        address pair = factory.getPair(address(tokenA), address(tokenB));
        
        vm.startPrank(user1);
        
        uint256 liquidity = SimpleV2Pair(pair).balanceOf(user1);
        
        // 转移LP代币到交易对
        SimpleV2Pair(pair).transfer(pair, liquidity);
        
        uint256 balanceABefore = tokenA.balanceOf(user1);
        uint256 balanceBBefore = tokenB.balanceOf(user1);
        
        // 调用burn函数
        (uint256 amount0, uint256 amount1) = SimpleV2Pair(pair).burn(user1);
        
        assertGt(amount0, 0);
        assertGt(amount1, 0);
        
        vm.stopPrank();
        
        console.log("Direct pair burn successful");
        console.log("Amount0 returned:", amount0);
        console.log("Amount1 returned:", amount1);
    }

    function test_PairDirectSwap() public {
        // 先添加流动性
        test_PairDirectMint();
        
        address pair = factory.getPair(address(tokenA), address(tokenB));
        
        vm.startPrank(user2);
        
        // 向交易对转移输入代币
        uint256 amountIn = 100 * 10**18;
        tokenA.transfer(pair, amountIn);
        
        uint256 balanceBBefore = tokenB.balanceOf(user2);
        
        // 计算输出数量
        (uint112 reserve0, uint112 reserve1,) = SimpleV2Pair(pair).getReserves();
        address token0 = SimpleV2Pair(pair).token0();
        
        uint256 amountOut;
        if (token0 == address(tokenA)) {
            amountOut = router.getAmountOut(amountIn, reserve0, reserve1);
            SimpleV2Pair(pair).swap(0, amountOut, user2, "");
        } else {
            amountOut = router.getAmountOut(amountIn, reserve1, reserve0);
            SimpleV2Pair(pair).swap(amountOut, 0, user2, "");
        }
        
        assertEq(tokenB.balanceOf(user2), balanceBBefore + amountOut);
        
        vm.stopPrank();
        
        console.log("Direct pair swap successful");
        console.log("Amount out:", amountOut);
    }
} 