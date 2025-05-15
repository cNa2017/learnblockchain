import axios from 'axios';
import { getAuthHeader } from './authService';

const API_URL = 'http://localhost:3001/api';

// 创建带认证的axios实例
const api = axios.create({
  baseURL: API_URL,
});

// 请求拦截器添加认证
api.interceptors.request.use(
  (config) => {
    const headers = getAuthHeader();
    if (headers.Authorization) {
      config.headers = {
        ...config.headers,
        ...headers
      };
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// 合约相关API
export const contractApi = {
  // 获取所有合约
  getAll: async () => {
    const response = await api.get('/contracts');
    return response.data;
  },
  
  // 添加新合约
  add: async (address: string) => {
    const response = await api.post('/contracts', { address });
    return response.data;
  },
  
  // 获取特定合约
  getById: async (id: number) => {
    const response = await api.get(`/contracts/${id}`);
    return response.data;
  },
  
  // 获取合约交易
  getTransactions: async (id: number, limit = 50) => {
    const response = await api.get(`/contracts/${id}/transactions?limit=${limit}`);
    return response.data;
  },
  
  // 触发合约轮询
  triggerPolling: async (id: number) => {
    const response = await api.post(`/contracts/${id}/poll`);
    return response.data;
  }
};

// 交易相关API
export const transactionApi = {
  // 获取最新交易
  getLatest: async (limit = 20) => {
    const response = await api.get(`/transactions?limit=${limit}`);
    return response.data;
  },
  
  // 获取用户交易
  getUserTransactions: async (address: string, limit = 20) => {
    const response = await api.get(`/users/${address}/transactions?limit=${limit}`);
    return response.data;
  }
};

// 轮询日志相关API
export const pollingLogApi = {
  // 获取最新轮询日志
  getLatest: async (limit = 50) => {
    const response = await api.get(`/polling-logs?limit=${limit}`);
    return response.data;
  },
  
  // 获取合约轮询日志
  getContractLogs: async (contractId: number, limit = 20) => {
    const response = await api.get(`/polling-logs/contract/${contractId}?limit=${limit}`);
    return response.data;
  }
};

export default api; 