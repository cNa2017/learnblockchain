'use client';

import { useEffect, useState } from 'react';
import { useAccount, useChainId, useWriteContract } from 'wagmi';
import ERC721ABI from '../../contracts/ERC721.json';

interface NFTProps {
  nftAddress: `0x${string}`;
}

interface NFTItem {
  id: number;
  owner: `0x${string}`;
  tokenURI: string;
}

export function NFT({ nftAddress }: NFTProps) {
  const { address } = useAccount();
  const chainId = useChainId();
  const [mounted, setMounted] = useState(false);
  const [nfts, setNfts] = useState<NFTItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [mintURI, setMintURI] = useState('');
  const [totalSupply, setTotalSupply] = useState<number>(0);

  // Mint NFT
  const { 
    writeContract,
    isPending: isMintPending,
    isSuccess: isMintSuccess,
    isError: isMintError,
    error: mintError
  } = useWriteContract();

  // 仅在客户端挂载后执行
  useEffect(() => {
    setMounted(true);
  }, []);

  // Mint成功后刷新NFT列表
  useEffect(() => {
    if (isMintSuccess) {
      fetchTotalSupply();
      fetchNFTs();
    }
    
    if (isMintError) {
      console.error('Mint NFT失败:', mintError);
    }
  }, [isMintSuccess, isMintError, mintError]);

  // 初始化加载
  useEffect(() => {
    if (mounted && address) {
      fetchTotalSupply();
    }
  }, [mounted, address, chainId]);

  // 当totalSupply更新时加载NFT
  useEffect(() => {
    if (mounted && address && totalSupply > 0) {
      fetchNFTs();
    }
  }, [mounted, address, totalSupply]);

  // 获取NFT总供应量
  const fetchTotalSupply = async () => {
    try {
      // 尝试通过tokenCounter获取供应量
      const counter = await readContract({
        address: nftAddress,
        abi: ERC721ABI,
        functionName: 'tokenCounter',
        chainId,
      }).catch(() => null);
      
      if (counter !== null) {
        setTotalSupply(Number(counter));
        return;
      }
      
      // 如果没有tokenCounter，尝试获取totalSupply
      const supply = await readContract({
        address: nftAddress,
        abi: ERC721ABI,
        functionName: 'totalSupply',
        chainId,
      }).catch(() => null);
      
      if (supply !== null) {
        setTotalSupply(Number(supply));
        return;
      }
      
      // 如果以上两种方法都不行，获取已铸造的所有NFT（基于合约地址）
      try {
        // 尝试一个小范围查找，最多查找10个
        // 从1开始，因为大多数NFT从1开始编号
        setTotalSupply(0); // 先清空，防止重复计算
        
        for (let i = 1; i <= 20; i++) {
          try {
            const owner = await readContract({
              address: nftAddress,
              abi: ERC721ABI,
              functionName: 'ownerOf',
              args: [i],
              chainId,
            });

            if (owner) {
              // 如果找到有效的owner，说明这个ID存在
              setTotalSupply(prevSupply => Math.max(prevSupply, i));
            }
          } catch (error: any) {
            // 这里的错误很可能是因为代币不存在
            // 我们可以忽略这些错误，继续寻找
            if (!error.message?.includes('ERC721NonexistentToken')) {
              // 如果是其他错误，则记录下来
              console.warn(`查询NFT #${i}所有者时出现非预期错误:`, error);
            }
          }
        }
      } catch (error) {
        console.error('获取NFT总供应量失败:', error);
      }
    } catch (error) {
      console.error('获取NFT总供应量失败:', error);
      setTotalSupply(0);
    }
  };

  // 获取所有NFT信息
  const fetchNFTs = async () => {
    if (!address || totalSupply === 0) return;
    
    setLoading(true);
    const tempNFTs: NFTItem[] = [];
    
    try {
      console.log('totalSupply:', totalSupply);
      for (let i = 1; i <= totalSupply+1; i++) {
        try {
          const owner = await readContract({
            address: nftAddress,
            abi: ERC721ABI,
            functionName: 'ownerOf',
            args: [i-1],
            chainId,
          });
          
          if (owner) {
            const tokenURI = await readTokenURI(i-1).catch(() => '');
            
            tempNFTs.push({
              id: i-1,
              owner: owner as `0x${string}`,
              tokenURI,
            });
          }
        } catch (error: any) {
          // 忽略代币不存在的错误
          if (!error.message?.includes('ERC721NonexistentToken')) {
            console.warn(`获取NFT #${i-1}信息失败:`, error);
          }
        }
      }
      
      setNfts(tempNFTs);
    } catch (error) {
      console.error('获取NFT信息失败:', error);
    } finally {
      setLoading(false);
    }
  };

  // 读取NFT元数据URI
  const readTokenURI = async (tokenId: number): Promise<string> => {
    const result = await readContract({
      address: nftAddress,
      abi: ERC721ABI,
      functionName: 'tokenURI',
      args: [tokenId],
      chainId,
    });
    return result as string;
  };

  // 铸造新NFT
  const handleMint = () => {
    if (!address || !mintURI.trim()) return;
    
    writeContract({
      address: nftAddress,
      abi: ERC721ABI,
      functionName: 'awardItem',
      args: [address, mintURI],
    });
  };

  // 如果尚未挂载，返回加载状态
  if (!mounted) {
    return <div>加载中...</div>;
  }

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold">我的NFT</h2>
      
      {/* Mint NFT表单 */}
      <div className="p-4 border rounded-md bg-gray-50">
        <h3 className="text-lg font-medium mb-3">创建新的NFT</h3>
        <div className="flex gap-2">
          <input
            type="text"
            value={mintURI}
            onChange={(e) => setMintURI(e.target.value)}
            placeholder="输入NFT元数据URI"
            className="flex-1 p-2 border rounded"
          />
          <button
            onClick={handleMint}
            disabled={isMintPending || !mintURI.trim()}
            className="bg-blue-500 hover:bg-blue-600 disabled:bg-gray-400 text-white py-2 px-4 rounded"
          >
            {isMintPending ? '处理中...' : '铸造NFT'}
          </button>
        </div>
      </div>
      
      {/* NFT列表 */}
      <div>
        <h3 className="text-lg font-medium mb-3">NFT列表 ({nfts.length})</h3>
        
        {loading ? (
          <div className="text-center py-8">加载NFT中...</div>
        ) : nfts.length === 0 ? (
          <div className="text-center py-8 text-gray-500">暂无NFT</div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {nfts.map((nft) => (
              <div key={nft.id} className="border rounded-md p-4">
                <div className="mb-2">
                  <span className="text-gray-500">ID:</span> {nft.id}
                </div>
                <div className="mb-2 truncate">
                  <span className="text-gray-500">拥有者:</span> 
                  <span className="font-mono text-sm">
                    {nft.owner === address ? '你' : nft.owner}
                  </span>
                </div>
                <div className="mb-2 truncate">
                  <span className="text-gray-500">URI:</span> 
                  <span className="font-mono text-sm">{nft.tokenURI}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// 辅助函数：读取合约数据
async function readContract({ address, abi, functionName, args, chainId }: any) {
  // 为了解决BigInt序列化问题，自定义JSON序列化
  const body = JSON.stringify({
    address,
    abi,
    functionName,
    args,
    chainId,
  }, (key, value) => {
    // 检查值是否为BigInt类型
    if (typeof value === 'bigint') {
      // 将BigInt转换为字符串
      return value.toString();
    }
    // 其他类型正常返回
    return value;
  });

  const response = await fetch('/api/read-contract', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: body,
  });
  
  const data = await response.json();
  
  // 处理API返回的合约错误
  if (data.contractError) {
    if (data.contractError.type === 'ERC721NonexistentToken') {
      // 对于不存在的Token，直接返回null不抛出错误
      return null;
    }
    // 其他合约错误仍然抛出异常
    throw new Error(data.contractError.message || '合约调用失败');
  }
  
  // 处理API错误
  if (data.error) {
    throw new Error(data.error);
  }
  
  return data.result;
} 