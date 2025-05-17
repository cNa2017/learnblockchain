// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title MultiSigWallet
 * @dev 一个简单的多签钱包合约，支持多个持有人共同管理资金
 */
contract MultiSigWallet {
    // 事件
    event Deposit(address indexed sender, uint amount);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    // 存储多签持有人地址
    address[] public owners;
    // 地址是否为多签持有人的映射
    mapping(address => bool) public isOwner;
    // 执行交易所需的确认数量
    uint public numConfirmationsRequired;

    // 交易结构体
    struct Transaction {
        address to;      // 目标地址
        uint value;      // 发送的ETH数量
        bytes data;      // 调用数据
        bool executed;   // 是否已执行
        uint numConfirmations; // 确认数量
    }

    // 交易数组
    Transaction[] public transactions;
    // 交易确认情况: txIndex => owner => confirmed
    mapping(uint => mapping(address => bool)) public isConfirmed;

    // 修饰器: 仅持有人可调用
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    // 修饰器: 指定交易存在
    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    // 修饰器: 指定交易未执行
    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    // 修饰器: 指定交易未被该持有人确认
    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    /**
     * @dev 构造函数
     * @param _owners 多签持有人地址数组
     * @param _numConfirmationsRequired 确认门槛数量
     */
    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "owners required");
        require(
            _numConfirmationsRequired > 0 && 
            _numConfirmationsRequired <= _owners.length,
            "invalid number of confirmations"
        );

        // 添加持有人
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    /**
     * @dev 接收ETH
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev 提交交易提案
     * @param _to 目标地址
     * @param _value ETH数量
     * @param _data 调用数据
     * @return 交易索引
     */
    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner returns (uint) {
        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
        return txIndex;
    }

    /**
     * @dev 确认交易
     * @param _txIndex 交易索引
     */
    function confirmTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /**
     * @dev 执行交易
     * @param _txIndex 交易索引
     */
    function executeTransaction(uint _txIndex)
        public
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    /**
     * @dev 撤销确认
     * @param _txIndex 交易索引
     */
    function revokeConfirmation(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    /**
     * @dev 获取持有人数量
     * @return 持有人数量
     */
    function getOwnersCount() public view returns (uint) {
        return owners.length;
    }

    /**
     * @dev 获取所有持有人
     * @return 持有人地址数组
     */
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /**
     * @dev 获取交易数量
     * @return 交易数量
     */
    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    /**
     * @dev 获取交易详情
     * @param _txIndex 交易索引
     * @return to 目标地址
     * @return value 交易金额
     * @return data 调用数据
     * @return executed 是否已执行
     * @return numConfirmations 确认数量
     */
    function getTransaction(uint _txIndex)
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
} 