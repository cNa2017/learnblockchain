# NFT与Wagmi交互规范

## NFT合约交互模式

### ERC721标准读取

```tsx
// NFT基本信息读取
const { data: name } = useReadContract({
  address: NFT_ADDRESS as `0x${string}`,
  abi: NFT_ABI,
  functionName: 'name',
});

const { data: symbol } = useReadContract({
  address: NFT_ADDRESS as `0x${string}`,
  abi: NFT_ABI,
  functionName: 'symbol',
});

// 查询NFT所有者
const { data: owner } = useReadContract({
  address: NFT_ADDRESS as `0x${string}`,
  abi: NFT_ABI,
  functionName: 'ownerOf',
  args: [tokenId],
});

// 查询账户持有的NFT数量
const { data: balance } = useReadContract({
  address: NFT_ADDRESS as `0x${string}`,
  abi: NFT_ABI,
  functionName: 'balanceOf',
  args: [address],
});
```

### ERC721转账

```tsx
// 使用safeTransferFrom转移NFT
const { writeContract } = useWriteContract();

const handleTransfer = () => {
  writeContract({
    address: NFT_ADDRESS as `0x${string}`,
    abi: NFT_ABI,
    functionName: 'safeTransferFrom',
    args: [from, to, tokenId],
  });
};
```

### 批准NFT使用权

```tsx
// 批准其他地址操作特定NFT
const { writeContract } = useWriteContract();

const handleApprove = () => {
  writeContract({
    address: NFT_ADDRESS as `0x${string}`,
    abi: NFT_ABI,
    functionName: 'approve',
    args: [operator, tokenId],
  });
};

// 批准或撤销操作者对所有NFT的权限
const handleSetApprovalForAll = (approved: boolean) => {
  writeContract({
    address: NFT_ADDRESS as `0x${string}`,
    abi: NFT_ABI,
    functionName: 'setApprovalForAll',
    args: [operator, approved],
  });
};

// 检查是否已授权所有NFT
const { data: isApprovedForAll } = useReadContract({
  address: NFT_ADDRESS as `0x${string}`,
  abi: NFT_ABI,
  functionName: 'isApprovedForAll',
  args: [owner, operator],
});
```

## NFT元数据获取

### 通过tokenURI获取元数据

```tsx
// 获取NFT的URI
const { data: tokenURI } = useReadContract({
  address: NFT_ADDRESS as `0x${string}`,
  abi: NFT_ABI,
  functionName: 'tokenURI',
  args: [tokenId],
});

// 自定义Hook获取NFT元数据
export function useNFTMetadata(address: `0x${string}`, tokenId: bigint) {
  const { data: tokenURI } = useReadContract({
    address,
    abi: NFT_ABI,
    functionName: 'tokenURI',
    args: [tokenId],
  });
  
  const [metadata, setMetadata] = useState<NFTMetadata | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  
  useEffect(() => {
    if (!tokenURI) return;
    
    const fetchMetadata = async () => {
      setIsLoading(true);
      try {
        // 处理IPFS链接
        const url = tokenURI.replace('ipfs://', 'https://ipfs.io/ipfs/');
        const response = await fetch(url);
        const data = await response.json();
        setMetadata(data);
      } catch (err) {
        setError(err instanceof Error ? err : new Error('Failed to fetch metadata'));
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchMetadata();
  }, [tokenURI]);
  
  return { metadata, isLoading, error };
}
```

## NFT市场交互

### 上架NFT

```tsx
// 上架NFT到市场
const handleListNFT = () => {
  // 首先需要批准市场合约操作NFT
  writeContract({
    address: NFT_ADDRESS as `0x${string}`,
    abi: NFT_ABI,
    functionName: 'approve',
    args: [MARKETPLACE_ADDRESS, tokenId],
  });
  
  // 监听批准事件完成后上架
  useEffect(() => {
    if (isApproveSuccess) {
      writeContract({
        address: MARKETPLACE_ADDRESS as `0x${string}`,
        abi: MARKETPLACE_ABI,
        functionName: 'listItem',
        args: [NFT_ADDRESS, tokenId, price],
      });
    }
  }, [isApproveSuccess]);
};
```

### 购买NFT

```tsx
// 从市场购买NFT
const handleBuyNFT = () => {
  writeContract({
    address: MARKETPLACE_ADDRESS as `0x${string}`,
    abi: MARKETPLACE_ABI,
    functionName: 'buyItem',
    args: [NFT_ADDRESS, tokenId],
    value: price, // 支付的ETH金额
  });
};
```

### 取消NFT上架

```tsx
// 取消NFT上架
const handleCancelListing = () => {
  writeContract({
    address: MARKETPLACE_ADDRESS as `0x${string}`,
    abi: MARKETPLACE_ABI,
    functionName: 'cancelListing',
    args: [NFT_ADDRESS, tokenId],
  });
};
```

## NFT数据展示组件

### NFT卡片组件

```tsx
interface NFTCardProps {
  contractAddress: `0x${string}`;
  tokenId: bigint;
  onClick?: () => void;
}

export function NFTCard({ contractAddress, tokenId, onClick }: NFTCardProps) {
  const { metadata, isLoading } = useNFTMetadata(contractAddress, tokenId);
  const { data: owner } = useReadContract({
    address: contractAddress,
    abi: NFT_ABI,
    functionName: 'ownerOf',
    args: [tokenId],
  });
  
  if (isLoading) {
    return <div className="rounded-lg p-4 h-64 bg-gray-100 animate-pulse" />;
  }
  
  return (
    <div 
      className="border rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow"
      onClick={onClick}
    >
      {metadata?.image && (
        <img 
          src={metadata.image.replace('ipfs://', 'https://ipfs.io/ipfs/')} 
          alt={metadata.name || `NFT #${tokenId}`}
          className="w-full h-48 object-cover"
        />
      )}
      <div className="p-4">
        <h3 className="font-semibold text-lg">{metadata?.name || `NFT #${tokenId}`}</h3>
        {metadata?.description && (
          <p className="text-sm text-gray-600 line-clamp-2">{metadata.description}</p>
        )}
        <p className="text-xs text-gray-500 mt-2">
          Owner: {formatAddress(owner || '')}
        </p>
      </div>
    </div>
  );
}
```

### NFT集合组件

```tsx
interface NFTCollectionProps {
  contractAddress: `0x${string}`;
  ownerAddress?: `0x${string}`;
}

export function NFTCollection({ contractAddress, ownerAddress }: NFTCollectionProps) {
  const [tokensOwned, setTokensOwned] = useState<bigint[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  
  // 获取持有的代币ID
  useEffect(() => {
    if (!ownerAddress) return;
    
    const fetchOwnedTokens = async () => {
      setIsLoading(true);
      try {
        // 这里简化了实现，实际项目中需要考虑分页和大量NFT的情况
        // 可能需要使用合约的事件查询或专门的索引服务
        
        // 假设我们有一个方法可以获取所有者拥有的代币ID
        const tokens = await getOwnedTokenIds(contractAddress, ownerAddress);
        setTokensOwned(tokens);
      } catch (error) {
        console.error('Error fetching owned tokens:', error);
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchOwnedTokens();
  }, [contractAddress, ownerAddress]);
  
  if (isLoading) {
    return <div>加载中...</div>;
  }
  
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
      {tokensOwned.map((tokenId) => (
        <NFTCard 
          key={tokenId.toString()} 
          contractAddress={contractAddress} 
          tokenId={tokenId} 
        />
      ))}
      {tokensOwned.length === 0 && (
        <div className="col-span-full text-center py-8 text-gray-500">
          没有找到NFT
        </div>
      )}
    </div>
  );
}
```

## NFT交易历史

### 查询交易事件

```tsx
// 获取特定NFT的Transfer事件历史
export function useNFTTransferHistory(
  contractAddress: `0x${string}`, 
  tokenId: bigint
) {
  const client = useClient();
  const [events, setEvents] = useState<TransferEvent[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  
  useEffect(() => {
    const fetchEvents = async () => {
      if (!client || !contractAddress || !tokenId) return;
      
      setIsLoading(true);
      try {
        // 查询从创建到现在的所有转账事件
        const logs = await client.getLogs({
          address: contractAddress,
          event: {
            type: 'event',
            name: 'Transfer',
            inputs: [
              { type: 'address', name: 'from', indexed: true },
              { type: 'address', name: 'to', indexed: true },
              { type: 'uint256', name: 'tokenId', indexed: true },
            ],
          },
          args: {
            tokenId: tokenId,
          },
          fromBlock: 0n,
          toBlock: 'latest',
        });
        
        // 转换日志为更易用的格式
        const transferEvents = logs.map(log => ({
          from: log.args.from as `0x${string}`,
          to: log.args.to as `0x${string}`,
          tokenId: log.args.tokenId as bigint,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        }));
        
        setEvents(transferEvents);
      } catch (error) {
        console.error('Error fetching transfer events:', error);
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchEvents();
  }, [client, contractAddress, tokenId]);
  
  return { events, isLoading };
}
```

## NFT铸造

### 铸造新NFT

```tsx
// 铸造新NFT
const { writeContract } = useWriteContract();

const handleMintNFT = (to: `0x${string}`, uri: string) => {
  writeContract({
    address: NFT_ADDRESS as `0x${string}`,
    abi: NFT_ABI,
    functionName: 'mint',
    args: [to, uri],
  });
};
```

### 批量铸造

```tsx
// 批量铸造NFT
const handleBatchMint = (to: `0x${string}`, uris: string[]) => {
  writeContract({
    address: NFT_ADDRESS as `0x${string}`,
    abi: NFT_ABI,
    functionName: 'batchMint',
    args: [to, uris],
  });
};
```

## 错误处理最佳实践

### NFT特有错误处理

```tsx
// NFT操作常见错误处理
function parseNFTError(error: Error): string {
  // 处理NFT交互常见错误
  if (error.message.includes('ERC721: invalid token ID')) {
    return '无效的NFT ID';
  }
  
  if (error.message.includes('ERC721: caller is not token owner or approved')) {
    return '您没有权限操作此NFT';
  }
  
  if (error.message.includes('ERC721: transfer to non ERC721Receiver')) {
    return '接收地址不支持接收NFT';
  }
  
  // 返回通用错误消息
  return error.message;
}
```

## 性能优化

### 高效加载多个NFT

```tsx
// 高效加载多个NFT元数据
export function useBatchNFTMetadata(
  contractAddress: `0x${string}`,
  tokenIds: bigint[]
) {
  const [metadataMap, setMetadataMap] = useState<Record<string, NFTMetadata>>({});
  const [isLoading, setIsLoading] = useState(false);
  
  useEffect(() => {
    if (!tokenIds.length) return;
    
    const fetchMetadata = async () => {
      setIsLoading(true);
      
      try {
        // 并行请求所有token URIs
        const uriPromises = tokenIds.map(id => {
          return fetchTokenURI(contractAddress, id);
        });
        
        const uris = await Promise.all(uriPromises);
        
        // 并行请求所有元数据
        const metadataPromises = uris.map((uri, index) => {
          if (!uri) return null;
          
          const url = uri.replace('ipfs://', 'https://ipfs.io/ipfs/');
          return fetch(url)
            .then(res => res.json())
            .then(data => ({ tokenId: tokenIds[index].toString(), data }))
            .catch(() => ({ tokenId: tokenIds[index].toString(), data: null }));
        });
        
        const results = await Promise.all(metadataPromises);
        
        // 构建映射
        const newMetadataMap = results.reduce((map, result) => {
          if (result && result.data) {
            map[result.tokenId] = result.data;
          }
          return map;
        }, {} as Record<string, NFTMetadata>);
        
        setMetadataMap(newMetadataMap);
      } catch (error) {
        console.error('Error batch fetching metadata:', error);
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchMetadata();
  }, [contractAddress, tokenIds]);
  
  return { metadataMap, isLoading };
}

// 辅助函数：获取单个token的URI
async function fetchTokenURI(address: `0x${string}`, tokenId: bigint): Promise<string | null> {
  // 这里应该使用合约调用获取tokenURI
  // 简化实现
  try {
    const client = getClient();
    const data = await client.readContract({
      address,
      abi: NFT_ABI,
      functionName: 'tokenURI',
      args: [tokenId],
    });
    return data as string;
  } catch (error) {
    console.error(`Error fetching URI for token ${tokenId}:`, error);
    return null;
  }
}
```

## 安全考虑

### 防止重入攻击

检查NFT合约是否实现了重入保护机制，特别是在涉及交易的场景下：

```tsx
// 确保marketplace合约实现了ReentrancyGuard或类似的保护机制
// 在前端，我们可以显示警告如果检测到不安全的合约

const { data: implementsReentrancyGuard } = useReadContract({
  address: MARKETPLACE_ADDRESS as `0x${string}`,
  abi: ['function supportsInterface(bytes4 interfaceId) view returns (bool)'],
  functionName: 'supportsInterface',
  args: ['0x4e2312e0'], // ReentrancyGuard接口ID（假设）
});

// 在UI中显示安全警告
{!implementsReentrancyGuard && (
  <div className="bg-yellow-100 text-yellow-800 p-3 rounded mb-4">
    警告：此市场合约可能不安全，缺乏重入攻击保护
  </div>
)}
``` 