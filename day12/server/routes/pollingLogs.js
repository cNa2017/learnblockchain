import express from 'express';
import { getAllLogs, getContractLogs } from '../controllers/pollingLogController.js';

const router = express.Router();

// 获取所有轮询日志
router.get('/', getAllLogs);

// 获取特定合约的轮询日志
router.get('/contract/:contractId', getContractLogs);

export default router; 