import { createPublicClient, http } from 'viem';
import { sepolia } from 'viem/chains';

// 导入合约ABI
import NFTMarketABI from "../../public/contracts/NFTMarket.json";

// 使用config.js中配置的NFTMarket合约地址
const NFT_MARKET_ADDRESS = window.APP_CONFIG.contracts.nftMarket;

// 创建公共客户端
const publicClient = createPublicClient({
  chain: sepolia,
  transport: http("https://sepolia.infura.io/v3/ffcda30520a845238726f8ef17ce38d2")
});

// 存储事件日志
let eventLogs = [];

/**
 * 开始监听NFTMarket合约事件
 */
export const startEventListening = () => {
  // 监听NFT上架事件
  const unWatchNFTListed = publicClient.watchContractEvent({
    address: NFT_MARKET_ADDRESS,
    abi: NFTMarketABI,
    eventName: 'Listed',
    onLogs: (logs) => {
      logs.forEach(log => {
        const { args, blockNumber, transactionHash } = log;
        const { seller, tokenId, price } = args;
        
        const eventLog = {
          type: 'NFTListed',
          timestamp: new Date().toLocaleString(),
          blockNumber,
          transactionHash,
          details: {
            seller,
            tokenId: tokenId.toString(),
            price: price.toString()
          }
        };
        
        console.log('NFT上架事件:', eventLog);
        eventLogs.unshift(eventLog); // 新事件添加到数组开头
      });
    },
  });
  
  // 监听NFT售出事件
  const unWatchNFTSold = publicClient.watchContractEvent({
    address: NFT_MARKET_ADDRESS,
    abi: NFTMarketABI,
    eventName: 'Bought',
    onLogs: (logs) => {
      logs.forEach(log => {
        const { args, blockNumber, transactionHash } = log;
        const { buyer, tokenId, price } = args;
        
        const eventLog = {
          type: 'NFTSold',
          timestamp: new Date().toLocaleString(),
          blockNumber,
          transactionHash,
          details: {
            buyer,
            seller: '', // Bought事件中没有seller参数
            tokenId: tokenId.toString(),
            price: price.toString()
          }
        };
        
        console.log('NFT售出事件:', eventLog);
        eventLogs.unshift(eventLog); // 新事件添加到数组开头
      });
    },
  });
  
  // 监听代币接收事件
  const unWatchTokensReceived = publicClient.watchContractEvent({
    address: NFT_MARKET_ADDRESS,
    abi: NFTMarketABI,
    eventName: 'TokensReceived',
    onLogs: (logs) => {
      logs.forEach(log => {
        const { args, blockNumber, transactionHash } = log;
        const { buyer, tokenId, price, amount } = args;
        
        const eventLog = {
          type: 'TokensReceived',
          timestamp: new Date().toLocaleString(),
          blockNumber,
          transactionHash,
          details: {
            operator: '',
            from: '',
            to: buyer,
            price: price.toString(),
            tokenId: tokenId.toString(),
            amount: amount.toString()
          }
        };
        
        console.log('代币接收事件:', eventLog);
        eventLogs.unshift(eventLog); // 新事件添加到数组开头
      });
    },
  });
  
  // 防止重复监听
  if (window._eventListeningActive) {
    console.log('已有监听器在运行，不重复创建');
    return window._eventListeningUnwatch;
  }
  
  // 标记监听状态
  window._eventListeningActive = true;
  window._eventListeningUnwatch = () => {
    unWatchNFTListed();
    unWatchNFTSold();
    unWatchTokensReceived();
    window._eventListeningActive = false;
    console.log('已停止监听NFTMarket合约事件');
  };
  
  return window._eventListeningUnwatch;
  
  // 已在上面返回取消监听的函数
};

/**
 * 获取事件日志
 * @param {number} limit 限制返回的日志数量
 * @returns {Array} 事件日志数组
 */
export const getEventLogs = (limit = 100) => {
  return eventLogs.slice(0, limit);
};

/**
 * 清除事件日志
 */
export const clearEventLogs = () => {
  eventLogs = [];
  console.log('已清除所有事件日志');
};