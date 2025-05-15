import dotenv from 'dotenv';
import jwt from 'jsonwebtoken';
import User from '../models/User.js';

dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET || 'default_jwt_secret_key';

// 处理用户登录（通过钱包地址）
export const loginUser = async (req, res) => {
  try {
    const { address } = req.body;
    
    if (!address) {
      return res.status(400).json({ success: false, message: '钱包地址不能为空' });
    }
    
    // 创建或获取用户
    const user = await User.create(address);
    
    // 生成JWT令牌
    const token = jwt.sign(
      { id: user.id, address: address.toLowerCase() },
      JWT_SECRET,
      { expiresIn: '7d' }
    );
    
    res.json({
      success: true,
      user: { id: user.id, address: address.toLowerCase() },
      token
    });
  } catch (error) {
    console.error('用户登录错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
};

// 获取用户信息
export const getUserInfo = async (req, res) => {
  try {
    // 用户信息从auth中间件获取
    const user = req.user;
    
    if (!user) {
      return res.status(401).json({ success: false, message: '未授权' });
    }
    
    res.json({
      success: true,
      user
    });
  } catch (error) {
    console.error('获取用户信息错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
};

// 获取用户交易记录
export const getUserTransactions = async (req, res) => {
  try {
    const { address } = req.params;
    const limit = parseInt(req.query.limit) || 20;
    
    if (!address) {
      return res.status(400).json({ success: false, message: '地址不能为空' });
    }
    
    const transactions = await User.getUserTransactions(address.toLowerCase(), limit);
    
    res.json({
      success: true,
      transactions
    });
  } catch (error) {
    console.error('获取用户交易记录错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
}; 