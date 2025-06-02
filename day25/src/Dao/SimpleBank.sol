// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SimpleBank
 * @dev 简单银行合约，支持存款、提款和管理员转移功能
 *      现在支持通过治理合约管理 withdraw 功能
 */
contract SimpleBank {
    // 状态变量
    address public admin;
    uint256 public totalDeposits;
    
    // 事件定义
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed admin, uint256 amount);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    
    // 修饰器：仅管理员可调用
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }
    
    /**
     * @dev 构造函数，设置初始管理员
     * @param _admin 初始管理员地址，如果传入零地址则使用部署者作为管理员
     */
    constructor(address _admin) {
        if (_admin == address(0)) {
            admin = msg.sender;
        } else {
            admin = _admin;
        }
    }

    /**
     * @dev 存入ETH到银行合约
     * 任何人都可以调用此函数存入ETH
     */
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        totalDeposits += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @dev 提取指定数量的ETH给管理员
     * 只有管理员可以调用此函数
     * @param amount 要提取的ETH数量（以wei为单位）
     */
    function withdraw(uint256 amount) external onlyAdmin {
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient balance");
        
        totalDeposits -= amount;
        
        // 使用call方法安全转账
        (bool success, ) = payable(admin).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdraw(admin, amount);
    }

    /**
     * @dev 提取指定数量的ETH到指定地址
     * 只有管理员可以调用此函数，支持治理合约调用
     * @param to 接收地址
     * @param amount 要提取的ETH数量（以wei为单位）
     */
    function withdrawTo(address payable to, uint256 amount) external onlyAdmin {
        require(to != address(0), "Recipient cannot be zero address");
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient balance");
        
        totalDeposits -= amount;
        
        // 使用call方法安全转账
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdraw(to, amount);
    }

    /**
     * @dev 转移管理员权限给新地址
     * 只有当前管理员可以调用此函数
     * @param newAdmin 新管理员的地址
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "New admin cannot be zero address");
        require(newAdmin != admin, "New admin must be different from current admin");
        
        address previousAdmin = admin;
        admin = newAdmin;
        
        emit AdminTransferred(previousAdmin, newAdmin);
    }

    /**
     * @dev 查询合约当前余额
     * @return 合约的ETH余额（以wei为单位）
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev 查询总存款金额
     * @return 总存款金额（以wei为单位）
     */
    function getTotalDeposits() external view returns (uint256) {
        return totalDeposits;
    }

    /**
     * @dev 紧急暂停功能（可通过治理添加）
     * 现在只是占位符，展示治理可以扩展的功能
     */
    function emergencyPause() external onlyAdmin {
        // 实现紧急暂停逻辑
        // 这个函数可以通过治理提案来调用
    }
}
