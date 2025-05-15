import dotenv from 'dotenv';
import mysql from 'mysql2/promise';

dotenv.config();

// 打印配置信息(不包含密码)用于调试
console.log(`数据库连接信息: 
  host: ${process.env.DB_HOST || '127.0.0.1'}
  port: ${process.env.DB_PORT || '3306'}
  user: ${process.env.DB_USER || 'root'}
  database: ${process.env.DB_NAME || 'viem_test'}
`);

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: parseInt(process.env.DB_PORT || '3306'),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',  // 如果没有密码，使用空字符串
  database: process.env.DB_NAME || 'viem_test',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// 测试连接
pool.getConnection()
  .then(connection => {
    console.log('数据库连接成功');
    connection.release();
  })
  .catch(err => {
    console.error('数据库连接错误:', err);
  });

export default pool; 