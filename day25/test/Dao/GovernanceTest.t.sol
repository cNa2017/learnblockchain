// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GovernanceToken} from "src/Dao/GovernanceToken.sol";
import {GovernanceTimelock} from "src/Dao/TimelockController.sol";
import {BankGovernor} from "src/Dao/BankGovernor.sol";
import {SimpleBank} from "src/Dao/SimpleBank.sol";
import {IGovernor} from "openzeppelin-contracts/contracts/governance/IGovernor.sol";

/**
 * @title GovernanceTest
 * @dev 治理系统完整测试套件
 */
contract GovernanceTest is Test {
    // 合约实例
    GovernanceToken public token;
    GovernanceTimelock public timelock;
    BankGovernor public governor;
    SimpleBank public bank;

    // 测试地址
    address public deployer = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // 治理参数
    uint48 public constant VOTING_DELAY = 1;
    uint32 public constant VOTING_PERIOD = 50;
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18;
    uint256 public constant QUORUM_PERCENTAGE = 4;
    uint256 public constant TIMELOCK_DELAY = 1 days;

    // 事件定义
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );

    function setUp() public {
        console.log("Setting up governance test environment...");
        
        // 1. 部署治理代币
        token = new GovernanceToken();
        
        // 2. 部署时间锁
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(this); // 临时设置为当前测试合约
        executors[0] = address(this); // 临时设置为当前测试合约
        
        timelock = new GovernanceTimelock(
            TIMELOCK_DELAY,
            proposers,
            executors,
            address(this) // 设置当前测试合约为管理员
        );
        
        // 3. 部署治理合约
        governor = new BankGovernor(
            token,
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE
        );
        
        // 4. 设置时间锁权限 - 先撤销初始权限，然后设置正确的权限
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        
        // 撤销测试合约的临时权限
        timelock.revokeRole(proposerRole, address(this));
        timelock.revokeRole(executorRole, address(this));
        
        // 设置正确的权限
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0)); // 任何人都可以执行
        
        // 5. 部署银行合约
        bank = new SimpleBank(address(timelock));
        
        // 6. 分发代币和委托投票权
        _setupTokensAndDelegation();
        
        // 7. 向银行存入一些ETH用于测试
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        bank.deposit{value: 5 ether}();
        
        // 8. 等待一个区块以确保投票权生效
        vm.roll(block.number + 1);
        
        console.log("Setup completed!");
        console.log("Token total supply:", token.totalSupply() / 10**18);
        console.log("Bank balance:", bank.getBalance() / 10**18, "ETH");
    }

    function _setupTokensAndDelegation() internal {
        // 分发代币
        token.mint(alice, 50000 * 10**18);   // Alice: 50,000 tokens
        token.mint(bob, 30000 * 10**18);     // Bob: 30,000 tokens  
        token.mint(charlie, 20000 * 10**18); // Charlie: 20,000 tokens
        
        // 委托投票权
        vm.prank(alice);
        token.delegate(alice);
        
        vm.prank(bob);
        token.delegate(bob);
        
        vm.prank(charlie);
        token.delegate(charlie);
        
        // deployer 也委托给自己
        token.delegate(deployer);
        
        // 等待一个区块以确保委托生效
        vm.roll(block.number + 1);
    }

    function test_TokenSetup() public view {
        // 验证代币分发和委托
        assertEq(token.balanceOf(alice), 50000 * 10**18);
        assertEq(token.balanceOf(bob), 30000 * 10**18);
        assertEq(token.balanceOf(charlie), 20000 * 10**18);
        
        // 验证投票权
        assertEq(token.getVotes(alice), 50000 * 10**18);
        assertEq(token.getVotes(bob), 30000 * 10**18);
        assertEq(token.getVotes(charlie), 20000 * 10**18);
    }

    function test_GovernorSettings() public {
        // 验证治理参数
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), PROPOSAL_THRESHOLD);
        
        // 查询前一个区块的法定人数以避免 ERC5805FutureLookup 错误
        uint256 previousBlock = block.number > 0 ? block.number - 1 : 0;
        assertEq(governor.quorum(previousBlock), 
            (token.totalSupply() * QUORUM_PERCENTAGE) / 100);
    }

    function test_CreateProposal() public {
        // 准备提案数据：从银行提取 1 ETH 到 Alice
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdrawTo(address,uint256)", 
            alice, 
            1 ether
        );
        
        string memory description = "Proposal: Withdraw 1 ETH to Alice for community reward";
        
        // Alice 创建提案（她有足够的代币）
        vm.prank(alice);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );
        
        // 验证提案状态
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
        
        console.log("Proposal created with ID:", proposalId);
        console.log("Proposal state:", uint256(governor.state(proposalId)));
    }

    function test_VoteOnProposal() public {
        // 创建提案
        uint256 proposalId = _createWithdrawProposal();
        
        // 等待投票延迟期结束
        vm.roll(block.number + VOTING_DELAY + 1);
        
        // 验证提案现在处于投票状态
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));
        
        // Alice 投赞成票
        vm.prank(alice);
        governor.castVote(proposalId, 1); // 1 = For
        
        // Bob 投赞成票
        vm.prank(bob);
        governor.castVote(proposalId, 1);
        
        // Charlie 投反对票
        vm.prank(charlie);
        governor.castVote(proposalId, 0); // 0 = Against
        
        // 验证投票结果
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = 
            governor.proposalVotes(proposalId);
        
        console.log("Against votes:", againstVotes / 10**18);
        console.log("For votes:", forVotes / 10**18);
        console.log("Abstain votes:", abstainVotes / 10**18);
        
        assertEq(againstVotes, 20000 * 10**18); // Charlie's votes
        assertEq(forVotes, 80000 * 10**18);     // Alice + Bob
        assertEq(abstainVotes, 0);
    }

    function test_ExecuteSuccessfulProposal() public {
        // 创建提案
        uint256 proposalId = _createWithdrawProposal();
        
        // 投票阶段
        _voteOnProposal(proposalId, true); // 投票通过
        
        // 等待投票期结束
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        // 验证提案成功
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));
        
        // 获取提案数据用于排队和执行
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdrawTo(address,uint256)", 
            alice, 
            1 ether
        );
        
        bytes32 descriptionHash = keccak256(bytes("Withdraw 1 ETH to Alice"));
        
        // 排队提案
        governor.queue(targets, values, calldatas, descriptionHash);
        
        // 验证提案已排队
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));
        
        // 记录执行前的余额
        uint256 aliceBalanceBefore = alice.balance;
        uint256 bankBalanceBefore = bank.getBalance();
        
        // 等待时间锁延迟期
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        
        // 执行提案
        governor.execute(targets, values, calldatas, descriptionHash);
        
        // 验证提案已执行
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
        
        // 验证资金转移
        assertEq(alice.balance, aliceBalanceBefore + 1 ether);
        assertEq(bank.getBalance(), bankBalanceBefore - 1 ether);
        
        console.log("Proposal executed successfully!");
        console.log("Alice received 1 ETH from bank");
    }

    function test_FailedProposalDueToQuorum() public {
        // 创建提案
        uint256 proposalId = _createWithdrawProposal();
        
        // 等待投票延迟期结束
        vm.roll(block.number + VOTING_DELAY + 1);
        
        // 只有 Charlie 投票（不足法定人数）
        vm.prank(charlie);
        governor.castVote(proposalId, 1);
        
        // 等待投票期结束
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        // 验证提案因法定人数不足而失败
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
        
        console.log("Proposal defeated due to insufficient quorum");
    }

    function test_FailedProposalDueToMoreAgainstVotes() public {
        // 创建提案
        uint256 proposalId = _createWithdrawProposal();
        
        // 投票阶段 - 反对票更多
        _voteOnProposal(proposalId, false); // 投票否决
        
        // 等待投票期结束
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        // 验证提案失败
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
        
        console.log("Proposal defeated due to more against votes");
    }

    function test_OnlyTimelockCanWithdrawFromBank() public {
        // 尝试直接从银行提取（应该失败）
        vm.prank(alice);
        vm.expectRevert("Only admin can call this function");
        bank.withdraw(1 ether);
        
        // 验证只有时间锁可以提取
        assertEq(bank.admin(), address(timelock));
    }

    function test_EmergencyPauseViaGovernance() public {
        // 创建紧急暂停提案
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("emergencyPause()");
        
        string memory description = "Emergency Pause Proposal";
        
        vm.prank(alice);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );
        
        // 快速通过提案
        _voteOnProposal(proposalId, true);
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        // 排队和执行
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        governor.execute(targets, values, calldatas, descriptionHash);
        
        console.log("Emergency pause executed via governance");
    }

    // 辅助函数
    function _createWithdrawProposal() internal returns (uint256) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdrawTo(address,uint256)", 
            alice, 
            1 ether
        );
        
        string memory description = "Withdraw 1 ETH to Alice";
        
        vm.prank(alice);
        return governor.propose(targets, values, calldatas, description);
    }

    function _voteOnProposal(uint256 proposalId, bool shouldPass) internal {
        // 等待投票延迟期结束
        vm.roll(block.number + VOTING_DELAY + 1);
        
        if (shouldPass) {
            // Alice 和 Bob 投赞成票 (80k tokens)
            vm.prank(alice);
            governor.castVote(proposalId, 1);
            
            vm.prank(bob);
            governor.castVote(proposalId, 1);
            
            // Charlie 投反对票 (20k tokens)
            vm.prank(charlie);
            governor.castVote(proposalId, 0);
        } else {
            // Alice 投反对票 (50k tokens)
            vm.prank(alice);
            governor.castVote(proposalId, 0);
            
            // Bob 和 Charlie 投赞成票 (50k tokens)
            vm.prank(bob);
            governor.castVote(proposalId, 1);
            
            vm.prank(charlie);
            governor.castVote(proposalId, 1);
        }
    }



    receive() external payable {}
} 