import { ERC20_ABI, publicClient } from '../config/viem.js';
import Contract from '../models/Contract.js';
import { pollSpecificContract } from '../services/pollingService.js';

// 获取所有合约
export const getAllContracts = async (req, res) => {
  try {
    const contracts = await Contract.getAll();
    res.json({ success: true, contracts });
  } catch (error) {
    console.error('获取所有合约错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
};

// 添加新合约
export const addContract = async (req, res) => {
  try {
    const { address } = req.body;
    
    if (!address) {
      return res.status(400).json({ success: false, message: '合约地址不能为空' });
    }
    
    // 验证地址格式
    if (!/^0x[a-fA-F0-9]{40}$/.test(address)) {
      return res.status(400).json({ success: false, message: '无效的合约地址格式' });
    }
    
    // 检查合约是否已存在
    const existingContract = await Contract.findByAddress(address.toLowerCase());
    if (existingContract) {
      return res.json({ 
        success: true, 
        contract: existingContract,
        message: '合约已存在' 
      });
    }
    
    // 尝试获取合约信息
    let name = null;
    let symbol = null;
    let decimals = null;
    
    try {
      [name, symbol, decimals] = await Promise.all([
        publicClient.readContract({
          address: address,
          abi: ERC20_ABI,
          functionName: 'name',
        }),
        publicClient.readContract({
          address: address,
          abi: ERC20_ABI,
          functionName: 'symbol',
        }),
        publicClient.readContract({
          address: address,
          abi: ERC20_ABI,
          functionName: 'decimals',
        }),
      ]);
    } catch (err) {
      console.warn(`获取合约信息出错:`, err);
      // 继续执行，这里不返回错误，而是使用null值
    }
    
    // 创建合约
    const contract = await Contract.createOrUpdate({
      address: address.toLowerCase(),
      name,
      symbol,
      decimals,
    });
    
    // 异步启动轮询
    pollSpecificContract(contract.id).catch(err => {
      console.error('启动合约轮询出错:', err);
    });
    
    res.json({
      success: true,
      contract,
      message: '合约添加成功'
    });
  } catch (error) {
    console.error('添加合约错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
};

// 获取用户的合约订阅
export const getUserSubscriptions = async (req, res) => {
  try {
    const userId = req.user.id;
    const subscriptions = await Contract.getUserSubscriptions(userId);
    res.json(subscriptions);
  } catch (error) {
    console.error('获取用户订阅错误:', error);
    res.status(500).json({ message: '服务器错误' });
  }
};

// 获取特定合约详情
export const getContractById = async (req, res) => {
  try {
    const { id } = req.params;
    
    if (!id) {
      return res.status(400).json({ success: false, message: 'ID不能为空' });
    }
    
    const contract = await Contract.findById(id);
    
    if (!contract) {
      return res.status(404).json({ success: false, message: '找不到合约' });
    }
    
    res.json({
      success: true,
      contract
    });
  } catch (error) {
    console.error('获取合约详情错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
};

// 获取特定合约的交易记录
export const getContractTransactions = async (req, res) => {
  try {
    const { id } = req.params;
    const limit = parseInt(req.query.limit) || 50;
    
    if (!id) {
      return res.status(400).json({ success: false, message: 'ID不能为空' });
    }
    
    const transactions = await Contract.getContractTransactions(id, limit);
    
    res.json({
      success: true,
      transactions
    });
  } catch (error) {
    console.error('获取合约交易记录错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
};

// 手动触发合约轮询
export const triggerContractPolling = async (req, res) => {
  try {
    const { id } = req.params;
    
    if (!id) {
      return res.status(400).json({ success: false, message: 'ID不能为空' });
    }
    
    const result = await pollSpecificContract(id);
    
    if (!result.success) {
      return res.status(400).json({ success: false, message: result.error });
    }
    
    res.json({
      success: true,
      message: '轮询任务已提交'
    });
  } catch (error) {
    console.error('触发合约轮询错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
}; 