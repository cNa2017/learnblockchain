// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StakingPool} from "src/StakingPool/StakingPool.sol";
import {KKToken} from "src/StakingPool/KKToken.sol";

contract StakingPoolTest is Test {
    StakingPool public stakingPool;
    KKToken public kkToken;
    
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    
    uint256 public constant INITIAL_ETH = 100 ether;
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18;
    
    function setUp() public {
        vm.startPrank(owner);
        
        // 部署KK Token
        kkToken = new KKToken();
        
        // 部署StakingPool
        stakingPool = new StakingPool(address(kkToken));
        
        // 将KK Token的所有权转移给StakingPool
        kkToken.transferOwnership(address(stakingPool));
        
        vm.stopPrank();
        
        // 给用户发送ETH
        vm.deal(user1, INITIAL_ETH);
        vm.deal(user2, INITIAL_ETH);
        vm.deal(user3, INITIAL_ETH);
    }
    
    function test_deployment() public view {
        assertEq(address(stakingPool.rewardToken()), address(kkToken));
        assertEq(stakingPool.totalStaked(), 0);
        assertEq(stakingPool.REWARD_PER_BLOCK(), REWARD_PER_BLOCK);
    }
    
    function test_singleUserStake() public {
        uint256 stakeAmount = 1 ether;
        
        vm.startPrank(user1);
        stakingPool.stake{value: stakeAmount}();
        vm.stopPrank();
        
        assertEq(stakingPool.balanceOf(user1), stakeAmount);
        assertEq(stakingPool.totalStaked(), stakeAmount);
        assertEq(address(stakingPool).balance, stakeAmount);
    }
    
    function test_multipleUsersStakingAndRewards() public {
        console.log("Testing multiple users staking and rewards calculation");
        
        // 记录初始区块号
        uint256 startBlock = block.number;
        console.log("Start block:", startBlock);
        
        // User1在区块1质押1 ETH
        vm.startPrank(user1);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
        
        uint256 user1StakeBlock = block.number;
        console.log("User1 staked 1 ETH at block:", user1StakeBlock);
        console.log("User1 balance:", stakingPool.balanceOf(user1) / 1e18, "ETH");
        
        // 前进5个区块
        uint256 timeAdvance1 = block.timestamp + 5 * 12; // 假设每个区块12秒
        vm.warp(timeAdvance1);
        vm.roll(block.number + 5);
        
        console.log("Advanced 5 blocks, current block:", block.number);
        console.log("User1 earned before user2 stakes:", stakingPool.earned(user1) / 1e18, "KK");
        
        // User2在区块6质押2 ETH
        vm.startPrank(user2);
        stakingPool.stake{value: 2 ether}();
        vm.stopPrank();
        
        uint256 user2StakeBlock = block.number;
        console.log("User2 staked 2 ETH at block:", user2StakeBlock);
        console.log("User2 balance:", stakingPool.balanceOf(user2) / 1e18, "ETH");
        console.log("Total staked:", stakingPool.totalStaked() / 1e18, "ETH");
        
        // 前进3个区块
        uint256 timeAdvance2 = block.timestamp + 3 * 12;
        vm.warp(timeAdvance2);
        vm.roll(block.number + 3);
        
        console.log("Advanced 3 more blocks, current block:", block.number);
        console.log("User1 earned before user3 stakes:", stakingPool.earned(user1) / 1e18, "KK");
        console.log("User2 earned before user3 stakes:", stakingPool.earned(user2) / 1e18, "KK");
        
        // User3在区块9质押3 ETH
        vm.startPrank(user3);
        stakingPool.stake{value: 3 ether}();
        vm.stopPrank();
        
        uint256 user3StakeBlock = block.number;
        console.log("User3 staked 3 ETH at block:", user3StakeBlock);
        console.log("User3 balance:", stakingPool.balanceOf(user3) / 1e18, "ETH");
        console.log("Total staked:", stakingPool.totalStaked() / 1e18, "ETH");
        
        // 前进10个区块，让所有用户一起获得奖励
        uint256 timeAdvance3 = block.timestamp + 10 * 12;
        vm.warp(timeAdvance3);
        vm.roll(block.number + 10);
        
        console.log("Advanced 10 more blocks, current block:", block.number);
        
        // 计算各用户的收益
        uint256 user1Earned = stakingPool.earned(user1);
        uint256 user2Earned = stakingPool.earned(user2);
        uint256 user3Earned = stakingPool.earned(user3);
        
        console.log("Final earnings:");
        console.log("User1 earned:", user1Earned / 1e18, "KK");
        console.log("User2 earned:", user2Earned / 1e18, "KK");
        console.log("User3 earned:", user3Earned / 1e18, "KK");
        console.log("Total earned:", (user1Earned + user2Earned + user3Earned) / 1e18, "KK");
        
        // 验证奖励分配的合理性
        // User1应该获得最多奖励（质押时间最长）
        assertGt(user1Earned, user2Earned, "User1 should earn more than User2");
        assertGt(user1Earned, user3Earned, "User1 should earn more than User3");
        
        // 总奖励应该大于0
        assertGt(user1Earned + user2Earned + user3Earned, 0, "Total rewards should be positive");
    }
    
    function test_claimRewards() public {
        // User1质押
        vm.startPrank(user1);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
        
        // 前进几个区块
        uint256 timeAdvance = block.timestamp + 5 * 12;
        vm.warp(timeAdvance);
        vm.roll(block.number + 5);
        
        // 检查收益
        uint256 earnedBefore = stakingPool.earned(user1);
        assertGt(earnedBefore, 0, "Should have earned rewards");
        
        // 领取奖励
        vm.startPrank(user1);
        stakingPool.claim();
        vm.stopPrank();
        
        // 验证领取后的状态
        assertEq(stakingPool.earned(user1), 0, "Should have no pending rewards after claim");
        assertEq(kkToken.balanceOf(user1), earnedBefore, "Should receive KK tokens");
    }
    
    function test_unstake() public {
        uint256 stakeAmount = 2 ether;
        uint256 unstakeAmount = 1 ether;
        
        // User1质押
        vm.startPrank(user1);
        stakingPool.stake{value: stakeAmount}();
        vm.stopPrank();
        
        uint256 balanceBefore = user1.balance;
        
        // 前进几个区块
        uint256 timeAdvance = block.timestamp + 3 * 12;
        vm.warp(timeAdvance);
        vm.roll(block.number + 3);
        
        // 取消质押
        vm.startPrank(user1);
        stakingPool.unstake(unstakeAmount);
        vm.stopPrank();
        
        // 验证状态
        assertEq(stakingPool.balanceOf(user1), stakeAmount - unstakeAmount, "Staked amount should decrease");
        assertEq(user1.balance, balanceBefore + unstakeAmount, "Should receive ETH back");
        assertEq(stakingPool.totalStaked(), stakeAmount - unstakeAmount, "Total staked should decrease");
    }
    
    function test_rewardCalculationAccuracy() public {
        console.log("Testing reward calculation accuracy");
        
        // User1质押1 ETH
        vm.startPrank(user1);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
        
        uint256 startBlock = block.number;
        console.log("User1 staked at block:", startBlock);
        
        // 前进1个区块
        uint256 timeAdvance1 = block.timestamp + 12;
        vm.warp(timeAdvance1);
        vm.roll(block.number + 1);
        
        // 应该获得10个KK Token（1个区块的奖励）
        uint256 expectedReward1 = REWARD_PER_BLOCK;
        uint256 actualReward1 = stakingPool.earned(user1);
        
        console.log("After 1 block:");
        console.log("Expected reward:", expectedReward1 / 1e18, "KK");
        console.log("Actual reward:", actualReward1 / 1e18, "KK");
        
        assertEq(actualReward1, expectedReward1, "Reward after 1 block should be 10 KK");
        
        // User2加入，质押1 ETH
        vm.startPrank(user2);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
        
        console.log("User2 staked at block:", block.number);
        
        // 前进2个区块
        uint256 timeAdvance2 = block.timestamp + 24;
        vm.warp(timeAdvance2);
        vm.roll(block.number + 2);
        
        // 现在有2个用户，每个用户质押相同数量，所以奖励应该平均分配
        uint256 user1Reward = stakingPool.earned(user1);
        uint256 user2Reward = stakingPool.earned(user2);
        
        console.log("After user2 joins and 2 more blocks:");
        console.log("User1 total reward:", user1Reward / 1e18, "KK");
        console.log("User2 total reward:", user2Reward / 1e18, "KK");
        
        // User1应该有：10（前1个区块的奖励）+ 10（2个区块奖励的一半）= 20 KK
        // User2应该有：10（2个区块奖励的一半）= 10 KK
        uint256 expectedUser1Reward = 20 * 1e18;
        uint256 expectedUser2Reward = 10 * 1e18;
        
        assertEq(user1Reward, expectedUser1Reward, "User1 should have 20 KK tokens");
        assertEq(user2Reward, expectedUser2Reward, "User2 should have 10 KK tokens");
    }
    
    function test_noRewardsWhenNotStaked() public {
        // 前进几个区块
        uint256 timeAdvance = block.timestamp + 5 * 12;
        vm.warp(timeAdvance);
        vm.roll(block.number + 5);
        
        // 没有质押应该没有奖励
        assertEq(stakingPool.earned(user1), 0, "Should have no rewards when not staked");
    }
    
    function test_revertOnZeroStake() public {
        vm.startPrank(user1);
        vm.expectRevert("Cannot stake 0 ETH");
        stakingPool.stake{value: 0}();
        vm.stopPrank();
    }
    
    function test_revertOnInsufficientUnstake() public {
        vm.startPrank(user1);
        stakingPool.stake{value: 1 ether}();
        
        vm.expectRevert("Insufficient staked amount");
        stakingPool.unstake(2 ether);
        vm.stopPrank();
    }
    
    function test_revertOnClaimWithNoRewards() public {
        vm.startPrank(user1);
        vm.expectRevert("No rewards to claim");
        stakingPool.claim();
        vm.stopPrank();
    }
} 