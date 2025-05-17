# 多签钱包 (MultiSigWallet)

一个基于智能合约的多签钱包，支持多个持有人共同管理资金。该合约允许多个地址作为签名者，需要达到特定的签名数量才能执行交易。

## 功能特点

- 创建多签钱包时，指定所有持有人地址和签名门槛（例如：2/3签名）
- 多签持有人可提交交易提案
- 持有人可对提案进行确认或撤销确认
- 签名达到门槛后，任何人都可执行交易
- 提供完整的交易历史记录和状态查询功能

## 合约结构

合约包含以下主要组件：

- **持有人管理**：存储所有持有人地址及其权限
- **交易管理**：记录所有提交的交易及其状态
- **确认管理**：追踪每个交易的确认状态

## 使用方法

### 部署合约

1. 准备持有人地址列表和所需的确认门槛
2. 使用部署脚本进行部署：

```bash
# 指定持有人地址和确认门槛
export OWNER1=0x...
export OWNER2=0x...
export OWNER3=0x...
export CONFIRMATIONS=2

# 部署合约
forge script script/DeployMultiSigWallet.s.sol:DeployMultiSigWallet --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

### 合约交互

#### 提交交易

持有人可以提交交易提案：

```solidity
function submitTransaction(
    address _to,
    uint _value,
    bytes memory _data
) public onlyOwner returns (uint)
```

参数说明：
- `_to`：目标地址
- `_value`：发送的ETH数量
- `_data`：调用数据

#### 确认交易

持有人可以确认交易：

```solidity
function confirmTransaction(uint _txIndex) public
```

参数说明：
- `_txIndex`：交易索引

#### 执行交易

当确认数量达到门槛后，任何人都可以执行交易：

```solidity
function executeTransaction(uint _txIndex) public
```

参数说明：
- `_txIndex`：交易索引

#### 撤销确认

持有人可以撤销已确认的交易（如果交易尚未执行）：

```solidity
function revokeConfirmation(uint _txIndex) public
```

参数说明：
- `_txIndex`：交易索引

## 示例场景

### 创建多签钱包

```solidity
// 创建持有人地址数组
address[] memory owners = new address[](3);
owners[0] = 0x123...;
owners[1] = 0x456...;
owners[2] = 0x789...;

// 部署合约，需要2/3签名
MultiSigWallet wallet = new MultiSigWallet(owners, 2);
```

### 向合约发送资金

```solidity
// 直接发送ETH到合约地址
payable(address(wallet)).transfer(1 ether);
```

### 提交和执行交易

```solidity
// 持有人1提交交易
uint txIndex = wallet.submitTransaction(recipient, 0.5 ether, "");

// 持有人1确认交易
wallet.confirmTransaction(txIndex);

// 持有人2确认交易
wallet.confirmTransaction(txIndex);

// 任何人可以执行已确认的交易
wallet.executeTransaction(txIndex);
```

## 安全考虑

- 使用多签钱包可以减少单一密钥泄露的风险
- 确保持有人地址安全，不要使用轻易泄露的地址
- 交易执行前务必仔细检查交易内容，确认无误后再签名
- 建议在主网部署前在测试网进行充分测试 