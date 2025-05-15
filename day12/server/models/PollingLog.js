import db from '../config/database.js';

class PollingLog {
  // 创建轮询日志
  static async create(logData) {
    const { contract_id, status, last_block_number, message } = logData;
    
    try {
      const [result] = await db.execute(
        `INSERT INTO polling_logs 
         (contract_id, status, last_block_number, message) 
         VALUES (?, ?, ?, ?)`,
        [contract_id, status, last_block_number, message]
      );
      
      return { id: result.insertId, ...logData };
    } catch (error) {
      console.error('创建轮询日志错误:', error);
      throw error;
    }
  }

  // 更新轮询日志
  static async update(id, updateData) {
    const { status, last_block_number, message } = updateData;
    
    try {
      const fields = [];
      const values = [];
      
      if (status !== undefined) {
        fields.push('status = ?');
        values.push(status);
      }
      
      if (last_block_number !== undefined) {
        fields.push('last_block_number = ?');
        values.push(last_block_number);
      }
      
      if (message !== undefined) {
        fields.push('message = ?');
        values.push(message);
      }
      
      if (fields.length === 0) {
        return null;
      }
      
      values.push(id);
      
      await db.execute(
        `UPDATE polling_logs 
         SET ${fields.join(', ')} 
         WHERE id = ?`,
        values
      );
      
      return { id, ...updateData };
    } catch (error) {
      console.error('更新轮询日志错误:', error);
      throw error;
    }
  }

  // 获取合约最近的轮询日志
  static async getLatestByContract(contractId, limit = 20) {
    try {
      const [rows] = await db.execute(
        `SELECT * FROM polling_logs 
         WHERE contract_id = ? 
         ORDER BY created_at DESC 
         LIMIT ?`,
        [contractId, limit]
      );
      return rows;
    } catch (error) {
      console.error('获取合约轮询日志错误:', error);
      throw error;
    }
  }

  // 获取所有轮询日志
  static async getLatest(limit = 50) {
    try {
      const [rows] = await db.execute(
        `SELECT pl.*, c.address as contract_address, c.symbol as contract_symbol
         FROM polling_logs pl
         JOIN contracts c ON pl.contract_id = c.id
         ORDER BY pl.created_at DESC
         LIMIT ?`,
        [limit]
      );
      return rows;
    } catch (error) {
      console.error('获取轮询日志错误:', error);
      throw error;
    }
  }
}

export default PollingLog; 