// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StakingPool} from "src/StakingPool/StakingPool.sol";
import {KKToken} from "src/StakingPool/KKToken.sol";

contract StakingPoolDetailedTest is Test {
    StakingPool public stakingPool;
    KKToken public kkToken;
    
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18;
    
    function setUp() public {
        vm.startPrank(owner);
        
        // 部署合约
        kkToken = new KKToken();
        stakingPool = new StakingPool(address(kkToken));
        kkToken.transferOwnership(address(stakingPool));
        
        vm.stopPrank();
        
        // 给用户发送ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }
    
    function test_detailedRewardCalculation() public {
        console.log("=== Detailed Reward Calculation Test ===");
        console.log("Each block generates 10 KK tokens");
        console.log("Rewards are distributed proportionally to staked amount");
        console.log("");
        
        uint256 startBlock = block.number;
        console.log("Starting at block:", startBlock);
        
        // 阶段1: Alice质押1 ETH (区块1)
        console.log("--- Phase 1: Alice stakes 1 ETH ---");
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
        
        uint256 aliceStakeBlock = block.number;
        console.log("Alice staked 1 ETH at block:", aliceStakeBlock);
        console.log("Total staked:", stakingPool.totalStaked() / 1e18, "ETH");
        console.log("Alice's share: 100%");
        console.log("");
        
        // 前进3个区块 (区块2-4)
        console.log("--- Advancing 3 blocks (Alice earns alone) ---");
        uint256 timeAdvance1 = block.timestamp + 3 * 12;
        vm.warp(timeAdvance1);
        vm.roll(block.number + 3);
        
        uint256 aliceEarned1 = stakingPool.earned(alice);
        console.log("After 3 blocks (block", block.number, "):");
        console.log("Alice earned:", aliceEarned1 / 1e18, "KK (should be 30 KK)");
        console.log("Calculation: 3 blocks * 10 KK/block * 100% share = 30 KK");
        console.log("");
        
        // 阶段2: Bob质押2 ETH (区块5)
        console.log("--- Phase 2: Bob stakes 2 ETH ---");
        vm.startPrank(bob);
        stakingPool.stake{value: 2 ether}();
        vm.stopPrank();
        
        uint256 bobStakeBlock = block.number;
        console.log("Bob staked 2 ETH at block:", bobStakeBlock);
        console.log("Total staked:", stakingPool.totalStaked() / 1e18, "ETH");
        console.log("Alice's share: 1/3 = 33.33%");
        console.log("Bob's share: 2/3 = 66.67%");
        console.log("");
        
        // 前进2个区块 (区块6-7)
        console.log("--- Advancing 2 blocks (Alice and Bob share rewards) ---");
        uint256 timeAdvance2 = block.timestamp + 2 * 12;
        vm.warp(timeAdvance2);
        vm.roll(block.number + 2);
        
        uint256 aliceEarned2 = stakingPool.earned(alice);
        uint256 bobEarned2 = stakingPool.earned(bob);
        console.log("After 2 more blocks (block", block.number, "):");
        console.log("Alice total earned:", aliceEarned2 / 1e18, "KK");
        console.log("  - Previous: 30 KK");
        console.log("  - New: 2 blocks * 10 KK/block * 1/3 share =", (aliceEarned2 - aliceEarned1) / 1e18, "KK");
        console.log("Bob total earned:", bobEarned2 / 1e18, "KK");
        console.log("  - New: 2 blocks * 10 KK/block * 2/3 share =", bobEarned2 / 1e18, "KK");
        console.log("");
        
        // 阶段3: Charlie质押3 ETH (区块8)
        console.log("--- Phase 3: Charlie stakes 3 ETH ---");
        vm.startPrank(charlie);
        stakingPool.stake{value: 3 ether}();
        vm.stopPrank();
        
        uint256 charlieStakeBlock = block.number;
        console.log("Charlie staked 3 ETH at block:", charlieStakeBlock);
        console.log("Total staked:", stakingPool.totalStaked() / 1e18, "ETH");
        console.log("Alice's share: 1/6 = 16.67%");
        console.log("Bob's share: 2/6 = 33.33%");
        console.log("Charlie's share: 3/6 = 50%");
        console.log("");
        
        // 前进5个区块 (区块9-13)
        console.log("--- Advancing 5 blocks (All three users share rewards) ---");
        uint256 timeAdvance3 = block.timestamp + 5 * 12;
        vm.warp(timeAdvance3);
        vm.roll(block.number + 5);
        
        uint256 aliceFinal = stakingPool.earned(alice);
        uint256 bobFinal = stakingPool.earned(bob);
        uint256 charlieFinal = stakingPool.earned(charlie);
        
        console.log("Final results after 5 more blocks (block", block.number, "):");
        console.log("");
        console.log("Alice final earned:", aliceFinal / 1e18, "KK");
        console.log("  - Breakdown:");
        console.log("    * 3 blocks alone: 30 KK");
        console.log("    * 2 blocks with Bob: ~6.67 KK");
        console.log("    * 5 blocks with Bob & Charlie: ~8.33 KK");
        console.log("    * Total expected: ~45 KK");
        console.log("");
        
        console.log("Bob final earned:", bobFinal / 1e18, "KK");
        console.log("  - Breakdown:");
        console.log("    * 2 blocks with Alice: ~13.33 KK");
        console.log("    * 5 blocks with Alice & Charlie: ~16.67 KK");
        console.log("    * Total expected: ~30 KK");
        console.log("");
        
        console.log("Charlie final earned:", charlieFinal / 1e18, "KK");
        console.log("  - Breakdown:");
        console.log("    * 5 blocks with Alice & Bob: ~25 KK");
        console.log("    * Total expected: ~25 KK");
        console.log("");
        
        uint256 totalEarned = aliceFinal + bobFinal + charlieFinal;
        console.log("Total KK tokens earned:", totalEarned / 1e18, "KK");
        // 计算实际经过的区块数：3(Alice独占) + 2(Alice+Bob) + 5(三人共享) = 10个区块
        uint256 expectedBlockRewards = 10;
        console.log("Expected blocks for rewards:", expectedBlockRewards);
        console.log("Expected total:", expectedBlockRewards * 10, "KK");
        console.log("");
        
        // 验证奖励合理性
        assertGt(aliceFinal, bobFinal, "Alice should earn more than Bob (staked longer)");
        assertGt(bobFinal, charlieFinal, "Bob should earn more than Charlie (staked longer)");
        
        // 验证总奖励约等于预期值（考虑精度误差）
        uint256 expectedTotal = expectedBlockRewards * REWARD_PER_BLOCK;
        assertApproxEqAbs(totalEarned, expectedTotal, 1e16, "Total rewards should match expected");
        
        console.log("All assertions passed!");
    }
    
    function test_rewardAccuracy() public {
        console.log("=== Basic Reward Verification ===");
        
        // Alice质押1 ETH并获得奖励
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
        
        // 前进几个区块
        vm.roll(block.number + 5);
        
        uint256 aliceReward = stakingPool.earned(alice);
        console.log("Alice earned after 5 blocks:", aliceReward / 1e18, "KK");
        
        // Alice独自质押5个区块应该获得50 KK
        assertEq(aliceReward, 50 * 1e18, "Alice should earn 50 KK for 5 blocks alone");
        
        // Bob加入
        vm.startPrank(bob);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
        
        // 再前进2个区块
        vm.roll(block.number + 2);
        
        uint256 aliceReward2 = stakingPool.earned(alice);
        uint256 bobReward = stakingPool.earned(bob);
        
        console.log("After Bob joins and 2 more blocks:");
        console.log("Alice total reward:", aliceReward2 / 1e18, "KK");
        console.log("Bob reward:", bobReward / 1e18, "KK");
        
        // Alice应该有 50 + 10 = 60 KK, Bob应该有 10 KK
        assertEq(aliceReward2, 60 * 1e18, "Alice should have 60 KK total");
        assertEq(bobReward, 10 * 1e18, "Bob should have 10 KK");
        
        console.log("Basic reward verification passed!");
    }
    
    function test_claimAndContinueEarning() public {
        console.log("=== Claim and Continue Earning Test ===");
        
        // Alice质押并获得一些奖励
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
        
        // 前进几个区块
        uint256 timeAdvance1 = block.timestamp + 3 * 12;
        vm.warp(timeAdvance1);
        vm.roll(block.number + 3);
        
        uint256 earnedBeforeClaim = stakingPool.earned(alice);
        console.log("Alice earned before claim:", earnedBeforeClaim / 1e18, "KK");
        
        // 领取奖励
        vm.startPrank(alice);
        stakingPool.claim();
        vm.stopPrank();
        
        console.log("Alice claimed rewards");
        assertEq(kkToken.balanceOf(alice), earnedBeforeClaim, "Alice should receive KK tokens");
        assertEq(stakingPool.earned(alice), 0, "Pending rewards should be 0 after claim");
        
        // 继续质押并获得新奖励
        uint256 timeAdvance2 = block.timestamp + 2 * 12;
        vm.warp(timeAdvance2);
        vm.roll(block.number + 2);
        
        uint256 newEarned = stakingPool.earned(alice);
        console.log("Alice earned after claim:", newEarned / 1e18, "KK");
        
        // 应该获得新的奖励
        assertEq(newEarned, 20 * 1e18, "Should earn 20 KK for 2 more blocks");
        
        console.log("Claim and continue earning verified!");
    }
} 