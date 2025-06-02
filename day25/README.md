# DAO 治理系统

这是一个基于 Compound 模式的完整 DAO 治理系统，用于管理 SimpleBank 合约的 withdraw 功能。

## 系统架构

### 核心组件

1. **GovernanceToken (治理代币)**
   - 基于 OpenZeppelin ERC20Votes
   - 支持投票权委托 (delegation)
   - 支持基于区块快照的投票权查询
   - 初始供应量：1,000,000 GOV

2. **GovernanceTimelock (时间锁)**
   - 基于 OpenZeppelin TimelockController
   - 对提案执行引入延迟，防止闪电攻击
   - 默认延迟：1 天

3. **BankGovernor (治理合约)**
   - 基于 OpenZeppelin Governor 及其扩展
   - 管理提案生命周期：创建 → 投票 → 排队 → 执行
   - 集成投票、计数、设置、时间锁等功能

4. **SimpleBank (银行合约)**
   - 支持 ETH 存款和提款
   - 管理员权限由时间锁合约控制
   - 只有通过治理提案才能执行 withdraw 操作

### 治理参数

- **投票延迟期**: 1 个区块
- **投票持续期**: 50 个区块
- **提案门槛**: 1,000 GOV 代币
- **法定人数**: 4% 的总供应量
- **时间锁延迟**: 1 天

## 功能特性

### 1. 代币功能
- ✅ ERC20 标准功能
- ✅ 投票权委托
- ✅ 基于区块的投票权快照
- ✅ EIP-712 签名支持 (Permit)

### 2. 治理功能
- ✅ 提案创建
- ✅ 投票机制（赞成/反对/弃权）
- ✅ 法定人数检查
- ✅ 时间锁保护
- ✅ 提案执行

### 3. 银行管理
- ✅ 通过治理控制 withdraw 功能
- ✅ 支持向指定地址提取资金
- ✅ 紧急暂停功能（通过治理）

## 部署指南

### 1. 编译合约
```bash
forge build
```

### 2. 运行测试
```bash
forge test --match-path test/Dao/GovernanceTest.t.sol -vv
```

### 3. 部署合约
```bash
# 本地测试网络
forge script script/Dao/DeployGovernance.s.sol

# 实际网络部署（需要设置 PRIVATE_KEY 环境变量）
forge script script/Dao/DeployGovernance.s.sol --rpc-url <RPC_URL> --broadcast
```

## 使用流程

### 1. 准备阶段
1. 获取治理代币
2. 委托投票权给自己或他人
3. 向银行存入 ETH

### 2. 创建提案
```solidity
// 示例：提案从银行提取 1 ETH 到指定地址
address[] memory targets = new address[](1);
uint256[] memory values = new uint256[](1);
bytes[] memory calldatas = new bytes[](1);

targets[0] = address(bank);
values[0] = 0;
calldatas[0] = abi.encodeWithSignature(
    "withdrawTo(address,uint256)", 
    recipient, 
    1 ether
);

string memory description = "Withdraw 1 ETH for community reward";

uint256 proposalId = governor.propose(
    targets,
    values,
    calldatas,
    description
);
```

### 3. 投票阶段
```solidity
// 等待投票延迟期结束
// 投票：0=反对, 1=赞成, 2=弃权
governor.castVote(proposalId, 1);
```

### 4. 执行提案
```solidity
// 投票期结束后，如果提案通过
governor.queue(targets, values, calldatas, descriptionHash);

// 等待时间锁延迟期
// 执行提案
governor.execute(targets, values, calldatas, descriptionHash);
```

## 测试用例

系统包含完整的测试套件，覆盖以下场景：

1. **基础功能测试**
   - ✅ 代币分发和委托
   - ✅ 治理参数验证
   - ✅ 权限控制

2. **提案流程测试**
   - ✅ 提案创建
   - ✅ 投票机制
   - ✅ 成功执行
   - ✅ 失败场景（法定人数不足、反对票过多）

3. **安全性测试**
   - ✅ 只有时间锁可以操作银行
   - ✅ 紧急暂停功能

## 安全考虑

1. **时间锁保护**: 所有提案执行都有 1 天延迟期
2. **法定人数要求**: 需要 4% 的代币参与投票
3. **提案门槛**: 需要 1000 个代币才能创建提案
4. **权限分离**: 银行管理权完全由治理控制

## 合约地址

部署后的合约地址将显示在部署脚本输出中：

```
=== Deployment Summary ===
GovernanceToken: 0x...
GovernanceTimelock: 0x...
BankGovernor: 0x...
SimpleBank: 0x...
```

## 技术栈

- **Solidity**: ^0.8.20
- **OpenZeppelin**: v5.3.0
- **Foundry**: 测试和部署框架
- **Forge**: 编译和测试工具

## 许可证

MIT License 