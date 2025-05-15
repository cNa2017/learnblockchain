import db from '../config/database.js';

class Contract {
  // 创建或更新合约
  static async createOrUpdate(contractData) {
    const { address, name, symbol, decimals } = contractData;
    
    try {
      const [result] = await db.execute(
        `INSERT INTO contracts (address, name, symbol, decimals) 
         VALUES (?, ?, ?, ?) 
         ON DUPLICATE KEY UPDATE 
         name = IF(? IS NOT NULL, ?, name),
         symbol = IF(? IS NOT NULL, ?, symbol),
         decimals = IF(? IS NOT NULL, ?, decimals),
         updated_at = CURRENT_TIMESTAMP`,
        [
          address, name, symbol, decimals,
          name, name,
          symbol, symbol,
          decimals, decimals
        ]
      );

      // 如果是新记录，返回新ID，否则查询现有记录的ID
      if (result.insertId) {
        return { id: result.insertId, ...contractData };
      } else {
        return await this.findByAddress(address);
      }
    } catch (error) {
      console.error('创建或更新合约错误:', error);
      throw error;
    }
  }

  // 根据地址查找合约
  static async findByAddress(address) {
    try {
      const [rows] = await db.execute(
        'SELECT * FROM contracts WHERE address = ?',
        [address]
      );
      return rows[0] || null;
    } catch (error) {
      console.error('查找合约错误:', error);
      throw error;
    }
  }

  // 根据ID查找合约
  static async findById(id) {
    try {
      const [rows] = await db.execute(
        'SELECT * FROM contracts WHERE id = ?',
        [id]
      );
      return rows[0] || null;
    } catch (error) {
      console.error('根据ID查找合约错误:', error);
      throw error;
    }
  }

  // 获取所有合约
  static async getAll() {
    try {
      const [rows] = await db.execute('SELECT * FROM contracts ORDER BY created_at DESC');
      return rows;
    } catch (error) {
      console.error('获取所有合约错误:', error);
      throw error;
    }
  }

  // 获取特定合约的交易记录
  static async getContractTransactions(contractId, limit = 50) {
    try {
      const [rows] = await db.execute(
        `SELECT * FROM transactions 
         WHERE contract_id = ? 
         ORDER BY timestamp DESC 
         LIMIT ?`,
        [contractId, limit]
      );
      return rows;
    } catch (error) {
      console.error('获取合约交易错误:', error);
      throw error;
    }
  }
}

export default Contract; 