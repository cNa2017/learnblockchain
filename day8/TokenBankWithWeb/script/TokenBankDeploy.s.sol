// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/TokenBank.sol";

contract TokenBankDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("user1PrivateKey");
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署MyToken合约并铸造初始代币
        uint256 initialSupply = 1000000 * 10**18; // 100万代币
        MyToken token = new MyToken(initialSupply);
        console.log("MyToken address: %s", address(token));
        
        // 部署TokenBank合约并传入MyToken地址
        TokenBank bank = new TokenBank(address(token));
        console.log("TokenBank address: %s", address(bank));
        
        vm.stopBroadcast();
    }
}