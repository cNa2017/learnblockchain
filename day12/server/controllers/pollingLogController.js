import PollingLog from '../models/PollingLog.js';

// 获取最新轮询日志
export const getLatestLogs = async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const logs = await PollingLog.getLatest(limit);
    
    res.json({
      success: true,
      logs
    });
  } catch (error) {
    console.error('获取轮询日志错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
};

// 获取特定合约的轮询日志
export const getContractLogs = async (req, res) => {
  try {
    const { contractId } = req.params;
    const limit = parseInt(req.query.limit) || 20;
    
    if (!contractId) {
      return res.status(400).json({ success: false, message: '合约ID不能为空' });
    }
    
    const logs = await PollingLog.getLatestByContract(contractId, limit);
    
    res.json({
      success: true,
      logs
    });
  } catch (error) {
    console.error('获取合约轮询日志错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
}; 