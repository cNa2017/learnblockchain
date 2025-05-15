import express from 'express';
import {
    addContract,
    getAllContracts,
    getContractById,
    getContractTransactions,
    triggerContractPolling
} from '../controllers/contractController.js';
import { optionalAuth } from '../middleware/auth.js';

const router = express.Router();

// 获取所有合约
router.get('/', getAllContracts);

// 添加新合约
router.post('/', optionalAuth, addContract);

// 获取特定合约
router.get('/:id', getContractById);

// 获取合约交易
router.get('/:id/transactions', getContractTransactions);

// 手动触发合约轮询
router.post('/:id/poll', triggerContractPolling);

export default router; 