import dotenv from 'dotenv';
import jwt from 'jsonwebtoken';
import User from '../models/User.js';

dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET || 'default_jwt_secret_key';

// 验证JWT令牌
export const authenticateToken = async (req, res, next) => {
  // 从请求头中获取令牌
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ success: false, message: '未提供认证令牌' });
  }
  
  try {
    // 验证令牌
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // 从数据库获取用户信息
    const user = await User.findByAddress(decoded.address);
    
    if (!user) {
      return res.status(401).json({ success: false, message: '用户不存在' });
    }
    
    // 将用户信息添加到请求对象
    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: '令牌已过期' });
    }
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ success: false, message: '无效的令牌' });
    }
    
    console.error('认证错误:', error);
    return res.status(500).json({ success: false, message: '服务器错误' });
  }
};

// 可选的身份验证
export const optionalAuth = async (req, res, next) => {
  // 从请求头中获取令牌
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    // 没有令牌，继续执行
    return next();
  }
  
  try {
    // 验证令牌
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // 从数据库获取用户信息
    const user = await User.findByAddress(decoded.address);
    
    if (user) {
      // 将用户信息添加到请求对象
      req.user = user;
    }
    
    next();
  } catch (error) {
    // 令牌无效，但我们不返回错误，让请求继续
    next();
  }
}; 