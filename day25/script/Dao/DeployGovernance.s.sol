// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {GovernanceToken} from "src/Dao/GovernanceToken.sol";
import {GovernanceTimelock} from "src/Dao/TimelockController.sol";
import {BankGovernor} from "src/Dao/BankGovernor.sol";
import {SimpleBank} from "src/Dao/SimpleBank.sol";

/**
 * @title DeployGovernance
 * @dev 部署完整的治理系统脚本
 */
contract DeployGovernance is Script {
    // 治理参数配置
    uint48 public constant VOTING_DELAY = 1; // 1个区块
    uint32 public constant VOTING_PERIOD = 50; // 50个区块
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18; // 1000个代币
    uint256 public constant QUORUM_PERCENTAGE = 4; // 4%
    uint256 public constant TIMELOCK_DELAY = 1 days; // 1天延迟

    function run() external {
        uint256 deployerPrivateKey;
        address deployer;
        
        // 尝试从环境变量获取私钥，如果失败则使用默认测试私钥
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
            deployer = vm.addr(deployerPrivateKey);
        } catch {
            // 使用默认的测试私钥（Anvil 的第一个账户）
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
            deployer = vm.addr(deployerPrivateKey);
        }
        
        console.log("Deploying governance contracts with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署治理代币
        console.log("Deploying GovernanceToken...");
        GovernanceToken token = new GovernanceToken();
        console.log("GovernanceToken deployed at:", address(token));

        // 2. 部署时间锁合约
        console.log("Deploying GovernanceTimelock...");
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = deployer; // 临时设置为部署者
        executors[0] = deployer; // 临时设置为部署者
        
        GovernanceTimelock timelock = new GovernanceTimelock(
            TIMELOCK_DELAY,
            proposers,
            executors,
            deployer // 设置部署者为临时管理员
        );
        console.log("GovernanceTimelock deployed at:", address(timelock));

        // 3. 部署治理合约
        console.log("Deploying BankGovernor...");
        BankGovernor governor = new BankGovernor(
            token,
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE
        );
        console.log("BankGovernor deployed at:", address(governor));

        // 4. 设置时间锁的权限
        console.log("Setting up timelock roles...");
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        
        // 撤销部署者的临时权限
        timelock.revokeRole(proposerRole, deployer);
        timelock.revokeRole(executorRole, deployer);
        
        // 设置正确的权限
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0)); // 任何人都可以执行
        
        // 5. 部署银行合约，设置时间锁为管理员
        console.log("Deploying SimpleBank with timelock as admin...");
        SimpleBank bank = new SimpleBank(address(timelock));
        console.log("SimpleBank deployed at:", address(bank));

        // 6. 设置代币委托（用于投票）
        console.log("Delegating tokens to deployer for voting...");
        token.delegate(deployer);

        // 7. 分发一些代币给测试账户（如果需要）
        console.log("Minting additional tokens for testing...");
        token.mint(deployer, 10000 * 10**18); // 额外铸造10000个代币用于测试

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("GovernanceToken:", address(token));
        console.log("GovernanceTimelock:", address(timelock));
        console.log("BankGovernor:", address(governor));
        console.log("SimpleBank:", address(bank));
        console.log("\n=== Configuration ===");
        console.log("Voting Delay:", VOTING_DELAY, "blocks");
        console.log("Voting Period:", VOTING_PERIOD, "blocks");
        console.log("Proposal Threshold:", PROPOSAL_THRESHOLD / 10**18, "tokens");
        console.log("Quorum:", QUORUM_PERCENTAGE, "%");
        console.log("Timelock Delay:", TIMELOCK_DELAY / 1 days, "days");
        console.log("\n=== Next Steps ===");
        console.log("1. Deposit some ETH to the bank using: bank.deposit{value: amount}()");
        console.log("2. Create a proposal using: governor.propose()");
        console.log("3. Vote on the proposal using: governor.castVote()");
        console.log("4. Execute the proposal after timelock delay");
    }
} 