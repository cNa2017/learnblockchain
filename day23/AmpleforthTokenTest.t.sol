// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AmpleforthToken} from "src/Ampleforth_rebase/AmpleforthToken.sol";

contract AmpleforthTokenTest is Test {
    AmpleforthToken public token;
    address public owner;
    address public user1;
    address public user2;

    uint256 constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 1亿代币
    uint256 constant REBASE_INTERVAL = 365 days; // 1年

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.prank(owner);
        token = new AmpleforthToken(owner);
    }

    function test_InitialState() public view {
        // 测试初始状态
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.rebaseCount(), 0);
        assertEq(token.name(), "AmpleforthToken");
        assertEq(token.symbol(), "AMPL");
        assertEq(token.decimals(), 18);
        
        console.log("Initial total supply:", token.totalSupply());
        console.log("Owner initial balance:", token.balanceOf(owner));
    }

    function test_Transfer() public {
        uint256 transferAmount = 1000 * 10**18;
        
        vm.prank(owner);
        token.transfer(user1, transferAmount);
        
        assertEq(token.balanceOf(user1), transferAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        
        console.log("User1 balance after transfer:", token.balanceOf(user1));
        console.log("Owner balance after transfer:", token.balanceOf(owner));
    }

    function test_CannotRebaseEarly() public {
        // 测试不能提前 rebase
        vm.expectRevert("Rebase: too early to rebase");
        token.rebase();
    }

    function test_Rebase() public {
        // 给用户1一些代币
        uint256 transferAmount = 1000 * 10**18;
        vm.prank(owner);
        token.transfer(user1, transferAmount);
        
        uint256 initialSupply = token.totalSupply();
        uint256 initialUser1Balance = token.balanceOf(user1);
        uint256 initialOwnerBalance = token.balanceOf(owner);
        
        console.log("Before rebase:");
        console.log("Total supply:", initialSupply);
        console.log("User1 balance:", initialUser1Balance);
        console.log("Owner balance:", initialOwnerBalance);
        
        // 快进一年
        vm.warp(block.timestamp + REBASE_INTERVAL);
        
        // 执行 rebase
        uint256 newSupply = token.rebase();
        
        // 验证总供应量减少了 1%
        uint256 expectedNewSupply = (initialSupply * 99) / 100;
        assertEq(newSupply, expectedNewSupply);
        assertEq(token.totalSupply(), expectedNewSupply);
        
        // 验证用户余额按比例减少
        uint256 newUser1Balance = token.balanceOf(user1);
        uint256 newOwnerBalance = token.balanceOf(owner);
        uint256 expectedUser1Balance = (initialUser1Balance * 99) / 100;
        uint256 expectedOwnerBalance = (initialOwnerBalance * 99) / 100;
        
        assertEq(newUser1Balance, expectedUser1Balance);
        assertEq(newOwnerBalance, expectedOwnerBalance);
        
        // 验证 rebase 计数增加
        assertEq(token.rebaseCount(), 1);
        
        console.log("After rebase:");
        console.log("Total supply:", token.totalSupply());
        console.log("User1 balance:", newUser1Balance);
        console.log("Owner balance:", newOwnerBalance);
    }

    function test_MultipleRebase() public {
        uint256 initialSupply = token.totalSupply();
        uint256 currentSupply = initialSupply;
        uint256 currentTime = block.timestamp;
        
        console.log("Initial supply:", initialSupply);
        
        // 执行多次 rebase
        for (uint256 i = 0; i < 3; i++) {
            // 每次都推进一年的时间
            currentTime += REBASE_INTERVAL;
            vm.warp(currentTime);
            
            uint256 newSupply = token.rebase();
            uint256 expectedSupply = (currentSupply * 99) / 100;
            
            // 使用近似比较，允许微小精度误差
            uint256 loopTolerance = expectedSupply / 1000000; // 0.0001% 容差
            uint256 loopDiff = newSupply > expectedSupply ? 
                newSupply - expectedSupply : 
                expectedSupply - newSupply;
            
            assertLe(loopDiff, loopTolerance, "Each rebase should reduce supply by approximately 1%");
            assertEq(token.rebaseCount(), i + 1);
            
            currentSupply = newSupply;
            console.log("After rebase", i + 1, "supply:", currentSupply);
            console.log("Expected supply:", expectedSupply);
            console.log("Actual supply:", newSupply);
            console.log("Difference:", loopDiff);
        }
        
        // 验证经过3次rebase后的总供应量
        // 计算: 初始供应量 * 0.99^3 ≈ 97,029,900
        uint256 expectedFinalSupply = initialSupply;
        for (uint256 i = 0; i < 3; i++) {
            expectedFinalSupply = (expectedFinalSupply * 99) / 100;
        }
        
        uint256 actualFinalSupply = token.totalSupply();
        
        // 使用近似等于，允许微小的精度误差（小于0.001%）
        uint256 finalTolerance = expectedFinalSupply / 100000; // 0.001% 容差
        uint256 finalDiff = actualFinalSupply > expectedFinalSupply ? 
            actualFinalSupply - expectedFinalSupply : 
            expectedFinalSupply - actualFinalSupply;
        
        assertLe(finalDiff, finalTolerance, "Final supply should be approximately equal to expected value");
        
        console.log("Expected final supply:", expectedFinalSupply);
        console.log("Actual final supply:", actualFinalSupply);
        console.log("Final difference:", finalDiff);
        console.log("Final tolerance:", finalTolerance);
    }

    function test_CanRebaseFunction() public {
        // 初始时不能 rebase
        assertEq(token.canRebase(), false);
        
        // 快进一年后可以 rebase
        vm.warp(block.timestamp + REBASE_INTERVAL);
        assertEq(token.canRebase(), true);
        
        // 执行 rebase 后需要再等一年
        token.rebase();
        assertEq(token.canRebase(), false);
    }

    function test_TimeToNextRebase() public {
        uint256 initialTime = token.timeToNextRebase();
        assertEq(initialTime, REBASE_INTERVAL);
        
        // 快进半年
        vm.warp(block.timestamp + REBASE_INTERVAL / 2);
        uint256 halfYearTime = token.timeToNextRebase();
        assertEq(halfYearTime, REBASE_INTERVAL / 2);
        
        // 快进到可以 rebase 的时间
        vm.warp(block.timestamp + REBASE_INTERVAL / 2);
        assertEq(token.timeToNextRebase(), 0);
    }

    function test_ApproveAndTransferFrom() public {
        uint256 approveAmount = 500 * 10**18;
        uint256 transferAmount = 300 * 10**18;
        
        // owner 授权给 user1
        vm.prank(owner);
        token.approve(user1, approveAmount);
        
        // 验证授权金额
        assertEq(token.allowance(owner, user1), approveAmount);
        console.log("Allowance after approve:", token.allowance(owner, user1));
        
        // user1 从 owner 转账给 user2
        vm.prank(user1);
        token.transferFrom(owner, user2, transferAmount);
        
        // 验证转账结果
        assertEq(token.balanceOf(user2), transferAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        
        // 验证剩余授权金额
        uint256 remainingAllowance = token.allowance(owner, user1);
        assertEq(remainingAllowance, approveAmount - transferAmount);
        
        console.log("User2 balance after transferFrom:", token.balanceOf(user2));
        console.log("Remaining allowance:", remainingAllowance);
    }

    function test_RebaseAfterTransfers() public {
        // 分发代币给多个用户
        uint256 transferAmount = 10000 * 10**18;
        
        vm.startPrank(owner);
        token.transfer(user1, transferAmount);
        token.transfer(user2, transferAmount);
        vm.stopPrank();
        
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 user1BalanceBefore = token.balanceOf(user1);
        uint256 user2BalanceBefore = token.balanceOf(user2);
        
        // 快进一年并执行 rebase
        vm.warp(block.timestamp + REBASE_INTERVAL);
        token.rebase();
        
        // 验证所有用户余额都按比例减少
        assertEq(token.balanceOf(owner), (ownerBalanceBefore * 99) / 100);
        assertEq(token.balanceOf(user1), (user1BalanceBefore * 99) / 100);
        assertEq(token.balanceOf(user2), (user2BalanceBefore * 99) / 100);
        
        console.log("Owner balance before rebase:", ownerBalanceBefore);
        console.log("Owner balance after rebase:", token.balanceOf(owner));
        console.log("User1 balance before rebase:", user1BalanceBefore);
        console.log("User1 balance after rebase:", token.balanceOf(user1));
    }

    function test_GonsConsistency() public view {
        // 测试 gons 机制的一致性
        uint256 totalGons = token.getTotalGons();
        uint256 gonsPerFragment = token.getGonsPerFragment();
        
        console.log("Total gons:", totalGons);
        console.log("Gons per fragment:", gonsPerFragment);
        console.log("Calculated total supply:", totalGons / gonsPerFragment);
        console.log("Actual total supply:", token.totalSupply());
        
        assertEq(token.totalSupply(), totalGons / gonsPerFragment);
    }
} 