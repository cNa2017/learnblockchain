import { NextRequest, NextResponse } from 'next/server';
import { Chain, PublicClient, createPublicClient, http } from 'viem';
import { foundry, sepolia } from 'viem/chains';

// 支持的链配置
const chains: Record<number, Chain> = {
  [sepolia.id]: sepolia,
  [foundry.id]: foundry,
};

// 创建多链公共客户端
const publicClients: Record<number, PublicClient> = {
  [sepolia.id]: createPublicClient({
    chain: sepolia,
    transport: http(),
  }),
  [foundry.id]: createPublicClient({
    chain: foundry,
    transport: http(),
  }),
};

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { address, abi, functionName, args = [], chainId = sepolia.id } = body;

    if (!address || !abi || !functionName) {
      return NextResponse.json(
        { error: '缺少必要参数' },
        { status: 400 }
      );
    }

    // 检查是否支持请求的链ID
    if (!publicClients[chainId]) {
      return NextResponse.json(
        { error: `不支持的链ID: ${chainId}` },
        { status: 400 }
      );
    }

    try {
      // 使用对应链的客户端调用合约读取函数
      const client = publicClients[chainId];
      const result = await client.readContract({
        address: address as `0x${string}`,
        abi,
        functionName,
        args,
      });

      // 处理结果中的BigInt，转换为字符串
      const processedResult = convertBigIntToString(result);
      return NextResponse.json({ result: processedResult });
    } catch (contractError: any) {
      // 处理合约调用错误
      console.log('合约调用错误:', contractError.message);
      
      // 处理特定类型的错误
      if (contractError.message && contractError.message.includes('ERC721NonexistentToken')) {
        // 对于不存在的NFT，返回null而不是错误
        return NextResponse.json({ 
          result: null,
          contractError: {
            type: 'ERC721NonexistentToken',
            tokenId: args[0], // 假设第一个参数是tokenId
            message: `Token ID ${args[0]} 不存在`
          }
        });
      }
      
      // 其他合约错误
      return NextResponse.json({ 
        result: null, 
        contractError: {
          message: contractError.message,
          args: args
        }
      });
    }
  } catch (error: any) {
    console.error('API请求处理错误:', error);
    
    return NextResponse.json(
      { error: error.message || '合约读取失败' },
      { status: 500 }
    );
  }
}

/**
 * 递归处理结果中的BigInt类型，转换为字符串
 */
function convertBigIntToString(value: any): any {
  // 处理BigInt类型
  if (typeof value === 'bigint') {
    return value.toString();
  }
  
  // 处理数组
  if (Array.isArray(value)) {
    return value.map(item => convertBigIntToString(item));
  }
  
  // 处理对象
  if (value !== null && typeof value === 'object') {
    const result: Record<string, any> = {};
    for (const key in value) {
      result[key] = convertBigIntToString(value[key]);
    }
    return result;
  }
  
  // 其他类型直接返回
  return value;
} 