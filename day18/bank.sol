// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";


// 开发一个Bank合约，用于测试chainlink的automation
/**
    Bank合约中需要三个函数：用于存款、取款、chainlink自动取款到admin
    Automation合约中需要两个函数：checkUpkeep、performUpkeep
        checkUpkeep：检查是Bank余额是否大于0.001ETH，是则返回true，否则返回false
        performUpkeep：执行Bank合约自动取款到admin
 */ 

contract Bank {
    address public admin;
    mapping(address => uint256) public balance;

    constructor() {
        admin = msg.sender;
    }

    function deposit() public payable {
        balance[msg.sender] += msg.value;
    }

    function withdraw() public {
        require(balance[msg.sender] > 0.001 ether, "Balance is less than 0.001 ether");
        uint value = balance[msg.sender];
        balance[msg.sender] = 0;
        payable(msg.sender).transfer(value);
    }

    function withdrawToAdmin() public {
        // require(msg.sender == 0x86EFBD0b6736Bed994962f9797049422A3A8E8Ad, "Only chainlink can withdraw");

        payable(admin).transfer(address(this).balance/2);
    }

    
}   

contract Automation is AutomationCompatibleInterface{
    address public bank;
    constructor(address _bank) {
        bank = _bank;
    }

    function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
        if (bank.balance > 0.001 ether) {
            upkeepNeeded = true;
        }

    }

    function performUpkeep(bytes calldata performData) external override {
        Bank(bank).withdrawToAdmin();
    }
}