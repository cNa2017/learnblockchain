import db from '../config/database.js';

class Transaction {
  // 创建交易记录
  static async create(txData) {
    const { tx_hash, contract_id, from_address, to_address, value, block_number, timestamp } = txData;
    
    // 确保地址格式正确
    const normalizedFromAddress = from_address ? from_address.toLowerCase() : null;
    const normalizedToAddress = to_address ? to_address.toLowerCase() : null;
    
    try {
      const [result] = await db.execute(
        `INSERT INTO transactions 
         (tx_hash, contract_id, from_address, to_address, value, block_number, timestamp) 
         VALUES (?, ?, ?, ?, ?, ?, ?) 
         ON DUPLICATE KEY UPDATE 
         contract_id = ?,
         from_address = ?,
         to_address = ?,
         value = ?,
         block_number = ?,
         timestamp = ?`,
        [
          tx_hash, contract_id, normalizedFromAddress, normalizedToAddress, value, block_number, timestamp,
          contract_id, normalizedFromAddress, normalizedToAddress, value, block_number, timestamp
        ]
      );
      
      return { id: result.insertId || 0, ...txData };
    } catch (error) {
      console.error('创建交易记录错误:', error);
      throw error;
    }
  }

  // 批量创建交易记录
  static async bulkCreate(transactions) {
    if (!transactions || transactions.length === 0) {
      return [];
    }

    try {
      // 准备批量插入数据
      const values = transactions.map(tx => [
        tx.tx_hash, 
        tx.contract_id, 
        tx.from_address ? tx.from_address.toLowerCase() : null, // 确保地址小写
        tx.to_address ? tx.to_address.toLowerCase() : null, // 确保地址小写
        tx.value, 
        tx.block_number, 
        tx.timestamp
      ]);
      
      const placeholders = values.map(() => '(?, ?, ?, ?, ?, ?, ?)').join(', ');
      
      const [result] = await db.query(
        `INSERT INTO transactions
         (tx_hash, contract_id, from_address, to_address, value, block_number, timestamp)
         VALUES ${placeholders}
         ON DUPLICATE KEY UPDATE
         contract_id = VALUES(contract_id),
         from_address = VALUES(from_address),
         to_address = VALUES(to_address),
         value = VALUES(value),
         block_number = VALUES(block_number),
         timestamp = VALUES(timestamp)`,
        values.flat()
      );
      
      return result;
    } catch (error) {
      console.error('批量创建交易记录错误:', error);
      throw error;
    }
  }

  // 根据哈希查找交易
  static async findByHash(txHash) {
    try {
      const [rows] = await db.execute(
        'SELECT * FROM transactions WHERE tx_hash = ?',
        [txHash]
      );
      return rows[0] || null;
    } catch (error) {
      console.error('查找交易记录错误:', error);
      throw error;
    }
  }

  // 获取最新交易记录
  static async getLatest(limit = 20) {
    try {
      const [rows] = await db.execute(
        `SELECT t.*, c.address as contract_address, c.name as contract_name, c.symbol as contract_symbol
         FROM transactions t
         JOIN contracts c ON t.contract_id = c.id
         ORDER BY t.timestamp DESC
         LIMIT ?`,
        [limit]
      );
      return rows;
    } catch (error) {
      console.error('获取最新交易记录错误:', error);
      throw error;
    }
  }

  // 获取某个合约的最高区块
  static async getHighestBlockNumber(contractId) {
    try {
      const [rows] = await db.execute(
        'SELECT MAX(block_number) as highest_block FROM transactions WHERE contract_id = ?',
        [contractId]
      );
      return rows[0]?.highest_block || 0;
    } catch (error) {
      console.error('获取最高区块错误:', error);
      throw error;
    }
  }
}

export default Transaction; 