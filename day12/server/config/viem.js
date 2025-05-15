import dotenv from 'dotenv';
import { createPublicClient, http, parseAbi } from 'viem';
import { foundry } from 'viem/chains';

// 加载环境变量
dotenv.config();

// 创建Sepolia网络的公共客户端
export const publicClient = createPublicClient({
  chain: foundry,
  transport: http(process.env.RPC_URL || 'https://rpc.sepolia.org'),
});

// ERC20 ABI
export const ERC20_ABI = parseAbi([
  // 基本ERC20函数
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function totalSupply() view returns (uint256)',
  'function balanceOf(address owner) view returns (uint256)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function transfer(address to, uint256 value) returns (bool)',
  'function approve(address spender, uint256 value) returns (bool)',
  'function transferFrom(address from, address to, uint256 value) returns (bool)',
  
  // ERC20事件
  'event Transfer(address indexed from, address indexed to, uint256 value)',
  'event Approval(address indexed owner, address indexed spender, uint256 value)',
]);

// 每次轮询的区块数量
export const BLOCKS_PER_POLLING = 2000;

// 轮询间隔（毫秒）
export const POLLING_INTERVAL = 60 * 1000; // 60秒

// 最大并发轮询任务数
export const MAX_CONCURRENT_TASKS = 3;

// 最大重试次数
export const MAX_RETRIES = 3;

// 获取Transfer事件日志
export async function getTransferLogs(contractAddress, fromBlock, toBlock) {
  try {
    const logs = await publicClient.getLogs({
      address: contractAddress,
      event: {
        type: 'event',
        name: 'Transfer',
        inputs: [
          { type: 'address', name: 'from', indexed: true },
          { type: 'address', name: 'to', indexed: true },
          { type: 'uint256', name: 'value' }
        ]
      },
      fromBlock: BigInt(fromBlock),
      toBlock: BigInt(toBlock)
    });
    
    // 确保日志数据格式正确
    const formattedLogs = logs.map(log => {
      // 确保 args 存在且包含正确的字段
      if (!log.args || typeof log.args.from === 'undefined' || typeof log.args.to === 'undefined') {
        console.error('Event log missing expected args:', log);
        throw new Error('事件日志缺少预期的参数');
      }
      return log;
    });
    
    return formattedLogs;
  } catch (error) {
    console.error(`获取转账日志出错 [${contractAddress}] [${fromBlock}-${toBlock}]:`, error);
    throw error;
  }
} 