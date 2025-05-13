# Wagmi 开发规范

## 基本要求

- 代码与文档使用英文编写
- 注释使用中文编写
- 所有开发工作使用 TypeScript

## 项目结构

```
app/
├── components/          # 可复用UI组件
│   ├── wallet/          # 钱包连接相关组件
│   └── contracts/       # 合约交互相关组件
├── hooks/               # 自定义React与wagmi钩子
├── config/              # wagmi配置
│   └── providers.tsx    # WagmiProvider设置
├── constants/           # 项目常量
│   └── contracts.ts     # 合约地址与ABI
├── types/               # TypeScript类型定义
└── utils/               # 工具函数
```

## Wagmi 配置

### Providers 设置

- 为wagmi配置创建独立的providers文件
- 遵循以下模式:

```tsx
'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { WagmiProvider, createConfig, http } from 'wagmi';
import { mainnet, sepolia, ... } from 'wagmi/chains';

// 支持链配置
const chains = [mainnet, sepolia, ...];

// wagmi配置设置
const config = createConfig({
  chains,
  transports: {
    [mainnet.id]: http('https://ethereum-rpc-url'),
    [sepolia.id]: http('https://sepolia-rpc-url'),
    // 根据需要添加其他链
  },
});

// 创建TanStack Query客户端
const queryClient = new QueryClient();

// 主Providers组件
export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </WagmiProvider>
  );
}
```

## React Hooks 使用规范

### 基础连接钩子

- 只解构你需要的钩子属性
- 将钩子放在组件定义的顶部
- 将相关钩子分组放置

```tsx
// 钱包连接钩子
const { address, isConnected } = useAccount();
const { connect } = useConnect();
const { disconnect } = useDisconnect();

// 链信息钩子
const chainId = useChainId();
const chains = useChains();
```

### 合约交互钩子

- 将合约ABI和地址存储在单独的常量文件中
- 使用`0x${string}`类型为合约地址进行正确的类型标注
- 始终处理加载、成功和错误状态

```tsx
// 读取合约数据
const { data: counterValue, isLoading, refetch } = useReadContract({
  address: COUNTER_ADDRESS as `0x${string}`,
  abi: COUNTER_ABI,
  functionName: 'getValue',
});

// 写入合约数据
const { 
  writeContract,
  isPending,
  isSuccess,
  isError,
  error
} = useWriteContract();

// 处理合约写入
const handleSubmit = () => {
  writeContract({
    address: CONTRACT_ADDRESS as `0x${string}`,
    abi: CONTRACT_ABI,
    functionName: 'setValue',
    args: [newValue],
  });
};
```

### 交易处理

- 始终实现适当的交易状态处理
- 使用useEffect响应交易状态变化

```tsx
// 跟踪交易状态并在成功后刷新数据
useEffect(() => {
  if (isSuccess) {
    // 成功交易后刷新数据
    refetch();
    // 显示成功通知
  }
  
  if (isError) {
    // 适当处理错误
    console.error('交易失败:', error);
    // 显示错误通知
  }
}, [isSuccess, isError, error, refetch]);
```

## 组件设计

### 钱包连接组件

创建可复用的钱包连接组件:

```tsx
export function ConnectButton() {
  const { isConnected } = useAccount();
  const { connect } = useConnect();
  const { disconnect } = useDisconnect();

  if (isConnected) {
    return (
      <button 
        onClick={() => disconnect()}
        className="bg-red-500 text-white py-2 px-4 rounded"
      >
        Disconnect
      </button>
    );
  }

  return (
    <button
      onClick={() => connect({ connector: injected() })}
      className="bg-blue-500 text-white py-2 px-4 rounded"
    >
      Connect Wallet
    </button>
  );
}
```

### 账户信息组件

```tsx
export function AccountInfo() {
  const { address } = useAccount();
  const { data: balance } = useBalance({ address });
  
  if (!address) return null;
  
  return (
    <div className="p-4 border rounded">
      <p className="text-sm text-gray-500">Connected Account</p>
      <p className="font-mono text-sm">{address}</p>
      <p className="mt-2 text-sm text-gray-500">Balance</p>
      <p>{balance?.formatted || '0'} {balance?.symbol}</p>
    </div>
  );
}
```

## 自定义钩子

为常见模式创建自定义钩子:

```tsx
// 带自动刷新的合约读取自定义钩子
export function useContractData(
  address: `0x${string}`,
  abi: any,
  functionName: string,
  args?: any[],
  refreshInterval = 5000,
) {
  const { data, isLoading, isError, error, refetch } = useReadContract({
    address,
    abi,
    functionName,
    args,
  });
  
  // 定时自动刷新数据
  useEffect(() => {
    const interval = setInterval(() => {
      refetch();
    }, refreshInterval);
    
    return () => clearInterval(interval);
  }, [refetch, refreshInterval]);
  
  return { data, isLoading, isError, error, refetch };
}
```

## 错误处理

- 为所有合约交互实现适当的错误处理
- 创建可复用的错误组件和工具

```tsx
// 错误显示组件
export function TransactionError({ error }: { error: Error | null }) {
  if (!error) return null;
  
  return (
    <div className="p-4 bg-red-100 border border-red-400 text-red-700 rounded">
      <p className="font-bold">Transaction Error:</p>
      <p>{error.message}</p>
    </div>
  );
}
```

## 代码注释标准

- 对函数和组件使用JSDoc风格注释
- 为复杂逻辑包含中文注释
- 遵循以下模式:

```tsx
/**
 * Component for interacting with a smart contract
 * @param {`0x${string}`} contractAddress - The contract address
 * @param {any} contractAbi - The contract ABI
 */
export function ContractInteraction({
  contractAddress,
  contractAbi,
}: {
  contractAddress: `0x${string}`;
  contractAbi: any;
}) {
  // ... 组件实现
  
  // 处理用户提交表单时的操作
  const handleSubmit = () => {
    // 检查输入值是否有效
    if (!isValidInput) return;
    
    // 调用合约方法
    writeContract({
      address: contractAddress,
      abi: contractAbi,
      functionName: 'processData',
      args: [inputValue],
    });
  };
  
  return (
    // ... 组件JSX
  );
}
```

## 测试

- 使用Vitest或Jest为所有合约交互编写测试
- 在测试中使用wagmi测试工具模拟wagmi钩子

## 性能考虑

- 对昂贵的计算使用记忆化
- 在useEffect和useMemo中实现正确的依赖数组
- 考虑使用带有适当缓存策略的SWR模式

## 代码审查清单

提交代码审查前，确保:

1. 所有合约交互都有适当的错误处理
2. 函数和组件都有正确的类型标注
3. 注释使用中文并解释复杂逻辑
4. 代码遵循项目结构指南
5. 组件中没有硬编码的合约地址或ABI
6. 实现了适当的交易状态处理

## wagmi v2特有指南

### 连接钱子的最佳实践

```tsx
// 使用injected连接器
import { injected } from 'wagmi/connectors'

export function Connect() {
  const { connect } = useConnect()
  
  return (
    <button onClick={() => connect({ connector: injected() })}>
      Connect Wallet
    </button>
  )
}
```

### 多链支持

- 在配置中添加所有支持的链
- 使用switchChain钩子处理链切换

```tsx
const { chains, switchChain } = useSwitchChain()

return (
  <div>
    <div>当前链: {chain?.name}</div>
    <div>
      {chains.map((chain) => (
        <button
          key={chain.id}
          onClick={() => switchChain({ chainId: chain.id })}
        >
          {chain.name}
        </button>
      ))}
    </div>
  </div>
)
```

### 多钱包支持

```tsx
import { injected, metaMask, walletConnect } from 'wagmi/connectors'

export function ConnectWallet() {
  const { connect } = useConnect()
  
  return (
    <div>
      <button onClick={() => connect({ connector: metaMask() })}>
        MetaMask
      </button>
      <button onClick={() => connect({ connector: walletConnect() })}>
        WalletConnect
      </button>
      <button onClick={() => connect({ connector: injected() })}>
        Injected
      </button>
    </div>
  )
}
```

## 实用工具函数

创建以下实用工具:

1. 格式化地址工具
```tsx
// 将完整地址缩短为 0x1234...5678 格式
export function formatAddress(address: string, prefixLength = 6, suffixLength = 4): string {
  if (!address) return '';
  return `${address.substring(0, prefixLength)}...${address.substring(address.length - suffixLength)}`;
}
```

2. 错误解析工具
```tsx
// 解析Ethereum错误为用户友好的消息
export function parseEthError(error: Error): string {
  // 处理常见的以太坊错误
  if (error.message.includes('user rejected transaction')) {
    return '用户拒绝了交易';
  }
  
  if (error.message.includes('insufficient funds')) {
    return '余额不足，无法完成交易';
  }
  
  // 返回通用错误消息
  return error.message;
}
```

3. 区块链浏览器链接生成器
```tsx
// 生成到区块链浏览器的链接
export function getExplorerLink(chainId: number, hash: string, type: 'transaction' | 'address' | 'token' = 'transaction'): string {
  const explorers = {
    1: 'https://etherscan.io',
    5: 'https://goerli.etherscan.io',
    // 添加更多链的浏览器URL
  };
  
  const baseUrl = explorers[chainId] || explorers[1];
  
  switch (type) {
    case 'transaction':
      return `${baseUrl}/tx/${hash}`;
    case 'address':
      return `${baseUrl}/address/${hash}`;
    case 'token':
      return `${baseUrl}/token/${hash}`;
    default:
      return `${baseUrl}`;
  }
}
```

## 安全最佳实践

1. 永远不要在前端硬编码私钥
2. 使用环境变量存储敏感配置
3. 实现适当的用户确认机制，尤其是对敏感操作
4. 使用类型安全的合约ABI定义
5. 对用户输入数据进行验证和清理，防止注入攻击
6. 实现交易金额限制和确认，防止意外交易 