// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {VestingToken, Vesting} from "../src/Vesting.sol";

/**
 * @title DeployVesting
 * @dev 部署 Vesting 系统的脚本
 */
contract DeployVesting is Script {
    uint256 public constant VESTING_AMOUNT = 1_000_000 * 10**18; // 100万代币
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // 从环境变量获取受益人地址，如果没有则使用部署者地址
        address beneficiary;
        try vm.envAddress("BENEFICIARY") returns (address _beneficiary) {
            beneficiary = _beneficiary;
        } catch {
            beneficiary = deployer;
            console.log("Using deployer as beneficiary");
        }
        
        console.log("Deployer:", deployer);
        console.log("Beneficiary:", beneficiary);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署 VestingToken
        console.log("Deploying VestingToken...");
        VestingToken token = new VestingToken(deployer);
        console.log("VestingToken deployed at:", address(token));
        console.log("Total supply:", token.totalSupply());
        
        // 2. 部署 Vesting 合约
        console.log("Deploying Vesting contract...");
        Vesting vesting = new Vesting(beneficiary, address(token));
        console.log("Vesting contract deployed at:", address(vesting));
        
        // 3. 转移代币到 Vesting 合约
        console.log("Transferring tokens to vesting contract...");
        token.transfer(address(vesting), VESTING_AMOUNT);
        console.log("Transferred amount:", VESTING_AMOUNT);
        
        // 验证转账
        uint256 vestingBalance = token.balanceOf(address(vesting));
        console.log("Vesting contract balance:", vestingBalance);
        
        // 打印关键信息
        console.log("=== Deployment Summary ===");
        console.log("VestingToken address:", address(token));
        console.log("Vesting contract address:", address(vesting));
        console.log("Beneficiary:", vesting.beneficiary());
        console.log("Start time:", vesting.getStartTime());
        console.log("Cliff end time:", vesting.getCliffEnd());
        console.log("Vesting end time:", vesting.getVestingEnd());
        console.log("Tokens in vesting:", vestingBalance);
        
        vm.stopBroadcast();
    }
    
    /**
     * @dev 计算时间戳对应的日期（用于调试）
     */
    function timestampToDate(uint256 timestamp) external pure returns (string memory) {
        // 简单的时间戳转换（仅用于调试）
        uint256 day = timestamp / 86400;
        return string(abi.encodePacked("Day: ", day));
    }
} 