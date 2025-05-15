import db from '../config/database.js';

class User {
  // 创建用户
  static async create(address) {
    try {
      const [result] = await db.execute(
        'INSERT INTO users (address) VALUES (?) ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP',
        [address]
      );

      // 如果是新记录，返回新ID，否则查询现有记录的ID
      if (result.insertId) {
        return { id: result.insertId, address };
      } else {
        const [rows] = await db.execute(
          'SELECT id FROM users WHERE address = ?',
          [address]
        );
        return rows[0] || null;
      }
    } catch (error) {
      console.error('创建用户错误:', error);
      throw error;
    }
  }

  // 根据地址查找用户
  static async findByAddress(address) {
    try {
      const [rows] = await db.execute(
        'SELECT * FROM users WHERE address = ?',
        [address]
      );
      return rows[0] || null;
    } catch (error) {
      console.error('查找用户错误:', error);
      throw error;
    }
  }

  // 获取用户交易记录
  static async getUserTransactions(address, limit = 20) {
    try {
      const [rows] = await db.execute(
        `SELECT t.*, c.address as contract_address, c.name as contract_name, c.symbol as contract_symbol
         FROM transactions t
         JOIN contracts c ON t.contract_id = c.id
         WHERE t.from_address = ? OR t.to_address = ?
         ORDER BY t.timestamp DESC
         LIMIT ?`,
        [address, address, limit]
      );
      return rows;
    } catch (error) {
      console.error('获取用户交易错误:', error);
      throw error;
    }
  }
}

export default User; 