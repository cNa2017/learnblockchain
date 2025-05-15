import express from 'express';
import { getContractLogs, getLatestLogs } from '../controllers/pollingLogController.js';

const router = express.Router();

// 获取最新轮询日志
router.get('/', getLatestLogs);

// 获取特定合约的轮询日志
router.get('/contract/:contractId', getContractLogs);

export default router; 