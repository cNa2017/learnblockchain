// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20_Extend} from "../src/NFTMarketExchange.sol";
// import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ISignatureTransfer} from "permit2-light-sdk/sdk/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "permit2-light-sdk/sdk/IAllowanceTransfer.sol";
import {IPermit2} from "permit2-light-sdk/sdk/IPermit2.sol";

contract TokenBank {
    ERC20_Extend public token;
    mapping(address => uint256) public balances;
    IPermit2 public immutable permit2;
    address public immutable permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // 可迭代链表结构，用于记录前10名存款用户
    address public constant HEAD = address(1);
    address public constant TAIL = address(999);
    uint256 public constant MAX_TOP_USERS = 10;
    uint256 public topUsersCount;
    
    // next映射，记录当前地址的下一个地址
    mapping(address => address) public next;
    
    // 初始化链表
    constructor(address _token) {
        token = ERC20_Extend(_token);
        permit2 = IPermit2(permit2Address);
        
        // 初始化链表，HEAD -> TAIL
        next[HEAD] = TAIL;
        topUsersCount = 0;
    }

    // 更新前10排名
    function _updateTopUsers(address user) internal {
        // 如果用户已在链表中，先移除
        if (next[user] != address(0)) {
            _removeFromList(user);
        }
        
        // 寻找合适的插入位置
        address current = HEAD;
        while (next[current] != TAIL) {
            // 如果下一个用户余额小于当前用户，在这里插入
            if (balances[next[current]] < balances[user]) {
                break;
            }
            current = next[current];
        }
        
        // 插入用户到链表中
        next[user] = next[current];
        next[current] = user;
        
        // 如果超过最大数量，移除最后一个
        if (topUsersCount < MAX_TOP_USERS) {
            topUsersCount++;
        } else {
            // 找到倒数第二个节点
            address beforeLast = HEAD;
            while (next[next[beforeLast]] != TAIL) {
                beforeLast = next[beforeLast];
            }
            
            // 移除最后一个节点
            address last = next[beforeLast];
            next[beforeLast] = TAIL;
            next[last] = address(0); // 清除引用
        }
    }
    
    // 从链表中移除用户
    function _removeFromList(address user) internal {
        address current = HEAD;
        while (next[current] != TAIL) {
            if (next[current] == user) {
                next[current] = next[user];
                next[user] = address(0);
                topUsersCount--;
                break;
            }
            current = next[current];
        }
    }
    
    // 获取前N名用户
    function getTopUsers(uint256 n) external view returns (address[] memory, uint256[] memory) {
        uint256 count = n > topUsersCount ? topUsersCount : n;
        address[] memory users = new address[](count);
        uint256[] memory amounts = new uint256[](count);
        
        address current = next[HEAD];
        for (uint256 i = 0; i < count && current != TAIL; i++) {
            users[i] = current;
            amounts[i] = balances[current];
            current = next[current];
        }
        
        return (users, amounts);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        balances[msg.sender] += amount;
        
        // 更新排名
        _updateTopUsers(msg.sender);
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
        
        // 更新排名
        _updateTopUsers(msg.sender);
    }

    // 使用Permit2进行签名验证和token转账
    function depositWithPermit2(
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        bytes calldata signature
    ) external {
        require(amount > 0, "Amount must be greater than 0");
        
        // 创建单个Token的权限结构
        ISignatureTransfer.TokenPermissions memory permitted = ISignatureTransfer.TokenPermissions({
            token: address(token),
            amount: amount
        });
        
        // 创建SignatureTransfer结构
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: permitted,
            nonce: nonce, // 使用传入的nonce值
            deadline: deadline
        });
        
        // 创建转账详情
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(this),
            requestedAmount: amount
        });
        
        // 使用Permit2进行签名验证和token转账
        permit2.permitTransferFrom(
            permit,
            transferDetails,
            msg.sender,
            signature
        );
        
        // 更新余额
        balances[msg.sender] += amount;
        
        // 更新排名
        _updateTopUsers(msg.sender);
    }

    // 使用Permit2的AllowanceTransfer进行token转账
    function depositWithPermit2Allowance(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        
        // 使用AllowanceTransfer从用户转账到合约
        IAllowanceTransfer(address(permit2)).transferFrom(
            msg.sender,  // from
            address(this), // to
            uint160(amount), // amount
            address(token) // token
        );
        
        // 更新余额
        balances[msg.sender] += amount;
        
        // 更新排名
        _updateTopUsers(msg.sender);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        balances[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "Transfer failed");
        
        // 更新排名，如果余额降低了，可能需要调整位置
        if (next[msg.sender] != address(0)) {
            _updateTopUsers(msg.sender);
        }
    }
}