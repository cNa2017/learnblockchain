// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {InscriptionFactory, InscriptionToken} from "../src/Inscription.sol";

contract InscriptionTest is Test {
    InscriptionFactory public factory;
    address public owner;
    address public user1;
    address public user2;
    
    // 测试参数 - 使用更小的值
    string constant SYMBOL = "TEST";
    uint256 constant MAX_SUPPLY = 1000 * 10**18;
    uint256 constant PER_MINT = 1000;
    uint256 constant PRICE = 0.001 * 10**18;  // 降低单价以确保总价不超过最大限制

    function setUp() public {
        // 设置测试账户
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 给测试账户转入以太币
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        
        // 部署工厂合约
        vm.prank(owner);
        factory = new InscriptionFactory();
        console2.log("Factory deployed at:", address(factory));
        console2.log("Token implementation at:", factory.tokenImplementation());
        // console2.log("MAX_MINT_COST:", factory.MAX_MINT_COST());
    }
    
    function test_DeployInscription() public {
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(SYMBOL, MAX_SUPPLY, PER_MINT, PRICE);
        console2.log("Token deployed at:", tokenAddr);
        console2.log("Mint cost:", PER_MINT * PRICE);
        
        // 验证代币信息
        InscriptionToken token = InscriptionToken(tokenAddr);
        assertEq(token.factory(), address(factory));
        assertEq(token.creator(), user1);
        assertEq(token.maxSupply(), MAX_SUPPLY);
        assertEq(token.perMint(), PER_MINT);
        assertEq(token.price(), PRICE);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.name(), "Meme");
        assertEq(token.totalMinted(), 0);
    }
    
    function test_MintInscription() public {
        // 先部署代币
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(SYMBOL, MAX_SUPPLY, PER_MINT, PRICE);
        InscriptionToken token = InscriptionToken(tokenAddr);
        console2.log("Token deployed at:", tokenAddr);
        
        // 记录初始余额
        uint256 initialOwnerBalance = owner.balance;
        uint256 initialCreatorBalance = user1.balance;
        uint256 totalPayment = PER_MINT * PRICE;
        
        // user2 铸造代币
        console2.log("Attempting to mint tokens");
        console2.log("Required payment:", totalPayment);
        console2.log("User2 balance:", user2.balance);
        
        vm.prank(user2);
        factory.mintInscription{value: totalPayment}(tokenAddr);
        
        // 验证代币铸造
        assertEq(token.totalMinted(), PER_MINT);
        assertEq(token.balanceOf(user2), PER_MINT);
        
        // 验证费用分配
        uint256 platformFee = totalPayment * 1 / 100; // 1%平台费
        uint256 creatorFee = totalPayment - platformFee;
        
        assertEq(owner.balance, initialOwnerBalance + platformFee);
        assertEq(user1.balance, initialCreatorBalance + creatorFee);
    }
    
    function test_FailMintInscriptionInsufficientPayment() public {
        // 先部署代币
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(SYMBOL, MAX_SUPPLY, PER_MINT, PRICE);
        console2.log("Token deployed at:", tokenAddr);
        
        // user2 尝试以低于要求的价格铸造代币
        uint256 totalPayment = PER_MINT * PRICE;
        uint256 insufficientAmount = totalPayment - 1;
        console2.log("Required payment:", totalPayment);
        console2.log("Attempting to mint with insufficient payment:", insufficientAmount);
        
        vm.prank(user2);
        vm.expectRevert("Insufficient payment");
        factory.mintInscription{value: insufficientAmount}(tokenAddr);
    }
    
    function test_FailMintInscriptionExceedsMaxSupply() public {
        // 部署小供应量的代币
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(SYMBOL, PER_MINT, PER_MINT, PRICE);
        console2.log("Token deployed at:", tokenAddr);
        console2.log("Max supply:", PER_MINT);
        
        uint256 totalPayment = PER_MINT * PRICE;
        
        // 第一次铸造应该成功
        console2.log("First mint attempt");
        vm.prank(user2);
        factory.mintInscription{value: totalPayment}(tokenAddr);
        
        // 第二次铸造应该失败，因为超出最大供应量
        console2.log("Second mint attempt (should fail)");
        vm.prank(user2);
        vm.expectRevert("Exceeds max supply");
        factory.mintInscription{value: totalPayment}(tokenAddr);
    }
    
    function test_MultipleMints() public {
        // 部署代币
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(SYMBOL, PER_MINT * 3, PER_MINT, PRICE);
        InscriptionToken token = InscriptionToken(tokenAddr);
        console2.log("Token deployed at:", tokenAddr);
        console2.log("Max supply:", PER_MINT * 3);
        
        uint256 totalPayment = PER_MINT * PRICE;
        
        // 记录初始余额
        uint256 initialOwnerBalance = owner.balance;
        uint256 initialCreatorBalance = user1.balance;
        
        // 多次铸造
        for (uint i = 0; i < 3; i++) {
            console2.log("Mint attempt:", i + 1);
            
            // 记录铸造前的余额
            uint256 ownerBalanceBeforeMint = owner.balance;
            uint256 creatorBalanceBeforeMint = user1.balance;
            
            vm.prank(user2);
            factory.mintInscription{value: totalPayment}(tokenAddr);
            
            // 验证代币铸造
            assertEq(token.totalMinted(), PER_MINT * (i + 1));
            assertEq(token.balanceOf(user2), PER_MINT * (i + 1));
            
            // 验证每次铸造的费用分配
            uint256 platformFee = totalPayment * 1 / 100; // 1%平台费
            uint256 creatorFee = totalPayment - platformFee;
            
            assertEq(owner.balance, ownerBalanceBeforeMint + platformFee);
            assertEq(user1.balance, creatorBalanceBeforeMint + creatorFee);
        }
        
        // 验证总体费用分配
        uint256 totalPlatformFee = (totalPayment * 1 / 100) * 3; // 1%平台费 * 3次铸造
        uint256 totalCreatorFee = (totalPayment - (totalPayment * 1 / 100)) * 3;
        
        assertEq(owner.balance, initialOwnerBalance + totalPlatformFee);
        assertEq(user1.balance, initialCreatorBalance + totalCreatorFee);
        
        // 再次铸造应该失败
        console2.log("Final mint attempt (should fail)");
        vm.prank(user2);
        vm.expectRevert("Exceeds max supply");
        factory.mintInscription{value: totalPayment}(tokenAddr);
    }
    
} 