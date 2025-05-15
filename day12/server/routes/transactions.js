import express from 'express';
import { getLatestTransactions } from '../controllers/transactionController.js';

const router = express.Router();

// 获取最新交易记录
router.get('/', getLatestTransactions);

export default router;