pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../src/BankRank3.sol";

contract BankRank3Test is Test {
    Bank public bank;
    address public admin;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    
    receive() external payable {}
    function setUp() public {
        admin = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        
        vm.prank(admin);
        bank = new Bank();
        
        // 给测试用户一些ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);
    }
    
    // 测试1：检查存款前后用户余额更新是否正确
    function testDeposit() public {
        uint256 depositAmount = 1 ether;
        
        // 存款前余额为0
        assertEq(bank.balances(user1), 0);
        
        // 用户1存款
        vm.prank(user1);
        (bool success, ) = address(bank).call{value: depositAmount}("");
        require(success, "Deposit failed");
        
        // 检查存款后余额
        assertEq(bank.balances(user1), depositAmount);
    }
    
    // 测试2.1：检查只有1个用户时的排名
    function testTopThreeWithOneUser() public {
        // 用户1存款
        vm.prank(user1);
        (bool success, ) = address(bank).call{value: 1 ether}("");
        require(success, "Deposit failed");
        
        // 获取排名
        Bank.Rank[3] memory ranks = bank.getTopThree();
        
        // 验证排名
        assertEq(ranks[0].addr, user1);
        assertEq(ranks[0].amount, 1 ether);
        assertEq(ranks[1].addr, address(0));
        assertEq(ranks[1].amount, 0);
        assertEq(ranks[2].addr, address(0));
        assertEq(ranks[2].amount, 0);
    }
    
    // 测试2.2：检查有2个用户时的排名
    function testTopThreeWithTwoUsers() public {
        // 用户1存款
        vm.prank(user1);
        (bool success1, ) = address(bank).call{value: 1 ether}("");
        require(success1, "Deposit failed");
        
        // 用户2存款
        vm.prank(user2);
        (bool success2, ) = address(bank).call{value: 2 ether}("");
        require(success2, "Deposit failed");
        
        // 获取排名
        Bank.Rank[3] memory ranks = bank.getTopThree();
        
        // 验证排名（按金额降序）
        assertEq(ranks[0].addr, user2);
        assertEq(ranks[0].amount, 2 ether);
        assertEq(ranks[1].addr, user1);
        assertEq(ranks[1].amount, 1 ether);
        assertEq(ranks[2].addr, address(0));
        assertEq(ranks[2].amount, 0);
    }
    
    // 测试2.3：检查有3个用户时的排名
    function testTopThreeWithThreeUsers() public {
        // 用户1存款
        vm.prank(user1);
        (bool success1, ) = address(bank).call{value: 1 ether}("");
        require(success1, "Deposit failed");
        
        // 用户2存款
        vm.prank(user2);
        (bool success2, ) = address(bank).call{value: 2 ether}("");
        require(success2, "Deposit failed");
        
        // 用户3存款
        vm.prank(user3);
        (bool success3, ) = address(bank).call{value: 3 ether}("");
        require(success3, "Deposit failed");
        
        // 获取排名
        Bank.Rank[3] memory ranks = bank.getTopThree();
        
        // 验证排名（按金额降序）
        assertEq(ranks[0].addr, user3);
        assertEq(ranks[0].amount, 3 ether);
        assertEq(ranks[1].addr, user2);
        assertEq(ranks[1].amount, 2 ether);
        assertEq(ranks[2].addr, user1);
        assertEq(ranks[2].amount, 1 ether);
    }
    
    // 测试2.4：检查有4个用户时的排名（只保留前3名）
    function testTopThreeWithFourUsers() public {
        // 用户1存款
        vm.prank(user1);
        (bool success1, ) = address(bank).call{value: 1 ether}("");
        require(success1, "Deposit failed");
        
        // 用户2存款
        vm.prank(user2);
        (bool success2, ) = address(bank).call{value: 2 ether}("");
        require(success2, "Deposit failed");
        
        // 用户3存款
        vm.prank(user3);
        (bool success3, ) = address(bank).call{value: 3 ether}("");
        require(success3, "Deposit failed");
        
        // 用户4存款（金额小于用户3，但大于用户2）
        vm.prank(user4);
        (bool success4, ) = address(bank).call{value: 2.5 ether}("");
        require(success4, "Deposit failed");
        
        // 获取排名
        Bank.Rank[3] memory ranks = bank.getTopThree();
        
        // 验证排名（按金额降序，用户1应该被排除）
        assertEq(ranks[0].addr, user3);
        assertEq(ranks[0].amount, 3 ether);
        assertEq(ranks[1].addr, user4);
        assertEq(ranks[1].amount, 2.5 ether);
        assertEq(ranks[2].addr, user2);
        assertEq(ranks[2].amount, 2 ether);
    }
    
    // 测试2.5：检查同一用户多次存款的情况
    function testTopThreeWithMultipleDeposits() public {
        // 用户1第一次存款
        vm.prank(user1);
        (bool success1, ) = address(bank).call{value: 1 ether}("");
        require(success1, "Deposit failed");
        
        // 用户2存款
        vm.prank(user2);
        (bool success2, ) = address(bank).call{value: 2 ether}("");
        require(success2, "Deposit failed");
        
        // 用户1第二次存款（总额应该变为3 ether）
        vm.prank(user1);
        (bool success3, ) = address(bank).call{value: 2 ether}("");
        require(success3, "Deposit failed");
        
        // 获取排名
        Bank.Rank[3] memory ranks = bank.getTopThree();
        
        // 验证排名（用户1应该排在第一位）
        assertEq(ranks[0].addr, user1);
        assertEq(ranks[0].amount, 3 ether);
        assertEq(ranks[1].addr, user2);
        assertEq(ranks[1].amount, 2 ether);
    }
    
    // 测试3.1：检查管理员可以提取资金
    function testAdminWithdraw() public {
        // 用户1存款
        vm.prank(user1);
        (bool success1, ) = address(bank).call{value: 1 ether}("");
        require(success1, "Deposit failed");
        
        // 记录管理员初始余额
        uint256 adminInitialBalance = admin.balance;
        
        // 管理员提取资金
        vm.prank(admin);
        bank.withdraw();
        
        // 验证合约余额为0
        assertEq(address(bank).balance, 0);
        
        // 验证管理员余额增加
        assertEq(admin.balance, adminInitialBalance + 1 ether);
    }
    
    // 测试3.2：检查非管理员不能提取资金
    function testNonAdminCannotWithdraw() public {
        // 用户1存款
        vm.prank(user1);
        (bool success1, ) = address(bank).call{value: 1 ether}("");
        require(success1, "Deposit failed");
        
        // 用户1尝试提取资金（应该失败）
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        bank.withdraw();
        
        // 验证合约余额仍然为1 ether
        assertEq(address(bank).balance, 1 ether);
    }
}