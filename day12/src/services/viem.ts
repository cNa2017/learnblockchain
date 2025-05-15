import { createPublicClient, createWalletClient, custom, http, type PublicClient, type WalletClient } from 'viem';
import { foundry } from 'viem/chains';

// MetaMask钱包客户端
export let walletClient: WalletClient | null = null;

// 创建Sepolia网络的公共客户端
export const publicClient: PublicClient = createPublicClient({
  chain: foundry,
  transport: http(),
});

// 连接MetaMask钱包
export async function connectWallet(): Promise<string | null> {
  if (!window.ethereum) {
    alert('请安装MetaMask!');
    return null;
  }
  
  try {
    // 请求账户访问权限
    const accounts = await window.ethereum.request({ 
      method: 'eth_requestAccounts' 
    });
    
    if (accounts.length === 0) {
      return null;
    }
    
    // 创建钱包客户端
    walletClient = createWalletClient({
      chain: foundry,
      transport: custom(window.ethereum),
    });
    
    return accounts[0];
  } catch (error) {
    console.error('连接钱包失败:', error);
    return null;
  }
}

// 获取当前连接的地址
export async function getCurrentAddress(): Promise<string | null> {
  if (!window.ethereum) return null;
  
  try {
    const accounts = await window.ethereum.request({ 
      method: 'eth_accounts' 
    });
    
    return accounts.length > 0 ? accounts[0] : null;
  } catch (error) {
    console.error('获取当前地址失败:', error);
    return null;
  }
}

// 签名消息
export async function signMessage(message: string): Promise<string | null> {
  if (!walletClient) return null;
  
  try {
    const address = await getCurrentAddress();
    if (!address) return null;
    
    const signature = await walletClient.signMessage({
      account: address as `0x${string}`,
      message,
    });
    
    return signature;
  } catch (error) {
    console.error('签名失败:', error);
    return null;
  }
}

// ERC20合约的ABI (仅包含Transfer事件和必要的函数)
export const ERC20_ABI = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        name: "from",
        type: "address",
      },
      {
        indexed: true,
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        name: "value",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    inputs: [],
    name: "name",
    outputs: [{ name: "", type: "string" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "symbol",
    outputs: [{ name: "", type: "string" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "decimals",
    outputs: [{ name: "", type: "uint8" }],
    stateMutability: "view",
    type: "function",
  },
] as const;

// 获取ERC20代币的基本信息
export async function getERC20Info(contractAddress: string) {
  try {
    const [name, symbol, decimals] = await Promise.all([
      publicClient.readContract({
        address: contractAddress as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'name',
      }),
      publicClient.readContract({
        address: contractAddress as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'symbol',
      }),
      publicClient.readContract({
        address: contractAddress as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'decimals',
      }),
    ]);
    
    return { name, symbol, decimals };
  } catch (error) {
    console.error('Error fetching ERC20 info:', error);
    throw error;
  }
}

// 为TypeScript添加window.ethereum类型
declare global {
  interface Window {
    ethereum?: any;
  }
} 