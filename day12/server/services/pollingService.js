import { BLOCKS_PER_POLLING, MAX_CONCURRENT_TASKS, POLLING_INTERVAL, getTransferLogs, publicClient } from '../config/viem.js';
import Contract from '../models/Contract.js';
import PollingLog from '../models/PollingLog.js';
import Transaction from '../models/Transaction.js';

let io;
let isPolling = false;
let pollingQueue = [];
let activePollingTasks = 0;

// 启动轮询服务
export function startPollingService(socketIo) {
  io = socketIo;
  
  // 设置定时任务
  setInterval(async () => {
    try {
      if (!isPolling) {
        isPolling = true;
        await pollAllContracts();
        isPolling = false;
      }
    } catch (error) {
      console.error('轮询服务运行错误:', error);
      isPolling = false;
    }
  }, POLLING_INTERVAL);
  
  console.log('轮询服务已启动');
  
  // 定时检查队列
  setInterval(processQueue, 5000);
}

// 处理轮询队列
async function processQueue() {
  if (pollingQueue.length === 0 || activePollingTasks >= MAX_CONCURRENT_TASKS) {
    return;
  }
  
  // 从队列取出任务并执行
  while (pollingQueue.length > 0 && activePollingTasks < MAX_CONCURRENT_TASKS) {
    const task = pollingQueue.shift();
    activePollingTasks++;
    
    task()
      .catch(error => console.error('轮询任务执行错误:', error))
      .finally(() => {
        activePollingTasks--;
        // 检查是否可以处理更多任务
        if (pollingQueue.length > 0 && activePollingTasks < MAX_CONCURRENT_TASKS) {
          processQueue();
        }
      });
  }
}

// 轮询所有合约
async function pollAllContracts() {
  try {
    // 获取所有合约
    const contracts = await Contract.getAll();
    
    if (contracts.length === 0) {
      return;
    }
    
    // 获取当前区块号
    const currentBlockNumber = await publicClient.getBlockNumber();
    
    // 将每个合约的轮询任务加入队列
    for (const contract of contracts) {
      // 加入队列而不是立即执行
      pollingQueue.push(() => pollContractEvents(contract, currentBlockNumber));
    }
    
    // 开始处理队列
    processQueue();
    
  } catch (error) {
    console.error('轮询所有合约错误:', error);
    // 通知前端出错
    if (io) {
      io.emit('polling_error', { message: `轮询合约错误: ${error.message}` });
    }
  }
}

// 轮询单个合约的事件
async function pollContractEvents(contract, currentBlockNumber) {
  // 创建初始日志
  const logEntry = await PollingLog.create({
    contract_id: contract.id,
    status: 'processing',
    last_block_number: null,
    message: '开始获取交易数据'
  });
  
  // 通知前端开始轮询
  if (io) {
    io.emit('polling_started', { 
      contractId: contract.id, 
      contractAddress: contract.address,
      logId: logEntry.id
    });
  }
  
  try {
    // 获取最后处理的区块
    const lastProcessedBlock = await Transaction.getHighestBlockNumber(contract.id);
    
    // 确定起始和结束区块
    const fromBlock = lastProcessedBlock ? Number(lastProcessedBlock) + 1 : 0;
    const toBlock = Number(currentBlockNumber);
    
    // 如果没有新区块，则跳过
    if (fromBlock > toBlock) {
      await PollingLog.update(logEntry.id, {
        status: 'completed',
        last_block_number: toBlock,
        message: '没有新区块需要处理'
      });
      
      // 通知前端完成
      if (io) {
        io.emit('polling_completed', { 
          contractId: contract.id, 
          contractAddress: contract.address,
          fromBlock,
          toBlock,
          transactionsFound: 0,
          logId: logEntry.id
        });
      }
      
      return;
    }
    
    // 更新日志
    await PollingLog.update(logEntry.id, {
      message: `处理区块 ${fromBlock} 到 ${toBlock}`
    });
    
    let processedTransactions = 0;
    
    // 按块范围分批处理
    for (let startBlock = fromBlock; startBlock <= toBlock; startBlock += BLOCKS_PER_POLLING) {
      const endBlock = Math.min(startBlock + BLOCKS_PER_POLLING - 1, toBlock);
      
      // 更新日志状态
      await PollingLog.update(logEntry.id, {
        message: `处理区块 ${startBlock} 到 ${endBlock}`
      });
      
      // 获取Transfer事件日志
      const logs = await getTransferLogs(contract.address, startBlock, endBlock);
      
      if (logs.length > 0) {
        // 转换日志为交易记录
        const transactions = await Promise.all(logs.map(async (log) => {
          console.log("log-------:",log);
          // 获取区块时间戳
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          
          return {
            tx_hash: log.transactionHash,
            contract_id: contract.id,
            from_address: log.args.from.toLowerCase(),
            to_address: log.args.to.toLowerCase(),
            value: log.args.value.toString(),
            block_number: Number(log.blockNumber),
            timestamp: new Date(Number(block.timestamp) * 1000)
          };
        }));
        
        // 批量保存交易
        await Transaction.bulkCreate(transactions);
        
        processedTransactions += transactions.length;
        
        // 通知前端进度
        if (io) {
          io.emit('polling_progress', { 
            contractId: contract.id, 
            contractAddress: contract.address,
            currentBlock: endBlock,
            totalBlocks: toBlock - fromBlock,
            transactionsFound: processedTransactions,
            logId: logEntry.id
          });
        }
      }
    }
    
    // 完成处理
    await PollingLog.update(logEntry.id, {
      status: 'completed',
      last_block_number: toBlock,
      message: `处理完成，发现 ${processedTransactions} 笔交易`
    });
    
    // 通知前端完成
    if (io) {
      io.emit('polling_completed', { 
        contractId: contract.id, 
        contractAddress: contract.address,
        fromBlock,
        toBlock,
        transactionsFound: processedTransactions,
        logId: logEntry.id
      });
    }
    
  } catch (error) {
    console.error(`轮询合约 ${contract.address} 错误:`, error);
    
    // 更新日志为失败状态
    await PollingLog.update(logEntry.id, {
      status: 'failed',
      message: `错误: ${error.message}`
    });
    
    // 通知前端出错
    if (io) {
      io.emit('polling_error', { 
        contractId: contract.id, 
        contractAddress: contract.address,
        error: error.message,
        logId: logEntry.id
      });
    }
  }
}

// 手动触发特定合约的轮询
export async function pollSpecificContract(contractId) {
  try {
    const contract = await Contract.findById(contractId);
    if (!contract) {
      throw new Error('合约不存在');
    }
    
    const currentBlockNumber = await publicClient.getBlockNumber();
    
    // 加入队列
    pollingQueue.push(() => pollContractEvents(contract, currentBlockNumber));
    
    // 开始处理队列
    processQueue();
    
    return { success: true, message: '已加入轮询队列' };
  } catch (error) {
    console.error('手动轮询合约错误:', error);
    return { success: false, error: error.message };
  }
} 