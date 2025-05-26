# Vesting 合约系统

这是一个基于 OpenZeppelin VestingWallet 的代币释放合约系统，实现了 12 个月 cliff + 24 个月线性释放的机制。

## 合约概述

### Vesting.sol（单文件包含两个合约）

#### VestingToken 合约
- 基于 OpenZeppelin ERC20 的标准代币合约
- 初始发行量：1,000,000 代币（100万）
- 符号：VT
- 名称：VestingToken

#### Vesting 合约
- 基于 OpenZeppelin VestingWallet 的释放合约
- **Cliff 期**：12 个月（365 天）
- **线性释放期**：24 个月（730 天）
- **总周期**：36 个月（1095 天）

## 功能特性

### 时间机制
1. **Cliff 期（前 12 个月）**：代币完全锁定，无法释放
2. **线性释放期（第 13-36 个月）**：每月释放 1/24 的代币
3. **释放完成**：36 个月后所有代币完全释放

**设计改进**：Vesting 合约使用 `block.timestamp + CLIFF_DURATION` 作为 VestingWallet 的开始时间，这样使得：
- VestingWallet 自动处理 Cliff 期逻辑（在开始时间之前不释放任何代币）
- 代码逻辑更清晰，可读性更强
- 减少了手动实现 Cliff 逻辑的复杂性

### 主要函数

#### `releaseVesting()`
- 释放当前可用的代币给受益人
- 任何人都可以调用，但代币只会转给受益人
- 返回释放的代币数量

#### `releasable(address token)`
- 查询指定代币的可释放数量
- 视图函数，不消耗 gas

#### `beneficiary()`
- 获取受益人地址
- 受益人是合约的 owner

#### `emergencyWithdraw(address token, uint256 amount)`
- 紧急提取功能（仅限受益人）
- 用于特殊情况下的资产救援

### 查询函数
- `getDeployTime()`：获取合约部署时间（实际的开始时间）
- `getStartTime()`：获取线性释放开始时间
- `getCliffEnd()`：获取 Cliff 结束时间（等于线性释放开始时间）
- `getVestingEnd()`：获取 Vesting 结束时间
- `getReleasedAmount(address token)`：获取已释放的代币数量
- `getTotalBalance(address token)`：获取合约持有的代币总量

## 部署和使用

### 1. 部署合约

```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key
export BENEFICIARY=beneficiary_address  # 可选，默认使用部署者地址

# 部署到本地网络
forge script script/DeployVesting.s.sol --rpc-url http://localhost:8545 --broadcast

# 部署到测试网
forge script script/DeployVesting.s.sol --rpc-url $RPC_URL --broadcast --verify
```

### 2. 使用示例

```solidity
// 导入合约（单文件包含两个合约）
import {VestingToken, Vesting} from "./src/Vesting.sol";

// 获取可释放数量
uint256 releasable = vesting.releasable(tokenAddress);

// 释放代币
if (releasable > 0) {
    uint256 released = vesting.releaseVesting();
    console.log("Released:", released);
}

// 查询状态
address beneficiary = vesting.beneficiary();
uint256 deployTime = vesting.getDeployTime();    // 合约部署时间
uint256 startTime = vesting.getStartTime();      // 线性释放开始时间
uint256 cliffEnd = vesting.getCliffEnd();        // Cliff 结束时间
uint256 vestingEnd = vesting.getVestingEnd();    // Vesting 结束时间
```

## 测试

运行完整的测试套件：

```bash
forge test --match-contract VestingTest -v
```

### 测试覆盖

测试文件包含以下测试场景：

1. **基本功能测试**
   - 合约初始化
   - 初始状态验证
   - 无效参数处理

2. **Cliff 期测试**
   - Cliff 期间无法释放代币
   - Cliff 结束时间点验证

3. **线性释放测试**
   - 不同时间点的释放量计算
   - 每月释放 1/24 的逻辑验证

4. **释放功能测试**
   - 成功释放代币
   - 多次释放累计
   - 非受益人触发释放

5. **完整生命周期测试**
   - 36 个月完整周期模拟
   - 最终状态验证

6. **边界条件测试**
   - 时间操作测试
   - Gas 消耗测试
   - 紧急功能测试

## 时间模拟

测试使用 Foundry 的 `vm.warp()` 功能进行时间模拟：

```solidity
// 跳过 cliff 期
vm.warp(startTime + CLIFF_DURATION);

// 模拟第 6 个月
vm.warp(startTime + CLIFF_DURATION + 180 days);

// 模拟完整周期结束
vm.warp(startTime + TOTAL_DURATION);
```

## 安全特性

1. **基于 OpenZeppelin**：使用经过审计的标准库
2. **访问控制**：只有受益人可以执行紧急提取
3. **重入保护**：继承 VestingWallet 的安全机制
4. **精确计算**：使用整数运算避免精度损失

## Gas 优化

- 使用 `immutable` 变量存储代币地址
- 继承 OpenZeppelin 的优化实现
- 最小化存储操作

## 注意事项

1. **时间精度**：合约使用秒级时间戳，24 个月按 730 天计算
2. **精度损失**：整数除法可能导致微小的精度损失
3. **紧急功能**：`emergencyWithdraw` 仅用于特殊情况，正常情况下应使用 `releaseVesting`

## 许可证

MIT License 