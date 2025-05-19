import { createPublicClient, getAddress, http, toHex } from 'viem';
import { sepolia } from 'viem/chains';

// 创建访问Sepolia测试网的客户端
const client = createPublicClient({
  chain: sepolia,
  transport: http(),
});

// 合约地址
const contractAddress = '0xa815F9a44848810AF8Ae90F672415bd4129b326A' as const;

// LockInfo结构体定义
type LockInfo = {
  user: string;
  startTime: bigint;
  amount: bigint;
};

// 动态数组在Solidity中的储存布局计算
async function readAllLocks() {
  try {
    console.log('从合约中读取私有数组: '+contractAddress);
    
    // 在Solidity中，_locks是合约的第一个状态变量，存储在槽位0
    const arraySlot = '0x0000000000000000000000000000000000000000000000000000000000000000';
    
    // 读取数组长度（存储在槽位0）
    const lengthData = await client.getStorageAt({
      address: contractAddress,
      slot: arraySlot,
    });
    
    const length = BigInt(lengthData || '0x0');
    console.log(`发现 ${length} 个锁仓记录`);
    
    // 数组元素开始的槽位
    // 在 Solidity 中，动态数组元素的槽位从 keccak256(arraySlot) 开始
    // 这里使用预计算的哈希值
    const baseHash = '0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563';
    const baseSlot = BigInt(baseHash);
    
    // 读取每个数组元素
    const locks: LockInfo[] = [];
    
    for (let i = 0; i < Number(length); i++) {
      // 由于结构体有3个字段但只占用2个槽位，我们需要计算正确的偏移量
      // 对于每个元素i，它在 baseSlot + i*2 和 baseSlot + i*2 + 1
      const slotIndex = BigInt(i) * BigInt(2);
      
      // 读取第一个槽位（包含address和uint64）
      const slot1 = toHex(baseSlot + slotIndex);
      const data1 = await client.getStorageAt({
        address: contractAddress,
        slot: slot1,
      });
      
      // 读取第二个槽位（包含uint256 amount）
      const slot2 = toHex(baseSlot + slotIndex + BigInt(1));
      const data2 = await client.getStorageAt({
        address: contractAddress,
        slot: slot2,
      });
      
      // 解析数据
      const userValue = BigInt(data1 || '0x0');
      // 提取低160位作为地址
      const userAddressBigInt = userValue & ((BigInt(1) << BigInt(160)) - BigInt(1));
      const userAddress = getAddress('0x' + userAddressBigInt.toString(16).padStart(40, '0'));
      
      // 提取接下来的64位作为startTime
      const startTime = (userValue >> BigInt(160)) & ((BigInt(1) << BigInt(64)) - BigInt(1));
      
      // 第二个槽位的完整值作为amount
      const amount = BigInt(data2 || '0x0');
      
      locks.push({ user: userAddress, startTime, amount });
      
      // 打印结果
      console.log(`locks[${i}]: user:${userAddress}, startTime:${startTime}, amount:${amount}`);
    }
    
    return locks;
  } catch (error) {
    console.error('读取存储出错:', error);
    return [];
  }
}

// 执行函数
readAllLocks(); 