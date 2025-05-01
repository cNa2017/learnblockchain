// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBank {
    // 管理员提取资金（使用更安全的转账方式）
    function withdraw() external ;
}


contract Bank {

    mapping(address => uint256) public balances;
    address public admin;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin {
        require (msg.sender == admin, "Unauthorized! Bank");
        _;
    }
    // 管理员提取资金（使用更安全的转账方式）
    function withdraw() external onlyAdmin{
        (bool success, ) = payable(admin).call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

}

contract BigBank is Bank{
    modifier greaterAmountLimit{
        require (msg.value >0.001 ether,"Too little money!");
        _;
    }
    receive() external payable greaterAmountLimit{ 
        balances[msg.sender] += msg.value;
    }  

    function trasferAdmin (address newAdmin) public onlyAdmin{
        admin = newAdmin;
    }
}

contract Admin {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    receive() external payable { }
    
    modifier onlyOwner {
         require (msg.sender == owner, "Unauthorized! Admin"); 
         _;
    }

    function adminWithdraw(IBank bank) public onlyOwner{
        bank.withdraw();
    }

}