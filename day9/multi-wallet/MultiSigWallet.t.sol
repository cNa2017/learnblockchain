// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    // 测试账户
    address public owner1;
    address public owner2;
    address public owner3;
    address public nonOwner;
    
    // 测试合约
    MultiSigWallet public wallet;
    
    // 初始化
    function setUp() public {
        // 创建测试账户
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        nonOwner = makeAddr("nonOwner");
        
        // 给测试账户充值
        vm.deal(owner1, 10 ether);
        vm.deal(owner2, 10 ether);
        vm.deal(owner3, 10 ether);
        vm.deal(nonOwner, 10 ether);
        
        // 创建多签钱包，需要2/3签名
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        
        wallet = new MultiSigWallet(owners, 2);
    }
    
    // 测试构造函数
    function test_Constructor() public {
        // 验证持有人数量
        assertEq(wallet.getOwnersCount(), 3);
        
        // 验证确认门槛
        assertEq(wallet.numConfirmationsRequired(), 2);
        
        // 验证持有人身份
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertFalse(wallet.isOwner(nonOwner));
    }
    
    // 测试存款功能
    function test_Deposit() public {
        // 发送ETH到合约
        vm.deal(address(wallet), 0);
        assertEq(address(wallet).balance, 0);
        
        payable(address(wallet)).transfer(1 ether);
        assertEq(address(wallet).balance, 1 ether);
    }
    
    // 测试提交交易
    function test_SubmitTransaction() public {
        // 持有人1提交交易
        vm.prank(owner1);
        uint txIndex = wallet.submitTransaction(nonOwner, 0.5 ether, "");
        
        // 验证交易信息
        assertEq(wallet.getTransactionCount(), 1);
        
        (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        ) = wallet.getTransaction(txIndex);
        
        assertEq(to, nonOwner);
        assertEq(value, 0.5 ether);
        assertEq(data.length, 0);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }
    
    // 测试非持有人无法提交交易
    function test_SubmitTransaction_revert_NotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.submitTransaction(nonOwner, 0.5 ether, "");
    }
    
    // 测试确认交易
    function test_ConfirmTransaction() public {
        // 为合约添加ETH
        vm.deal(address(wallet), 1 ether);
        
        // 持有人1提交交易
        vm.prank(owner1);
        uint txIndex = wallet.submitTransaction(nonOwner, 0.5 ether, "");
        
        // 持有人1确认交易
        vm.prank(owner1);
        wallet.confirmTransaction(txIndex);
        
        // 验证确认状态
        (,,,,uint numConfirmations) = wallet.getTransaction(txIndex);
        assertEq(numConfirmations, 1);
        assertTrue(wallet.isConfirmed(txIndex, owner1));
    }
    
    // 测试执行交易
    function test_ExecuteTransaction() public {
        // 为合约添加ETH
        vm.deal(address(wallet), 1 ether);
        
        // 记录初始余额
        uint initialBalance = nonOwner.balance;
        
        // 持有人1提交交易
        vm.prank(owner1);
        uint txIndex = wallet.submitTransaction(nonOwner, 0.5 ether, "");
        
        // 持有人1确认交易
        vm.prank(owner1);
        wallet.confirmTransaction(txIndex);
        
        // 持有人2确认交易
        vm.prank(owner2);
        wallet.confirmTransaction(txIndex);
        
        // 任何人都可以执行已确认的交易
        vm.prank(nonOwner);
        wallet.executeTransaction(txIndex);
        
        // 验证交易执行
        (,,,bool executed,) = wallet.getTransaction(txIndex);
        assertTrue(executed);
        
        // 验证资金已转移
        assertEq(nonOwner.balance, initialBalance + 0.5 ether);
        assertEq(address(wallet).balance, 0.5 ether);
    }
    
    // 测试确认不足无法执行
    function test_ExecuteTransaction_revert_NotEnoughConfirmations() public {
        // 为合约添加ETH
        vm.deal(address(wallet), 1 ether);
        
        // 持有人1提交交易
        vm.prank(owner1);
        uint txIndex = wallet.submitTransaction(nonOwner, 0.5 ether, "");
        
        // 只有持有人1确认
        vm.prank(owner1);
        wallet.confirmTransaction(txIndex);
        
        // 尝试执行，应该失败
        vm.expectRevert("cannot execute tx");
        wallet.executeTransaction(txIndex);
    }
    
    // 测试撤销确认
    function test_RevokeConfirmation() public {
        // 持有人1提交交易
        vm.prank(owner1);
        uint txIndex = wallet.submitTransaction(nonOwner, 0.5 ether, "");
        
        // 持有人1确认交易
        vm.prank(owner1);
        wallet.confirmTransaction(txIndex);
        
        // 验证初始确认
        (,,,,uint numConfirmations) = wallet.getTransaction(txIndex);
        assertEq(numConfirmations, 1);
        
        // 持有人1撤销确认
        vm.prank(owner1);
        wallet.revokeConfirmation(txIndex);
        
        // 验证确认已撤销
        (,,,,numConfirmations) = wallet.getTransaction(txIndex);
        assertEq(numConfirmations, 0);
        assertFalse(wallet.isConfirmed(txIndex, owner1));
    }
    
    // 测试执行后无法撤销确认
    function test_RevokeConfirmation_revert_AlreadyExecuted() public {
        // 为合约添加ETH
        vm.deal(address(wallet), 1 ether);
        
        // 持有人1提交交易
        vm.prank(owner1);
        uint txIndex = wallet.submitTransaction(nonOwner, 0.5 ether, "");
        
        // 持有人1确认交易
        vm.prank(owner1);
        wallet.confirmTransaction(txIndex);
        
        // 持有人2确认交易
        vm.prank(owner2);
        wallet.confirmTransaction(txIndex);
        
        // 执行交易
        wallet.executeTransaction(txIndex);
        
        // 尝试撤销确认，应该失败
        vm.prank(owner1);
        vm.expectRevert("tx already executed");
        wallet.revokeConfirmation(txIndex);
    }
} 