# Wagmi Development Specification

## General Requirements

- Code and documentation must be written in English
- Comments must be written in Chinese
- Use TypeScript for all development work

## Project Structure

```
app/
├── components/          # Reusable UI components
│   ├── wallet/          # Wallet connection components
│   └── contracts/       # Contract interaction components
├── hooks/               # Custom React & wagmi hooks
├── config/              # wagmi configuration
│   └── providers.tsx    # WagmiProvider setup
├── constants/           # Project constants
│   └── contracts.ts     # Contract addresses & ABIs
├── types/               # TypeScript type definitions
└── utils/               # Utility functions
```

## Wagmi Configuration

### Providers Setup

- Create a standalone providers file for wagmi configuration
- Follow this pattern:

```tsx
'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { WagmiProvider, createConfig, http } from 'wagmi';
import { mainnet, sepolia, ... } from 'wagmi/chains';

// Supported chains configuration
const chains = [mainnet, sepolia, ...];

// wagmi config setup
const config = createConfig({
  chains,
  transports: {
    [mainnet.id]: http('https://ethereum-rpc-url'),
    [sepolia.id]: http('https://sepolia-rpc-url'),
    // Add other chains as needed
  },
});

// Create a client for TanStack Query
const queryClient = new QueryClient();

// Main providers component
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

## React Hooks Usage

### Basic Connection Hooks

- Always destructure only the properties you need from hooks
- Place hooks at the top of component definitions
- Group related hooks together

```tsx
// Wallet connection hooks
const { address, isConnected } = useAccount();
const { connect } = useConnect();
const { disconnect } = useDisconnect();

// Chain information hooks
const chainId = useChainId();
const chains = useChains();
```

### Contract Interaction Hooks

- Store contract ABIs and addresses in separate constant files
- Use proper typing for contract addresses with `0x${string}` type
- Always handle loading, success, and error states

```tsx
// Read contract data
const { data: counterValue, isLoading, refetch } = useReadContract({
  address: COUNTER_ADDRESS as `0x${string}`,
  abi: COUNTER_ABI,
  functionName: 'getValue',
});

// Write contract data
const { 
  writeContract,
  isPending,
  isSuccess,
  isError,
  error
} = useWriteContract();

// Handle contract writes
const handleSubmit = () => {
  writeContract({
    address: CONTRACT_ADDRESS as `0x${string}`,
    abi: CONTRACT_ABI,
    functionName: 'setValue',
    args: [newValue],
  });
};
```

### Transaction Handling

- Always implement proper transaction state handling
- Use useEffect to respond to transaction state changes

```tsx
// Track transaction status and refresh data after success
useEffect(() => {
  if (isSuccess) {
    // Refresh data after successful transaction
    refetch();
    // Show success notification
  }
  
  if (isError) {
    // Handle error appropriately
    console.error('Transaction failed:', error);
    // Show error notification
  }
}, [isSuccess, isError, error, refetch]);
```

## Components Design

### Wallet Connection Component

Create reusable wallet connection components:

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

### Account Information Component

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

## Custom Hooks

Create custom hooks for common patterns:

```tsx
// Custom hook for contract reads with auto-refresh
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
  
  // Auto-refresh data at interval
  useEffect(() => {
    const interval = setInterval(() => {
      refetch();
    }, refreshInterval);
    
    return () => clearInterval(interval);
  }, [refetch, refreshInterval]);
  
  return { data, isLoading, isError, error, refetch };
}
```

## Error Handling

- Always implement proper error handling for all contract interactions
- Create reusable error components and utilities

```tsx
// Error display component
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

## Code Commenting Standards

- Use JSDoc style comments for functions and components
- Include Chinese comments for complex logic
- Follow this pattern:

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
  // ... component implementation
  
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
    // ... component JSX
  );
}
```

## Testing

- Write tests for all contract interactions using Vitest or Jest
- Mock wagmi hooks in tests using the wagmi test utils

## Performance Considerations

- Use memoization for expensive computations
- Implement proper dependency arrays in useEffect and useMemo
- Consider using SWR patterns with appropriate caching strategies

## Code Review Checklist

Before submitting code for review, ensure:

1. All contract interactions have proper error handling
2. Functions and components are properly typed
3. Comments are in Chinese and explain complex logic
4. Code follows the project structure guidelines
5. No hardcoded contract addresses or ABIs in components
6. Proper transaction state handling is implemented 