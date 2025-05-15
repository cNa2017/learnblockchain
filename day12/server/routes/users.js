import express from 'express';
import { getUserInfo, getUserTransactions, loginUser } from '../controllers/userController.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// 用户登录
router.post('/login', loginUser);

// 获取用户信息
router.get('/me', authenticateToken, getUserInfo);

// 获取用户交易记录
router.get('/:address/transactions', getUserTransactions);

export default router;