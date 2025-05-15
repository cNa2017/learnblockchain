import Transaction from '../models/Transaction.js';

// 获取用户的交易
export const getUserTransactions = async (req, res) => {
  try {
    const userId = req.user.id;
    const transactions = await Transaction.getUserTransactions(userId);
    res.json(transactions);
  } catch (error) {
    console.error('获取用户交易错误:', error);
    res.status(500).json({ message: '服务器错误' });
  }
};

// 获取合约的交易
export const getContractTransactions = async (req, res) => {
  try {
    const { contractId } = req.params;
    const transactions = await Transaction.getContractTransactions(contractId);
    res.json(transactions);
  } catch (error) {
    console.error('获取合约交易错误:', error);
    res.status(500).json({ message: '服务器错误' });
  }
};

// 获取最新交易记录
export const getLatestTransactions = async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const transactions = await Transaction.getLatest(limit);
    
    res.json({
      success: true,
      transactions
    });
  } catch (error) {
    console.error('获取最新交易记录错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
}; 