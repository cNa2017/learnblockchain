// whitelistBuy.ts
import {
    Abi,
    createPublicClient,
    createWalletClient,
    encodeFunctionData,
    encodePacked,
    getContract,
    http,
    keccak256,
    parseEther
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { foundry } from 'viem/chains';
import merkleMarketJSON from './json/merkleMarket.json';
import permitTokenJSON from './json/permitToken.json';

// JSON文件中导入的是数组，需要将其作为ABI
const merkleMarketABI = merkleMarketJSON as unknown as Abi;
const permitTokenABI = permitTokenJSON as unknown as Abi;

// 合约地址（根据部署日志）
const MARKET_ADDRESS = '0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82';
const TOKEN_ADDRESS = '0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e';
const NFT_ADDRESS = '0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0';

// 白名单用户的私钥
const PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

// 创建客户端
const publicClient = createPublicClient({
  chain: foundry,
  transport: http()
});

const account = privateKeyToAccount(PRIVATE_KEY);
const walletClient = createWalletClient({
  account,
  chain: foundry,
  transport: http()
});

// 生成Merkle树证明
async function generateMerkleProof() {
  // 白名单地址
  const whitelistAddresses = [
    '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
    '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
    '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65'
  ];

  // 计算叶子节点 - 把字符串转成正确的 0x 格式
  const leaves = whitelistAddresses.map(addr => 
    keccak256(encodePacked(['address'], [addr as `0x${string}`]))
  );

  // 我们需要为地址为0的白名单用户生成证明
  const userIndex = 0;
  const userAddress = whitelistAddresses[userIndex];
  const userLeaf = leaves[userIndex];

  // 根据索引位置计算proof
  // 对于这个简单的案例，我们可以手动构建证明
  const proof: `0x${string}`[] = [];
  
  // 用户0需要用户1的节点作为proof
  proof.push(leaves[1]);
  
  // 用户0+1的父节点需要用户2+3的父节点作为proof
  const parentNode23 = hashPair(leaves[2], leaves[3]);
  proof.push(parentNode23);
  
  return { proof, userAddress };
}

// 计算两个节点的哈希值（与合约中相同的逻辑）
function hashPair(a: `0x${string}`, b: `0x${string}`): `0x${string}` {
  return a < b 
    ? keccak256(encodePacked(['bytes32', 'bytes32'], [a, b]))
    : keccak256(encodePacked(['bytes32', 'bytes32'], [b, a]));
}

// 主函数
async function main() {
  try {
    console.log('开始白名单购买测试...');
    
    // 获取白名单证明
    const { proof, userAddress } = await generateMerkleProof();
    console.log(`为白名单用户 ${userAddress} 生成的证明:`, proof);

    // 获取合约实例
    const tokenContract = getContract({
      address: TOKEN_ADDRESS,
      abi: permitTokenABI,
      client: { public: publicClient, wallet: walletClient }
    });

    const marketContract = getContract({
      address: MARKET_ADDRESS,
      abi: merkleMarketABI,
      client: { public: publicClient, wallet: walletClient }
    });
    
    // 准备签名数据，使用permit离线授权
    const tokenAmount = parseEther('500'); // 白名单购买需要500个代币
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1小时后过期
    
    // 获取链ID和合约名称等信息，用于构建EIP-712签名
    const chainId = await publicClient.getChainId();
    const name = String(await tokenContract.read.name());
    
    // 获取当前账户的nonce
    const nonceValue = await tokenContract.read.nonces([account.address]);
    const nonce = BigInt(Number(nonceValue));
    
    // 签署EIP-712离线授权
    const signature = await walletClient.signTypedData({
      domain: {
        name,
        version: '1',
        chainId,
        verifyingContract: TOKEN_ADDRESS,
      },
      types: {
        Permit: [
          { name: 'owner', type: 'address' },
          { name: 'spender', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
          { name: 'deadline', type: 'uint256' },
        ],
      },
      primaryType: 'Permit',
      message: {
        owner: account.address,
        spender: MARKET_ADDRESS,
        value: tokenAmount,
        nonce,
        deadline,
      }
    });
    
    // 从签名中提取 v, r, s
    const r = signature.slice(0, 66) as `0x${string}`;
    const s = `0x${signature.slice(66, 130)}` as `0x${string}`;
    const v = Number(signature.slice(130, 132) === '1c' ? 28 : 27);
    
    console.log('生成的签名:', { v, r, s });
    
    // 使用multicall调用
    console.log('使用multicall调用permitPrePay和claimNFT...');
    
    // 使用encodeFunctionData直接生成调用数据
    const permitPrePayData = encodeFunctionData({
      abi: merkleMarketABI,
      functionName: 'permitPrePay',
      args: [tokenAmount, deadline, v, r, s]
    });
    
    const claimNFTData = encodeFunctionData({
      abi: merkleMarketABI,
      functionName: 'claimNFT',
      args: [0n, proof]
    });
    
    // 使用multicall同时执行这两个调用
    const multicallTx = await marketContract.write.multicall([
      [permitPrePayData, claimNFTData]
    ]);
    
    console.log('交易已发送，交易哈希:', multicallTx);
    
    // 等待交易确认
    const receipt = await publicClient.waitForTransactionReceipt({ 
      hash: multicallTx 
    });
    
    console.log('交易已确认，状态:', receipt.status);
    console.log('白名单购买测试完成！');
    
  } catch (error) {
    console.error('执行过程中出错:', error);
  }
}

// 运行测试
main().catch(console.error);