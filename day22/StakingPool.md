# StakingPool 项目说明

## 项目概述

StakingPool 是一个基于 Solidity 0.8.20 的智能合约系统，允许用户质押 ETH 来获得 KK Token 奖励。该系统实现了公平的奖励分配机制，根据用户的质押时长和质押数量来分配收益。

## 合约架构

### 1. KKToken.sol
- **功能**: ERC20 奖励代币
- **特性**: 
  - 代币名称: "KK Token"
  - 代币符号: "KK"
  - 只有合约所有者可以铸造代币
  - 继承 OpenZeppelin 的 ERC20 和 Ownable

### 2. StakingPool.sol
- **功能**: 核心质押池合约
- **主要功能**:
  - `stake()`: 质押 ETH
  - `unstake(uint256 amount)`: 取消质押指定数量的 ETH
  - `claim()`: 领取 KK Token 奖励
  - `balanceOf(address account)`: 查询用户质押余额
  - `earned(address account)`: 查询用户待领取奖励

## 核心机制

### 奖励分配规则
- **每个区块产出**: 10 KK Token
- **分配方式**: 根据用户质押数量占总质押量的比例进行分配
- **计算公式**: 用户奖励 = 区块奖励 × (用户质押量 / 总质押量) × 区块数

### 示例场景
假设三个用户在不同时间质押不同数量的 ETH：

1. **Alice** 在区块 1 质押 1 ETH，独占 5 个区块奖励 = 50 KK
2. **Bob** 在区块 6 质押 2 ETH，与 Alice 共享 3 个区块奖励
   - Alice 获得: 3 × 10 × (1/3) = 10 KK
   - Bob 获得: 3 × 10 × (2/3) = 20 KK
3. **Charlie** 在区块 9 质押 3 ETH，三人共享 6 个区块奖励
   - Alice 获得: 6 × 10 × (1/6) = 10 KK
   - Bob 获得: 6 × 10 × (2/6) = 20 KK  
   - Charlie 获得: 6 × 10 × (3/6) = 30 KK

**最终收益**:
- Alice: 50 + 10 + 10 = 70 KK
- Bob: 20 + 20 = 40 KK
- Charlie: 30 KK

## 安全特性

1. **重入保护**: 使用 OpenZeppelin 的 ReentrancyGuard
2. **权限控制**: KK Token 的铸造权限由 StakingPool 控制
3. **输入验证**: 检查质押和取消质押的数量
4. **状态更新**: 使用 `updateReward` 修饰符确保状态一致性

## 文件结构

```
src/StakingPool/
├── KKToken.sol          # KK Token 合约
└── StakingPool.sol      # 质押池合约

test/StakingPool/
├── StakingPoolTest.t.sol          # 基础功能测试
├── StakingPoolSimpleTest.t.sol    # 简化场景测试
└── StakingPoolDetailedTest.t.sol  # 详细收益计算测试

script/StakingPool/
└── Deploy.s.sol         # 部署脚本
```

## 部署步骤

1. 设置环境变量 `PRIVATE_KEY`
2. 运行部署脚本:
   ```bash
   forge script script/StakingPool/Deploy.s.sol --broadcast
   ```

## 测试结果

所有测试均通过，包括：
- ✅ 基础功能测试 (10个测试)
- ✅ 简化场景测试 (2个测试)  
- ✅ 详细收益计算测试 (3个测试)

总计 15 个测试全部通过，验证了合约的正确性和安全性。

## 主要特点

1. **公平分配**: 严格按照质押比例和时长分配奖励
2. **实时计算**: 支持动态查询待领取奖励
3. **灵活操作**: 支持部分取消质押和随时领取奖励
4. **气体优化**: 使用高效的数学计算减少 gas 消耗
5. **安全可靠**: 遵循 Solidity 最佳实践和安全标准 