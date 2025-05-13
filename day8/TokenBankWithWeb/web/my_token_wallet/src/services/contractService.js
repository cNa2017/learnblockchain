import { createPublicClient, createWalletClient, http, parseEther, formatEther } from 'viem';
import { sepolia } from 'viem/chains';
// import { sepolia } from 'viem/chains';

// 导入合约ABI
import TokenBankABI from "../../public/contracts/TokenBank.json";
import ERC20ABI from "../../public/contracts/ERC20.json";

// 使用main.js中配置的合约地址
const TOKEN_BANK_ADDRESS = window.APP_CONFIG.contracts.tokenBank;
const ERC20_ADDRESS = window.APP_CONFIG.contracts.erc20;

// 创建公共客户端
const publicClient = createPublicClient({
  chain: sepolia,
  transport: http()
});

// 钱包客户端
let walletClient = null;

// 当前连接的账户地址
let currentAccount = null;

/**
 * 连接钱包
 */
export const connectWallet = async () => {
  try {
    // 请求用户连接MetaMask
    const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
    currentAccount = accounts[0];
    
    // 创建钱包客户端
    walletClient = createWalletClient({
      account: currentAccount,
      chain: sepolia,
      transport: http()
    });
    
    return { success: true, account: currentAccount };
  } catch (error) {
    console.error('连接钱包失败:', error);
    return { success: false, error: error.message };
  }
};

/**
 * 获取ERC20代币余额
 * @param {string} address 地址
 * @returns {Promise<string>} 余额
 */
export const getERC20Balance = async (address) => {
  try {
    console.log('-----currentAccount', currentAccount); // 
    console.log('-----ERC20ABI',ERC20ABI); // 
    const balance = await publicClient.readContract({
      address: ERC20_ADDRESS,
      abi: ERC20ABI,
      functionName: 'balanceOf',
      args: [address || currentAccount]
    });
    
    return formatEther(balance);
  } catch (error) {
    console.error('获取ERC20余额失败:', error);
    throw error;
  }
};

/**
 * 获取TokenBank中的代币余额
 * @param {string} address 地址
 * @returns {Promise<string>} 余额
 */
export const getTokenBankBalance = async (address) => {
  try {
    const balance = await publicClient.readContract({
      address: TOKEN_BANK_ADDRESS,
      abi: TokenBankABI,
      functionName: 'balances',
      args: [address || currentAccount]
    });
    
    return formatEther(balance);
  } catch (error) {
    console.error('获取TokenBank余额失败:', error);
    throw error;
  }
};

/**
 * 存入代币到TokenBank
 * @param {string} amount 存款金额
 * @returns {Promise<object>} 交易结果
 */
export const depositToBank = async (amount) => {
  try {
    if (!walletClient) {
      throw new Error('钱包未连接');
    }
      console.log('-----walletClient1', walletClient); //
      // 首先需要批准TokenBank合约使用代币
      const approveHash = await walletClient.writeContract({
        account:currentAccount,
        address: ERC20_ADDRESS,
        abi: ERC20ABI,
        functionName: 'approve',
        args: [TOKEN_BANK_ADDRESS, parseEther(amount)]
      });
      console.log('-----walletClient2', walletClient); //
    
    // 等待批准交易确认
    await publicClient.waitForTransactionReceipt({ hash: approveHash });
    
    // 然后存款
    const depositHash = await walletClient.writeContract({
      address: TOKEN_BANK_ADDRESS,
      abi: TokenBankABI,
      functionName: 'deposit',
      args: [parseEther(amount)]
    });
    
    // 等待存款交易确认
    const receipt = await publicClient.waitForTransactionReceipt({ hash: depositHash });
    
    return { success: true, hash: depositHash, receipt };
  } catch (error) {
    console.error('存款失败:', error);
    return { success: false, error: error.message };
  }
};

/**
 * 从TokenBank取出代币
 * @param {string} amount 取款金额
 * @returns {Promise<object>} 交易结果
 */
export const withdrawFromBank = async (amount) => {
  try {
    if (!walletClient) {
      throw new Error('钱包未连接');
    }
    
    const withdrawHash = await walletClient.writeContract({
      address: TOKEN_BANK_ADDRESS,
      abi: TokenBankABI,
      functionName: 'withdraw',
      args: [parseEther(amount)]
    });
    
    // 等待取款交易确认
    const receipt = await publicClient.waitForTransactionReceipt({ hash: withdrawHash });
    
    return { success: true, hash: withdrawHash, receipt };
  } catch (error) {
    console.error('取款失败:', error);
    return { success: false, error: error.message };
  }
};