'use client';

import { useEffect, useState } from 'react';
import { useAccount, useChainId, useReadContract, useWriteContract } from 'wagmi';
import ERC20ABI from '../../contracts/ERC20.json';
import ERC721ABI from '../../contracts/ERC721.json';
import NFTMarketABI from '../../contracts/nftMarket.json';

interface NFTMarketProps {
  nftAddress: `0x${string}`;
  nftMarketAddress: `0x${string}`;
  tokenAddress: `0x${string}`;
}

interface NFTListing {
  tokenId: number;
  seller: `0x${string}`;
  price: bigint;
  active: boolean;
}

export function NFTMarket({ nftAddress, nftMarketAddress, tokenAddress }: NFTMarketProps) {
  const { address } = useAccount();
  const chainId = useChainId();
  const [mounted, setMounted] = useState(false);
  const [listings, setListings] = useState<NFTListing[]>([]);
  const [loading, setLoading] = useState(true);
  const [ownedNFTs, setOwnedNFTs] = useState<number[]>([]);
  const [listTokenId, setListTokenId] = useState('');
  const [listPrice, setListPrice] = useState('');
  const [allowance, setAllowance] = useState<bigint>(BigInt(0));
  const [tokenBalance, setTokenBalance] = useState<bigint>(BigInt(0));
  const [totalSupply, setTotalSupply] = useState<number>(0);

  // 合约写入操作
  const { 
    writeContract,
    isPending: isWritePending,
    isSuccess: isWriteSuccess,
    isError: isWriteError,
    error: writeError
  } = useWriteContract();

  // 查询ERC20余额
  const { data: balance, refetch: refetchBalance } = useReadContract({
    address: tokenAddress,
    abi: ERC20ABI,
    functionName: 'balanceOf',
    args: [address],
  });

  // 查询ERC20授权额度
  const { data: approvedAmount, refetch: refetchAllowance } = useReadContract({
    address: tokenAddress,
    abi: ERC20ABI,
    functionName: 'allowance',
    args: [address, nftMarketAddress],
  });

  // 仅在客户端挂载后执行
  useEffect(() => {
    setMounted(true);
  }, []);

  // 初始化和更新数据
  useEffect(() => {
    if (mounted && address) {
      fetchTotalSupply();
      if (balance) {
        setTokenBalance(BigInt(balance.toString()));
      }
      if (approvedAmount) {
        setAllowance(BigInt(approvedAmount.toString()));
      }
    }
  }, [mounted, address, balance, approvedAmount, chainId]);

  // 获取数据依赖于totalSupply
  useEffect(() => {
    if (mounted && address && totalSupply > 0) {
      fetchListings();
      fetchOwnedNFTs();
    }
  }, [mounted, address, totalSupply]);

  // 交易成功后刷新数据
  useEffect(() => {
    if (isWriteSuccess) {
      fetchTotalSupply();
      fetchListings();
      fetchOwnedNFTs();
      refetchBalance();
      refetchAllowance();
    }
    
    if (isWriteError) {
      console.error('交易失败:', writeError);
    }
  }, [isWriteSuccess, isWriteError, writeError, refetchBalance, refetchAllowance]);

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
        // 尝试一个小范围查找，最多查找20个
        setTotalSupply(0); // 先清空，防止重复计算
        
        for (let i = 1; i <= 20; i++) {  // 修改这里，从0开始
          try {
            const owner = await readContract({
              address: nftAddress,
              abi: ERC721ABI,
              functionName: 'ownerOf',
              args: [i-1],
              chainId,
            });

            if (owner) {
              // 如果找到有效的owner，说明这个ID存在
              setTotalSupply(prevSupply => Math.max(prevSupply, i));
            }
          } catch (error: any) {
            // 这里的错误很可能是因为代币不存在
            if (!error.message?.includes('ERC721NonexistentToken')) {
              console.warn(`查询NFT #${i-1}所有者时出现非预期错误:`, error);
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

  // 获取市场上架的NFT列表
  const fetchListings = async () => {
    if (!address || totalSupply === 0) return;
    
    setLoading(true);
    try {
      const tempListings: NFTListing[] = [];
      
      for (let i = 0; i <= totalSupply; i++) {
        try {
          // 先检查NFT是否存在
          const ownerExists = await readContract({
            address: nftAddress,
            abi: ERC721ABI,
            functionName: 'ownerOf',
            args: [i],
            chainId,
          }).catch(() => null);
          
          if (ownerExists) {
            // 如果NFT存在，再查询其在市场上的列表状态
            const listing = await readContract({
              address: nftMarketAddress,
              abi: NFTMarketABI,
              functionName: 'listings',
              args: [i],
              chainId,
            });
            console.log('Listing for token', i, ':', listing);
            if (listing && listing[2]) {  // 检查listing存在且第三个元素（active状态）为true
              tempListings.push({
                tokenId: i,
                seller: listing[0] as `0x${string}`,  // 第一个元素是卖家地址
                price: BigInt(listing[1].toString()),  // 第二个元素是价格
                active: listing[2],  // 第三个元素是active状态
              });
            }
          }
        } catch (error: any) {
          // 忽略代币不存在的错误
          if (!error.message?.includes('ERC721NonexistentToken')) {
            console.warn(`获取NFT #${i}上架信息失败:`, error);
          }
        }
      }
      
      setListings(tempListings);
    } catch (error) {
      console.error('获取NFT上架列表失败:', error);
    } finally {
      setLoading(false);
    }
  };

  // 获取用户拥有的NFT
  const fetchOwnedNFTs = async () => {
    if (!address || totalSupply === 0) return;
    
    try {
      const owned: number[] = [];
      
      for (let i = 0; i < totalSupply; i++) {
        try {
          const owner = await readContract({
            address: nftAddress,
            abi: ERC721ABI,
            functionName: 'ownerOf',
            args: [i],
            chainId,
          });
          
          if (owner && owner.toLowerCase() === address?.toLowerCase()) {
            owned.push(i);
          }
        } catch (error: any) {
          // 忽略代币不存在的错误
          if (!error.message?.includes('ERC721NonexistentToken')) {
            console.warn(`获取NFT #${i}所有者失败:`, error);
          }
        }
      }
      console.log('Owned NFTs:', owned); // 打印Owned NFTs inf
      setOwnedNFTs(owned);
    } catch (error) {
      console.error('获取拥有的NFT失败:', error);
    }
  };

  // 上架NFT到市场
  const handleListNFT = async () => {
    if (!address || !listTokenId || !listPrice) return;
    
    const tokenId = parseInt(listTokenId);
    const price = BigInt(parseFloat(listPrice) * 10**18); // 转换为Wei
    
    try {
      // 先授权NFT给市场合约
      writeContract({
        address: nftAddress,
        abi: ERC721ABI,
        functionName: 'approve',
        args: [nftMarketAddress, tokenId],
      });
      
      // 等待授权完成后上架
      // 注意：在实际应用中应添加等待授权完成的逻辑
      setTimeout(() => {
        writeContract({
          address: nftMarketAddress,
          abi: NFTMarketABI,
          functionName: 'list',
          args: [tokenId, price],
        });
        
        // 再设置一个延时，确保交易完成后刷新列表
        setTimeout(() => {
          fetchListings();
        }, 3000);
      }, 2000);
    } catch (error) {
      console.error('上架NFT失败:', error);
    }
  };

  // 授权ERC20代币给市场合约
  const handleApproveToken = () => {
    if (!address) return;
    
    const maxAmount = BigInt(2) ** BigInt(256) - BigInt(1); // 最大值
    
    writeContract({
      address: tokenAddress,
      abi: ERC20ABI,
      functionName: 'approve',
      args: [nftMarketAddress, maxAmount],
    });
  };

  // 购买NFT
  const handleBuyNFT = (tokenId: number) => {
    if (!address) return;
    
    writeContract({
      address: nftMarketAddress,
      abi: NFTMarketABI,
      functionName: 'buyNFT',
      args: [tokenId],
    });
  };

  // 如果尚未挂载，返回加载状态
  if (!mounted) {
    return <div>加载中...</div>;
  }

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold">NFT 市场</h2>
      
      {/* 用户拥有的NFT和上架表单 */}
      <div className="p-4 border rounded-md bg-gray-50">
        <h3 className="text-lg font-medium mb-3">上架我的NFT</h3>
        
        {ownedNFTs.length === 0 ? (
          <div className="text-gray-500 mb-4">你没有可以上架的NFT</div>
        ) : (
          <div>
            <div className="mb-3">
              <p className="text-sm text-gray-600 mb-1">我拥有的NFT:</p>
              <div className="flex flex-wrap gap-2">
                {ownedNFTs.map((id) => (
                  <span 
                    key={id}
                    className="px-2 py-1 bg-blue-100 rounded text-sm cursor-pointer"
                    onClick={() => setListTokenId(id.toString())}
                  >
                    #{id}
                  </span>
                ))}
              </div>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-4">
              <div>
                <label className="block text-sm text-gray-600 mb-1">NFT ID</label>
                <input
                  type="text"
                  value={listTokenId}
                  onChange={(e) => setListTokenId(e.target.value)}
                  placeholder="输入NFT ID"
                  className="w-full p-2 border rounded"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-600 mb-1">价格 (Token)</label>
                <input
                  type="text"
                  value={listPrice}
                  onChange={(e) => setListPrice(e.target.value)}
                  placeholder="输入价格"
                  className="w-full p-2 border rounded"
                />
              </div>
            </div>
            
            <button
              onClick={handleListNFT}
              disabled={isWritePending || !listTokenId || !listPrice}
              className="bg-blue-500 hover:bg-blue-600 disabled:bg-gray-400 text-white py-2 px-4 rounded"
            >
              {isWritePending ? '处理中...' : '上架NFT'}
            </button>
          </div>
        )}
      </div>
      
      {/* Token授权和余额信息 */}
      <div className="p-4 border rounded-md bg-gray-50">
        <h3 className="text-lg font-medium mb-3">Token信息</h3>
        
        <div className="mb-3">
          <p className="text-sm text-gray-600">Token余额:</p>
          <p className="font-medium">{(Number(tokenBalance) / 10**18).toFixed(2)} Token</p>
        </div>
        
        <div className="mb-4">
          <p className="text-sm text-gray-600">授权市场使用的Token:</p>
          <p className="font-medium">{allowance > 0 ? '已授权' : '未授权'}</p>
        </div>
        
        {allowance === BigInt(0) && (
          <button
            onClick={handleApproveToken}
            disabled={isWritePending}
            className="bg-green-500 hover:bg-green-600 disabled:bg-gray-400 text-white py-2 px-4 rounded"
          >
            {isWritePending ? '处理中...' : '授权Token给市场'}
          </button>
        )}
      </div>
      
      {/* NFT上架列表 */}
      <div>
        <div className="flex justify-between items-center mb-3">
          <h3 className="text-lg font-medium">市场上架NFT</h3>
          <button
            onClick={() => {
              setLoading(true);
              fetchListings();
            }}
            className="bg-gray-200 hover:bg-gray-300 text-gray-700 py-1 px-3 rounded text-sm"
          >
            刷新列表
          </button>
        </div>
        
        {loading ? (
          <div className="text-center py-8">加载NFT中...</div>
        ) : listings.length === 0 ? (
          <div className="text-center py-8 text-gray-500">市场暂无NFT上架</div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {listings.map((listing) => (
              <div key={listing.tokenId} className="border rounded-md p-4">
                <div className="mb-2">
                  <span className="text-gray-500">NFT ID:</span> {listing.tokenId}
                </div>
                <div className="mb-2 truncate">
                  <span className="text-gray-500">卖家:</span> 
                  <span className="font-mono text-sm">
                    {listing.seller.toLowerCase() === address?.toLowerCase() 
                      ? '你' 
                      : `${listing.seller.substring(0, 6)}...${listing.seller.substring(listing.seller.length - 4)}`
                    }
                  </span>
                </div>
                <div className="mb-4">
                  <span className="text-gray-500">价格:</span> 
                  <span className="font-medium">{(Number(listing.price) / 10**18).toFixed(2)} Token</span>
                </div>
                
                {listing.seller.toLowerCase() !== address?.toLowerCase() && (
                  <button
                    onClick={() => handleBuyNFT(listing.tokenId)}
                    disabled={isWritePending || allowance === BigInt(0) || tokenBalance < listing.price}
                    className="w-full bg-purple-500 hover:bg-purple-600 disabled:bg-gray-400 text-white py-2 px-4 rounded"
                  >
                    {isWritePending 
                      ? '处理中...' 
                      : allowance === BigInt(0)
                        ? '需要先授权Token'
                        : tokenBalance < listing.price
                          ? 'Token余额不足'
                          : '购买NFT'
                    }
                  </button>
                )}
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