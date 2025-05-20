// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {ERC20_Extend} from "../src/NFTMarketExchange.sol";

contract TokenBankRecordTest is Test {
    TokenBank public tokenBank;
    ERC20_Extend public token;

    address public deployer = makeAddr("deployer");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public user4 = makeAddr("user4");
    address public user5 = makeAddr("user5");
    address public user6 = makeAddr("user6");
    address public user7 = makeAddr("user7");
    address public user8 = makeAddr("user8");
    address public user9 = makeAddr("user9");
    address public user10 = makeAddr("user10");
    address public user11 = makeAddr("user11");

    function setUp() public {
        vm.startPrank(deployer);
        
        // 部署测试用的ERC20代币合约
        token = new ERC20_Extend(100000*20*10**18);
        
        // 部署TokenBank合约
        tokenBank = new TokenBank(address(token));
        
        // 为测试用户铸造代币，提高金额以确保足够
        token.transfer(user1, 10000 ether);
        token.transfer(user2, 10000 ether);
        token.transfer(user3, 10000 ether);
        token.transfer(user4, 10000 ether);
        token.transfer(user5, 10000 ether);
        token.transfer(user6, 10000 ether);
        token.transfer(user7, 10000 ether);
        token.transfer(user8, 10000 ether);
        token.transfer(user9, 10000 ether);
        token.transfer(user10, 10000 ether);
        token.transfer(user11, 10000 ether);
        
        vm.stopPrank();
    }

    function test_TopUsersEmpty() public {
        // 初始状态下应该没有用户
        (address[] memory users, uint256[] memory amounts) = tokenBank.getTopUsers(10);
        assertEq(users.length, 0);
        assertEq(amounts.length, 0);
    }

    function test_AddSingleUser() public {
        // 用户1存入100 tokens
        vm.startPrank(user1);
        token.approve(address(tokenBank), 100 ether);
        tokenBank.deposit(100 ether);
        vm.stopPrank();
        
        // 检查排名
        (address[] memory users, uint256[] memory amounts) = tokenBank.getTopUsers(10);
        assertEq(users.length, 1);
        assertEq(users[0], user1);
        assertEq(amounts[0], 100 ether);
    }

    function test_AddMultipleUsersOrderedByBalance() public {
        // 用户1存入100 tokens
        vm.startPrank(user1);
        token.approve(address(tokenBank), 100 ether);
        tokenBank.deposit(100 ether);
        vm.stopPrank();
        
        // 用户2存入200 tokens
        vm.startPrank(user2);
        token.approve(address(tokenBank), 200 ether);
        tokenBank.deposit(200 ether);
        vm.stopPrank();
        
        // 用户3存入50 tokens
        vm.startPrank(user3);
        token.approve(address(tokenBank), 50 ether);
        tokenBank.deposit(50 ether);
        vm.stopPrank();
        
        // 检查排名，应该是 user2, user1, user3
        (address[] memory users, uint256[] memory amounts) = tokenBank.getTopUsers(10);
        assertEq(users.length, 3);
        assertEq(users[0], user2);
        assertEq(amounts[0], 200 ether);
        assertEq(users[1], user1);
        assertEq(amounts[1], 100 ether);
        assertEq(users[2], user3);
        assertEq(amounts[2], 50 ether);
    }

    function test_UpdateRankingOnDeposit() public {
        // 用户1存入100 tokens
        vm.startPrank(user1);
        token.approve(address(tokenBank), 200 ether);
        tokenBank.deposit(100 ether);
        vm.stopPrank();
        
        // 用户2存入50 tokens
        vm.startPrank(user2);
        token.approve(address(tokenBank), 50 ether);
        tokenBank.deposit(50 ether);
        vm.stopPrank();
        
        // 用户1再存入100 tokens，总共200，应该排第一
        vm.startPrank(user1);
        tokenBank.deposit(100 ether);
        vm.stopPrank();
        
        // 检查排名，应该是 user1, user2
        (address[] memory users, uint256[] memory amounts) = tokenBank.getTopUsers(10);
        assertEq(users.length, 2);
        assertEq(users[0], user1);
        assertEq(amounts[0], 200 ether);
        assertEq(users[1], user2);
        assertEq(amounts[1], 50 ether);
    }

    function test_UpdateRankingOnWithdraw() public {
        // 用户1存入200 tokens
        vm.startPrank(user1);
        token.approve(address(tokenBank), 200 ether);
        tokenBank.deposit(200 ether);
        vm.stopPrank();
        
        // 用户2存入150 tokens
        vm.startPrank(user2);
        token.approve(address(tokenBank), 150 ether);
        tokenBank.deposit(150 ether);
        vm.stopPrank();
        
        // 用户1取出120 tokens，剩余80，应该排第二
        vm.startPrank(user1);
        tokenBank.withdraw(120 ether);
        vm.stopPrank();
        
        // 检查排名，应该是 user2, user1
        (address[] memory users, uint256[] memory amounts) = tokenBank.getTopUsers(10);
        assertEq(users.length, 2);
        assertEq(users[0], user2);
        assertEq(amounts[0], 150 ether);
        assertEq(users[1], user1);
        assertEq(amounts[1], 80 ether);
    }

    function test_MaxTopUsersLimit() public {
        // 存入所有11个用户，每个用户存款金额不同
        vm.startPrank(user1);
        token.approve(address(tokenBank), 100 ether);
        tokenBank.deposit(100 ether);
        vm.stopPrank();
        
        vm.startPrank(user2);
        token.approve(address(tokenBank), 200 ether);
        tokenBank.deposit(200 ether);
        vm.stopPrank();
        
        vm.startPrank(user3);
        token.approve(address(tokenBank), 300 ether);
        tokenBank.deposit(300 ether);
        vm.stopPrank();
        
        vm.startPrank(user4);
        token.approve(address(tokenBank), 400 ether);
        tokenBank.deposit(400 ether);
        vm.stopPrank();
        
        vm.startPrank(user5);
        token.approve(address(tokenBank), 500 ether);
        tokenBank.deposit(500 ether);
        vm.stopPrank();
        
        vm.startPrank(user6);
        token.approve(address(tokenBank), 600 ether);
        tokenBank.deposit(600 ether);
        vm.stopPrank();
        
        vm.startPrank(user7);
        token.approve(address(tokenBank), 700 ether);
        tokenBank.deposit(700 ether);
        vm.stopPrank();
        
        vm.startPrank(user8);
        token.approve(address(tokenBank), 800 ether);
        tokenBank.deposit(800 ether);
        vm.stopPrank();
        
        vm.startPrank(user9);
        token.approve(address(tokenBank), 900 ether);
        tokenBank.deposit(900 ether);
        vm.stopPrank();
        
        vm.startPrank(user10);
        token.approve(address(tokenBank), 1000 ether);
        tokenBank.deposit(1000 ether);
        vm.stopPrank();
        
        // 这时候用户11存入50 ether，不应该进入前10名
        vm.startPrank(user11);
        token.approve(address(tokenBank), 50 ether);
        tokenBank.deposit(50 ether);
        vm.stopPrank();
        
        // 检查排名，应该只有10个用户，并且按照金额从大到小排序
        (address[] memory users, uint256[] memory amounts) = tokenBank.getTopUsers(10);
        assertEq(users.length, 10);
        assertEq(users[0], user10);
        assertEq(amounts[0], 1000 ether);
        assertEq(users[9], user1);
        assertEq(amounts[9], 100 ether);
        
        // 确认user11没有进入榜单
        bool user11InList = false;
        for (uint i = 0; i < users.length; i++) {
            if (users[i] == user11) {
                user11InList = true;
                break;
            }
        }
        assertFalse(user11InList);
    }

    function test_UserEntersAndExitsList() public {
        // 先添加10个用户，使用真实的测试用户地址
        address[10] memory testUsers = [user1, user2, user3, user4, user5, user6, user7, user8, user9, user10];
        for (uint i = 0; i < 10; i++) {
            vm.startPrank(testUsers[i]);
            token.approve(address(tokenBank), (i + 1) * 100 ether);
            tokenBank.deposit((i + 1) * 100 ether);
            vm.stopPrank();
        }
        
        // 用户11存入1100 tokens，应该进入前10
        vm.startPrank(user11);
        token.approve(address(tokenBank), 1100 ether);
        tokenBank.deposit(1100 ether);
        vm.stopPrank();
        
        // 检查排名，user11应该在第一位，user1应该被踢出
        (address[] memory users, uint256[] memory amounts) = tokenBank.getTopUsers(10);
        assertEq(users.length, 10);
        assertEq(users[0], user11);
        assertEq(amounts[0], 1100 ether);
        
        // 确认user1不在榜单中
        bool user1InList = false;
        for (uint i = 0; i < users.length; i++) {
            if (users[i] == user1) {
                user1InList = true;
                break;
            }
        }
        assertFalse(user1InList);
    }
} 