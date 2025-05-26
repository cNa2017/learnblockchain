// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {VestingToken, Vesting} from "../src/Vesting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VestingTest
 * @dev 测试 Vesting 合约的各种功能和时间逻辑
 */
contract VestingTest is Test {
    VestingToken public token;
    Vesting public vesting;
    
    address public owner = makeAddr("owner");
    address public beneficiary = makeAddr("beneficiary");
    address public randomUser = makeAddr("randomUser");
    
    uint256 public constant TOTAL_SUPPLY = 1_000_000 * 10**18; // 100万代币
    uint256 public constant VESTING_AMOUNT = 1_000_000 * 10**18; // 100万代币用于 vesting
    
    uint256 public constant CLIFF_DURATION = 365 days; // 12个月
    uint256 public constant VESTING_DURATION = 730 days; // 24个月
    uint256 public constant TOTAL_DURATION = CLIFF_DURATION + VESTING_DURATION; // 36个月
    
    uint256 public startTime;
    
    function setUp() public {
        // 设置初始状态
        vm.startPrank(owner);
        
        // 部署代币合约
        token = new VestingToken(owner);
        
        // 记录开始时间
        startTime = block.timestamp;
        
        // 部署 Vesting 合约
        vesting = new Vesting(beneficiary, address(token));
        
        // 转移代币到 Vesting 合约
        token.transfer(address(vesting), VESTING_AMOUNT);
        
        vm.stopPrank();
        
        // 验证初始状态
        assertEq(token.balanceOf(address(vesting)), VESTING_AMOUNT);
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(vesting.vestingToken(), address(token));
    }
    
    /* ============ 基本功能测试 ============ */
    
    function test_initialization() public {
        // 测试合约初始化
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(vesting.vestingToken(), address(token));
        assertEq(vesting.getDeployTime(), startTime);
        assertEq(vesting.getCliffEnd(), startTime + CLIFF_DURATION);
        assertEq(vesting.getStartTime(), startTime + CLIFF_DURATION);
        assertEq(vesting.getVestingEnd(), startTime + TOTAL_DURATION);
        assertEq(token.balanceOf(address(vesting)), VESTING_AMOUNT);
    }
    
    function test_initialReleasableAmount() public {
        // 初始时不应该有可释放的代币
        assertEq(vesting.releasable(address(token)), 0);
    }
    
    function test_invalidConstructorParams() public {
        // 测试无效的构造函数参数
        vm.expectRevert(); // OpenZeppelin Ownable 会抛出 OwnableInvalidOwner 错误
        new Vesting(address(0), address(token));
        
        vm.expectRevert("Token cannot be zero address");
        new Vesting(beneficiary, address(0));
    }
    
    /* ============ Cliff 期测试 ============ */
    
    function test_cliffPeriod() public {
        // 在 cliff 期间应该无法释放代币
        
        // 测试 cliff 期开始后的各个时间点
        uint256[] memory testTimes = new uint256[](5);
        testTimes[0] = 30 days;   // 1个月后
        testTimes[1] = 90 days;   // 3个月后
        testTimes[2] = 180 days;  // 6个月后
        testTimes[3] = 270 days;  // 9个月后
        testTimes[4] = 364 days;  // 差1天到cliff结束
        
        for (uint256 i = 0; i < testTimes.length; i++) {
            // 模拟时间推进
            vm.warp(startTime + testTimes[i]);
            
            // 应该没有可释放的代币
            assertEq(vesting.releasable(address(token)), 0, "Should have no releasable tokens during cliff");
            
            // 尝试释放应该失败
            vm.prank(beneficiary);
            vm.expectRevert("No tokens available for release");
            vesting.releaseVesting();
        }
    }
    
    function test_cliffEndExact() public {
        // 测试 cliff 期结束的确切时间
        vm.warp(startTime + CLIFF_DURATION);
        
        // cliff 结束时应该刚好开始线性释放，但此时刻还没有可释放的代币
        uint256 releasable = vesting.releasable(address(token));
        assertEq(releasable, 0, "At cliff end, no tokens should be releasable yet");
        
        // 稍微推进一点时间
        vm.warp(startTime + CLIFF_DURATION + 1 days);
        releasable = vesting.releasable(address(token));
        
        // 应该有一小部分代币可释放
        uint256 expectedReleasable = (VESTING_AMOUNT * 1 days) / VESTING_DURATION;
        assertEq(releasable, expectedReleasable, "Should have correct releasable amount after cliff");
    }
    
    /* ============ 线性释放测试 ============ */
    
    function test_linearVesting() public {
        // 测试线性释放逻辑
        
        // 跳过 cliff 期
        vm.warp(startTime + CLIFF_DURATION);
        
        // 测试不同时间点的释放量
        uint256[] memory testDays = new uint256[](6);
        testDays[0] = 30;   // 1个月
        testDays[1] = 90;   // 3个月
        testDays[2] = 180;  // 6个月
        testDays[3] = 365;  // 12个月
        testDays[4] = 547;  // 18个月
        testDays[5] = 730;  // 24个月（完全释放）
        
        for (uint256 i = 0; i < testDays.length; i++) {
            uint256 timeAfterCliff = testDays[i] * 1 days;
            vm.warp(startTime + CLIFF_DURATION + timeAfterCliff);
            
            uint256 expectedReleasable;
            if (timeAfterCliff >= VESTING_DURATION) {
                expectedReleasable = VESTING_AMOUNT;
            } else {
                expectedReleasable = (VESTING_AMOUNT * timeAfterCliff) / VESTING_DURATION;
            }
            
            uint256 actualReleasable = vesting.releasable(address(token));
            assertEq(actualReleasable, expectedReleasable, 
                string(abi.encodePacked("Incorrect releasable amount at day ", testDays[i])));
        }
    }
    
    function test_monthlyRelease() public {
        // 测试每月释放 1/24 的逻辑
        
        // 跳过 cliff 期
        vm.warp(startTime + CLIFF_DURATION);
        
        uint256 monthlyExpected = VESTING_AMOUNT / 24;
        
        for (uint256 month = 1; month <= 24; month++) {
            // 每个月结束时
            vm.warp(startTime + CLIFF_DURATION + (month * 30 days));
            
            uint256 expectedTotal = (VESTING_AMOUNT * month * 30 days) / VESTING_DURATION;
            uint256 actualReleasable = vesting.releasable(address(token));
            
            // 允许小幅度误差（由于精确的天数计算）
            uint256 tolerance = VESTING_AMOUNT / 10000; // 0.01% 容差
            assertApproxEqAbs(actualReleasable, expectedTotal, tolerance,
                string(abi.encodePacked("Incorrect amount at month ", month)));
        }
    }
    
    /* ============ 释放功能测试 ============ */
    
    function test_successfulRelease() public {
        // 测试成功的代币释放
        
        // 跳过 cliff 期并推进一些时间
        uint256 releaseTime = startTime + CLIFF_DURATION + 30 days;
        vm.warp(releaseTime);
        
        uint256 expectedReleasable = (VESTING_AMOUNT * 30 days) / VESTING_DURATION;
        uint256 initialBeneficiaryBalance = token.balanceOf(beneficiary);
        
        // 执行释放
        vm.prank(beneficiary);
        uint256 released = vesting.releaseVesting();
        
        // 验证结果
        assertEq(released, expectedReleasable, "Released amount should match expected");
        assertEq(token.balanceOf(beneficiary), initialBeneficiaryBalance + expectedReleasable, 
                "Beneficiary balance should increase");
        assertEq(vesting.getReleasedAmount(address(token)), expectedReleasable, 
                "Released amount should be tracked");
        assertEq(vesting.releasable(address(token)), 0, 
                "No more tokens should be releasable immediately after release");
    }
    
    function test_multipleReleases() public {
        // 测试多次释放
        
        // 跳过 cliff 期
        vm.warp(startTime + CLIFF_DURATION + 30 days);
        
        // 第一次释放
        vm.prank(beneficiary);
        uint256 firstRelease = vesting.releaseVesting();
        
        // 推进更多时间
        vm.warp(startTime + CLIFF_DURATION + 60 days);
        
        // 第二次释放
        vm.prank(beneficiary);
        uint256 secondRelease = vesting.releaseVesting();
        
        // 验证总释放量
        uint256 totalReleased = vesting.getReleasedAmount(address(token));
        assertEq(totalReleased, firstRelease + secondRelease, "Total released should be sum of releases");
        
        // 验证受益人余额
        uint256 expectedTotal = (VESTING_AMOUNT * 60 days) / VESTING_DURATION;
        assertEq(token.balanceOf(beneficiary), expectedTotal, "Beneficiary should have correct total");
    }
    
    function test_releaseByNonBeneficiary() public {
        // 测试非受益人是否可以触发释放
        
        // 跳过 cliff 期
        vm.warp(startTime + CLIFF_DURATION + 30 days);
        
        // 任何人都可以调用 releaseVesting 函数
        vm.prank(randomUser);
        uint256 released = vesting.releaseVesting();
        
        // 但代币应该转给受益人
        assertGt(released, 0, "Should release some tokens");
        assertGt(token.balanceOf(beneficiary), 0, "Beneficiary should receive tokens");
        assertEq(token.balanceOf(randomUser), 0, "Caller should not receive tokens");
    }
    
    /* ============ 完整生命周期测试 ============ */
    
    function test_fullVestingCycle() public {
        // 测试完整的 vesting 周期
        
        uint256 totalReleased = 0;
        
        // 每月释放一次（24个月）
        for (uint256 month = 1; month <= 24; month++) {
            // 推进到月末（使用精确的天数）
            uint256 daysIntoVesting = (month * VESTING_DURATION) / 24;
            vm.warp(startTime + CLIFF_DURATION + daysIntoVesting);
            
            uint256 releasableBefore = vesting.releasable(address(token));
            
            if (releasableBefore > 0) {
                vm.prank(beneficiary);
                uint256 released = vesting.releaseVesting();
                totalReleased += released;
                
                console.log("Month", month, "- Released:", released);
            }
        }
        
        // 验证最终状态
        assertEq(vesting.getReleasedAmount(address(token)), totalReleased, 
                "Total tracked release should match sum");
        assertEq(token.balanceOf(beneficiary), totalReleased, 
                "Beneficiary balance should match total released");
        
        // 最后应该释放所有代币（允许更大的容差，因为使用30天作为月份）
        assertApproxEqAbs(totalReleased, VESTING_AMOUNT, VESTING_AMOUNT / 100, 
                "Should release approximately all tokens");
    }
    
    function test_releaseAfterFullVesting() public {
        // 测试完全 vesting 后的释放
        
        // 跳到 vesting 结束后
        vm.warp(startTime + TOTAL_DURATION + 1 days);
        
        // 应该可以释放所有代币
        uint256 releasable = vesting.releasable(address(token));
        assertEq(releasable, VESTING_AMOUNT, "Should be able to release all tokens");
        
        // 执行释放
        vm.prank(beneficiary);
        uint256 released = vesting.releaseVesting();
        
        assertEq(released, VESTING_AMOUNT, "Should release all tokens");
        assertEq(token.balanceOf(beneficiary), VESTING_AMOUNT, "Beneficiary should have all tokens");
        assertEq(vesting.releasable(address(token)), 0, "No more tokens should be releasable");
    }
    
    /* ============ 紧急功能测试 ============ */
    
    function test_emergencyWithdraw() public {
        // 测试紧急提取功能
        
        uint256 withdrawAmount = 10000 * 10**18;
        
        // 只有受益人可以紧急提取
        vm.prank(beneficiary);
        vesting.emergencyWithdraw(address(token), withdrawAmount);
        
        assertEq(token.balanceOf(beneficiary), withdrawAmount, "Should withdraw correct amount");
    }
    
    function test_emergencyWithdrawUnauthorized() public {
        // 测试未授权的紧急提取
        
        uint256 withdrawAmount = 10000 * 10**18;
        
        vm.prank(randomUser);
        vm.expectRevert("Only beneficiary can withdraw");
        vesting.emergencyWithdraw(address(token), withdrawAmount);
    }
    
    /* ============ 边界条件测试 ============ */
    
    function test_releaseWithNoAvailableTokens() public {
        // 测试没有可用代币时的释放
        
        // 在 cliff 期间尝试释放
        vm.prank(beneficiary);
        vm.expectRevert("No tokens available for release");
        vesting.releaseVesting();
    }
    
    function test_timeManipulation() public {
        // 测试各种时间操作
        
        // 测试时间倒退不会产生问题
        vm.warp(startTime + CLIFF_DURATION + 30 days);
        uint256 releasable1 = vesting.releasable(address(token));
        
        vm.warp(startTime + CLIFF_DURATION + 15 days); // 时间倒退
        uint256 releasable2 = vesting.releasable(address(token));
        
        assertLe(releasable2, releasable1, "Releasable amount should not increase when time goes back");
    }
    
    function test_gasOptimization() public {
        // 测试 gas 消耗
        
        vm.warp(startTime + CLIFF_DURATION + 30 days);
        
        uint256 gasBefore = gasleft();
        vm.prank(beneficiary);
        vesting.releaseVesting();
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for release:", gasUsed);
        assertLt(gasUsed, 100000, "Gas usage should be reasonable");
    }
    
    /* ============ 辅助函数 ============ */
    
    function logVestingState(string memory label) internal view {
        console.log("=== %s ===", label);
        console.log("Current time:", block.timestamp);
        console.log("Start time:", vesting.getStartTime());
        console.log("Cliff end:", vesting.getCliffEnd());
        console.log("Vesting end:", vesting.getVestingEnd());
        console.log("Total balance:", vesting.getTotalBalance(address(token)));
        console.log("Released amount:", vesting.getReleasedAmount(address(token)));
        console.log("Releasable amount:", vesting.releasable(address(token)));
        console.log("Beneficiary balance:", token.balanceOf(beneficiary));
        console.log("");
    }
} 