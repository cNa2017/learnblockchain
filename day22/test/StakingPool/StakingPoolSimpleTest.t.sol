// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StakingPool} from "src/StakingPool/StakingPool.sol";
import {KKToken} from "src/StakingPool/KKToken.sol";

contract StakingPoolSimpleTest is Test {
    StakingPool public stakingPool;
    KKToken public kkToken;
    
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18;
    
    function setUp() public {
        vm.startPrank(owner);
        
        kkToken = new KKToken();
        stakingPool = new StakingPool(address(kkToken));
        kkToken.transferOwnership(address(stakingPool));
        
        vm.stopPrank();
        
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }
    
    function test_threeUsersScenario() public {
        console.log("=== Three Users Staking Scenario ===");
        console.log("REWARD_PER_BLOCK:", REWARD_PER_BLOCK / 1e18, "KK");
        console.log("");
        
        // 初始区块
        uint256 startBlock = block.number;
        console.log("Start block:", startBlock);
        
        // Alice质押1 ETH
        console.log("--- Alice stakes 1 ETH ---");
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
        
        console.log("Alice staked at block:", block.number);
        console.log("Alice balance:", stakingPool.balanceOf(alice) / 1e18, "ETH");
        console.log("Total staked:", stakingPool.totalStaked() / 1e18, "ETH");
        console.log("");
        
        // 前进5个区块
        vm.roll(block.number + 5);
        console.log("--- Advanced 5 blocks to block", block.number, "---");
        uint256 aliceEarned1 = stakingPool.earned(alice);
        console.log("Alice earned:", aliceEarned1 / 1e18, "KK");
        console.log("Expected: 5 blocks * 10 KK = 50 KK");
        console.log("");
        
        // Bob质押2 ETH
        console.log("--- Bob stakes 2 ETH ---");
        vm.startPrank(bob);
        stakingPool.stake{value: 2 ether}();
        vm.stopPrank();
        
        console.log("Bob staked at block:", block.number);
        console.log("Bob balance:", stakingPool.balanceOf(bob) / 1e18, "ETH");
        console.log("Total staked:", stakingPool.totalStaked() / 1e18, "ETH");
        console.log("Now Alice has 1/3 share, Bob has 2/3 share");
        console.log("");
        
        // 前进3个区块
        vm.roll(block.number + 3);
        console.log("--- Advanced 3 blocks to block", block.number, "---");
        uint256 aliceEarned2 = stakingPool.earned(alice);
        uint256 bobEarned2 = stakingPool.earned(bob);
        console.log("Alice total earned:", aliceEarned2 / 1e18, "KK");
        console.log("Bob total earned:", bobEarned2 / 1e18, "KK");
        console.log("Expected Alice additional: 3 blocks * 10 KK * 1/3 = 10 KK");
        console.log("Expected Bob: 3 blocks * 10 KK * 2/3 = 20 KK");
        console.log("");
        
        // Charlie质押3 ETH
        console.log("--- Charlie stakes 3 ETH ---");
        vm.startPrank(charlie);
        stakingPool.stake{value: 3 ether}();
        vm.stopPrank();
        
        console.log("Charlie staked at block:", block.number);
        console.log("Charlie balance:", stakingPool.balanceOf(charlie) / 1e18, "ETH");
        console.log("Total staked:", stakingPool.totalStaked() / 1e18, "ETH");
        console.log("Now Alice:1/6, Bob:2/6, Charlie:3/6 shares");
        console.log("");
        
        // 前进6个区块
        vm.roll(block.number + 6);
        console.log("--- Advanced 6 blocks to block", block.number, "---");
        uint256 aliceFinal = stakingPool.earned(alice);
        uint256 bobFinal = stakingPool.earned(bob);
        uint256 charlieFinal = stakingPool.earned(charlie);
        
        console.log("=== Final Results ===");
        console.log("Alice final earned:", aliceFinal / 1e18, "KK");
        console.log("Bob final earned:", bobFinal / 1e18, "KK");
        console.log("Charlie final earned:", charlieFinal / 1e18, "KK");
        console.log("Total earned:", (aliceFinal + bobFinal + charlieFinal) / 1e18, "KK");
        console.log("");
        
        console.log("Alice breakdown:");
        console.log("  - 5 blocks alone: 50 KK");
        console.log("  - 3 blocks with Bob (1/3 share): 10 KK");
        console.log("  - 6 blocks with Bob & Charlie (1/6 share): 10 KK");
        console.log("  - Expected total: 70 KK");
        console.log("");
        
        console.log("Bob breakdown:");
        console.log("  - 3 blocks with Alice (2/3 share): 20 KK");
        console.log("  - 6 blocks with Alice & Charlie (2/6 share): 20 KK");
        console.log("  - Expected total: 40 KK");
        console.log("");
        
        console.log("Charlie breakdown:");
        console.log("  - 6 blocks with Alice & Bob (3/6 share): 30 KK");
        console.log("  - Expected total: 30 KK");
        console.log("");
        
        // 验证奖励合理性
        assertGt(aliceFinal, bobFinal, "Alice should earn more than Bob");
        assertGt(bobFinal, charlieFinal, "Bob should earn more than Charlie");
        
        // 所有用户都应该有收益
        assertGt(aliceFinal, 0, "Alice should have rewards");
        assertGt(bobFinal, 0, "Bob should have rewards");
        assertGt(charlieFinal, 0, "Charlie should have rewards");
        
        console.log("All validations passed!");
    }
    
    function test_claimAndUnstake() public {
        console.log("=== Claim and Unstake Test ===");
        
        // Alice质押
        vm.startPrank(alice);
        stakingPool.stake{value: 2 ether}();
        vm.stopPrank();
        
        // 前进一些区块
        vm.roll(block.number + 5);
        
        uint256 earned = stakingPool.earned(alice);
        console.log("Alice earned:", earned / 1e18, "KK");
        
        // 领取奖励
        vm.startPrank(alice);
        stakingPool.claim();
        vm.stopPrank();
        
        console.log("Alice claimed rewards");
        assertEq(kkToken.balanceOf(alice), earned, "Should receive KK tokens");
        assertEq(stakingPool.earned(alice), 0, "Should have no pending rewards");
        
        // 继续赚取奖励
        vm.roll(block.number + 3);
        uint256 newEarned = stakingPool.earned(alice);
        console.log("Alice earned after claim:", newEarned / 1e18, "KK");
        assertGt(newEarned, 0, "Should continue earning");
        
        // 部分取消质押
        uint256 aliceBalanceBefore = alice.balance;
        vm.startPrank(alice);
        stakingPool.unstake(1 ether);
        vm.stopPrank();
        
        console.log("Alice unstaked 1 ETH");
        assertEq(stakingPool.balanceOf(alice), 1 ether, "Should have 1 ETH staked left");
        assertEq(alice.balance, aliceBalanceBefore + 1 ether, "Should receive ETH back");
        
        console.log("Claim and unstake test passed!");
    }
} 