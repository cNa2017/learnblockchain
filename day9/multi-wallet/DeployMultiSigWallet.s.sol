// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

/**
 * @title DeployMultiSigWallet
 * @dev 部署多签钱包合约的脚本
 */
contract DeployMultiSigWallet is Script {
    // 钱包配置
    address[] public owners;
    uint256 public numConfirmationsRequired = 2;
    
    function setUp() public {
        // 从环境变量获取配置
        string memory ownersStr = vm.envOr("OWNERS", string(""));
        
        // 至少添加3个默认地址
        if (bytes(ownersStr).length == 0) {
            owners = new address[](3);
            owners[0] = vm.envOr("OWNER1", address(0x123)); // 默认地址
            owners[1] = vm.envOr("OWNER2", address(0x456)); // 默认地址
            owners[2] = vm.envOr("OWNER3", address(0x789)); // 默认地址
        } else {
            // 解析字符串中的地址列表 (格式: "0x123,0x456,0x789")
            // 简化处理，实际部署时根据需要扩展
            // 这里省略具体实现
        }
        
        // 从环境变量获取确认门槛
        numConfirmationsRequired = vm.envOr("CONFIRMATIONS", uint256(2));
        
        // 确保确认数量合理
        require(numConfirmationsRequired > 0 && numConfirmationsRequired <= owners.length, 
                "Invalid confirmation threshold");
    }
    
    function run() public returns (MultiSigWallet) {
        // 启动广播
        vm.startBroadcast();
        
        // 部署多签钱包
        MultiSigWallet wallet = new MultiSigWallet(owners, numConfirmationsRequired);
        
        // 结束广播
        vm.stopBroadcast();
        
        return wallet;
    }
} 