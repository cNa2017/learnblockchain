# ERC20交易数据跟踪系统

这个系统可以帮助用户查询和跟踪Sepolia测试网络上的ERC20代币交易数据。

## 功能

- 用户通过MetaMask钱包登录
- 添加ERC20合约地址进行交易跟踪
- 自动轮询获取合约的Transfer事件
- 查看用户相关的交易记录
- 查看特定合约的交易记录

## 技术栈

- 前端: React, TypeScript, React Query, Tailwind CSS, Viem
- 后端: Node.js, Express, MySQL, Socket.io
- 区块链交互: Viem

## 安装和运行

### 前提条件

- Node.js >= 14
- MySQL 5.7+
- 以太坊钱包 (如MetaMask)

### 安装步骤

1. 克隆仓库

```bash
git clone https://github.com/yourusername/erc20-transaction-explorer.git
cd erc20-transaction-explorer
```

2. 安装依赖

```bash
npm install
```

3. 创建数据库

```bash
mysql -u root -p < database.sql
```

4. 配置环境变量

创建 `.env` 文件，参考 `.env.example` 内容

5. 启动开发服务器

```bash
# 前端开发服务器
npm run dev

# 后端服务器 
npm run dev:server
```

## 使用方法

1. 打开浏览器访问 http://localhost:5173
2. 使用MetaMask钱包登录
3. 在左侧添加ERC20合约地址
4. 系统将自动轮询获取交易数据
5. 在右侧可以查看与你的钱包地址相关的交易

## 许可证

MIT
