// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20_Extend} from "../src/NFTMarketExchange.sol";
// import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract TokenBank {
    ERC20_Extend public token;
    mapping(address => uint256) public balances;

    constructor(address _token) {
        token = ERC20_Extend(_token);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        balances[msg.sender] += amount;
    }

    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(amount > 0, "Amount must be greater than 0");
        
        // 使用permit函数进行授权，无需事先调用approve
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);
        
        // 执行转账
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // 更新余额
        balances[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        balances[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "Transfer failed");
    }
}