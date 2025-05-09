// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenBank.sol";
import "../src/MyToken.sol";

contract TokenBankTest is Test {
    TokenBank public tokenBank;
    IERC20 public token;
    address public user = address(1);
    
    function setUp() public {
        token = IERC20(address(new MyToken(1000 ether)));
        tokenBank = new TokenBank(address(token));
        
        // Transfer tokens to user
        token.transfer(user, 1000 ether);
    }
    
    function test_Deposit() public {
        vm.startPrank(user);
        token.approve(address(tokenBank), 100 ether);
        tokenBank.deposit(100 ether);
        vm.stopPrank();
        
        assertEq(tokenBank.balances(user), 100 ether);
        assertEq(token.balanceOf(address(tokenBank)), 100 ether);
    }
    
    function test_Withdraw() public {
        // First deposit
        vm.startPrank(user);
        token.approve(address(tokenBank), 100 ether);
        tokenBank.deposit(100 ether);
        
        // Then withdraw
        tokenBank.withdraw(50 ether);
        vm.stopPrank();
        
        assertEq(tokenBank.balances(user), 50 ether);
        assertEq(token.balanceOf(user), 950 ether);
    }
    
    function test_DepositZeroAmountReverts() public {
        vm.startPrank(user);
        token.approve(address(tokenBank), 100);
        vm.expectRevert("Amount must be greater than 0");
        tokenBank.deposit(0);
        vm.stopPrank();
    }
    
    function test_WithdrawMoreThanBalanceReverts() public {
        vm.startPrank(user);
        token.approve(address(tokenBank), 100 ether);
        tokenBank.deposit(100 ether);
        vm.expectRevert("Insufficient balance");
        tokenBank.withdraw(101 ether);
        vm.stopPrank();
    }
}

