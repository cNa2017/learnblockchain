// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {KKToken} from "src/StakingPool/KKToken.sol";
import {StakingPool} from "src/StakingPool/StakingPool.sol";

contract DeployStakingPool is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署KK Token
        console.log("Deploying KK Token...");
        KKToken kkToken = new KKToken();
        console.log("KK Token deployed at:", address(kkToken));
        
        // 部署StakingPool
        console.log("Deploying Staking Pool...");
        StakingPool stakingPool = new StakingPool(address(kkToken));
        console.log("Staking Pool deployed at:", address(stakingPool));
        
        // 将KK Token的所有权转移给StakingPool
        console.log("Transferring KK Token ownership to Staking Pool...");
        kkToken.transferOwnership(address(stakingPool));
        console.log("Ownership transferred successfully");
        
        vm.stopBroadcast();
        
        // 验证部署
        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("KK Token address:", address(kkToken));
        console.log("KK Token name:", kkToken.name());
        console.log("KK Token symbol:", kkToken.symbol());
        console.log("KK Token owner:", kkToken.owner());
        console.log("");
        console.log("Staking Pool address:", address(stakingPool));
        console.log("Reward token:", address(stakingPool.rewardToken()));
        console.log("Reward per block:", stakingPool.REWARD_PER_BLOCK() / 1e18, "KK");
        console.log("Total staked:", stakingPool.totalStaked());
        console.log("");
        console.log("Deployment completed successfully!");
    }
} 