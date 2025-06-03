# OpenspaceNFT Flashbot 捆绑交易脚本

这个脚本使用 Flashbot API 的 `eth_sendBundle` 功能来捆绑 OpenspaceNFT 合约的预售交易，确保 `enablePresale()` 和 `presale()` 交易能够在同一个区块中执行。

## 📋 功能特性

- ⚡ 使用 Flashbot 捆绑交易技术
- 🔐 自动检测合约状态和权限
- 📊 实时监控交易状态和捆绑统计
- 🎯 支持 Sepolia 测试网
- 🛡️ 完整的错误处理和状态检查

## 🚀 快速开始

### 1. 安装依赖

```bash
npm install
```

### 2. 配置环境变量

创建 `.env` 文件并添加您的私钥：

```bash
# 必需：您的钱包私钥（不要包含0x前缀）
PRIVATE_KEY=your_private_key_here

# 可选：自定义 Sepolia RPC URL
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID

# 可选：自定义 Flashbots URL（默认使用 Sepolia 测试网）
FLASHBOTS_URL=https://relay-sepolia.flashbots.net
```

⚠️ **重要安全提醒**: 
- 永远不要将包含真实私钥的 `.env` 文件提交到版本控制系统
- 建议使用测试网络和测试账户
- 确保账户有足够的 Sepolia ETH 支付 gas 费用

### 3. 运行脚本

```bash
npm start
```

或者直接使用 Node.js：

```bash
node flashbot-bundle.js
```

## 📊 脚本执行流程

1. **环境检查**: 验证私钥和网络连接
2. **合约状态检查**: 检查预售状态、Token ID 和所有者权限
3. **交易准备**: 
   - 如果预售未激活，准备 `enablePresale()` 交易
   - 准备 `presale(amount)` 交易（默认购买 2 个 NFT）
4. **Flashbot 捆绑**: 将交易打包并发送到 Flashbot 中继
5. **状态监控**: 
   - 等待目标区块确认
   - 使用 `flashbots_getBundleStats` 查询捆绑状态
   - 检查个别交易的确认状态
6. **结果报告**: 显示交易哈希、状态统计和最终合约状态

## 🔧 配置选项

### 合约配置

- **合约地址**: `0xb56EE9d932a33E3B6490424C213051181AAfd772` (Sepolia)
- **网络**: Sepolia 测试网 (Chain ID: 11155111)
- **NFT 价格**: 0.01 ETH 每个
- **默认购买数量**: 2 个 NFT

### Gas 配置

脚本会自动获取当前网络的 gas 价格，并使用 EIP-1559 交易类型：
- `enablePresale()`: 100,000 gas limit
- `presale(amount)`: 200,000 gas limit

## 📤 输出示例

```
🚀 开始 Flashbot 捆绑交易...
📍 钱包地址: 0x1234...5678
🌐 网络: sepolia 链ID: 11155111
💰 账户余额: 0.5 ETH
📊 合约状态:
  - 预售是否激活: false
  - 下一个Token ID: 1
  - 合约拥有者: 0x1234...5678
  - 当前钱包是否为拥有者: true
⚡ Flashbots Provider 创建成功
🎯 当前区块: 12345
🎯 目标区块: 12347
✅ 已准备 enablePresale 交易
✅ 已准备 presale 交易 (购买 2 个NFT，价值 0.02 ETH)
📦 准备发送捆绑交易，包含 2 个交易
📤 捆绑交易已发送
🆔 Bundle Hash: 0xabcd...ef01
⏳ 等待交易确认...
📊 Bundle Stats: {...}
📋 交易 1 哈希: 0x1111...2222
📋 交易 2 哈希: 0x3333...4444
✅ 交易 1 已确认: { blockNumber: 12347, gasUsed: "50000", status: "SUCCESS" }
✅ 交易 2 已确认: { blockNumber: 12347, gasUsed: "120000", status: "SUCCESS" }
📊 最终状态:
  - 预售是否激活: true
  - 下一个Token ID: 3
🎉 脚本执行完成!
```

## 🛠️ 故障排除

### 常见问题

1. **"请设置 PRIVATE_KEY 环境变量"**
   - 确保 `.env` 文件存在且包含有效的私钥

2. **"当前钱包不是合约拥有者"**
   - 只有合约拥有者才能调用 `enablePresale()` 函数
   - 确认使用正确的私钥

3. **"账户余额较低"**
   - 确保账户有足够的 Sepolia ETH 支付 gas 费用
   - 可以从 Sepolia 水龙头获取测试 ETH

4. **"获取 bundle stats 失败"**
   - 这通常是正常的，可能是网络延迟或 Flashbots 服务暂时不可用
   - 交易状态检查仍会正常进行

### 网络问题

如果遇到 RPC 连接问题，可以：
1. 使用自己的 Infura/Alchemy 项目 ID
2. 在 `.env` 文件中设置 `SEPOLIA_RPC_URL`

## 📚 技术细节

### 使用的技术栈

- **ethers.js v6**: 以太坊交互库
- **@flashbots/ethers-provider-bundle**: Flashbots 捆绑交易库
- **dotenv**: 环境变量管理

### Flashbot 工作原理

1. **交易捆绑**: 将多个交易打包成一个原子操作
2. **MEV 保护**: 防止 MEV (最大可提取价值) 攻击
3. **优先级竞拍**: 通过竞拍机制确保交易被包含

### 安全考虑

- 使用 EIP-1559 交易类型确保 gas 费用合理
- 实现完整的错误处理避免资金损失
- 支持优雅退出和信号处理

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

⚠️ **免责声明**: 此脚本仅用于教育和测试目的。请在使用前充分理解代码逻辑，并在测试网络上验证功能。使用者需自行承担所有风险。 