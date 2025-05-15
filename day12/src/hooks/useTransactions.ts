import { useEffect, useState } from 'react';
import { contractApi, transactionApi } from '../services/api';
import { ERC20Contract, Transaction } from '../types';

// 获取合约列表的钩子
export const useContracts = (address?: string) => {
  const [contracts, setContracts] = useState<ERC20Contract[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // 获取所有合约地址
  const fetchContracts = async () => {
    if (!address) return;
    
    setLoading(true);
    setError(null);
    try {
      const data = await contractApi.getAll();
      setContracts(data);
    } catch (err: any) {
      setError(err.response?.data?.message || '获取合约列表失败');
      console.error('Error fetching contracts:', err);
    } finally {
      setLoading(false);
    }
  };

  // 获取当前地址相关的合约
  const fetchAddressContracts = async () => {
    if (!address) return;
    
    setLoading(true);
    setError(null);
    try {
      const data = await contractApi.getAll(); // 修改为适当的API调用
      setContracts(data);
    } catch (err: any) {
      setError(err.response?.data?.message || '获取合约列表失败');
      console.error('Error fetching address contracts:', err);
    } finally {
      setLoading(false);
    }
  };

  // 添加新合约地址
  const addContract = async (contractAddress: string) => {
    if (!address) throw new Error('钱包未连接');
    
    setLoading(true);
    setError(null);
    try {
      const newContract = await contractApi.add(contractAddress);
      setContracts(prev => [...prev, newContract]);
      return newContract;
    } catch (err: any) {
      setError(err.response?.data?.message || '添加合约地址失败');
      console.error('Error adding contract:', err);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  // 当连接状态变化时获取合约列表
  useEffect(() => {
    if (address) {
      fetchAddressContracts();
    } else {
      setContracts([]);
    }
  }, [address]);

  return { contracts, loading, error, fetchContracts, fetchAddressContracts, addContract };
};

// 获取交易数据的钩子
export const useTransactions = (address?: string, contractId?: number) => {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // 获取交易记录
  const fetchTransactions = async () => {
    if (!address) return;
    
    setLoading(true);
    setError(null);
    try {
      let data: Transaction[];
      if (contractId) {
        data = await contractApi.getTransactions(contractId);
      } else {
        data = await transactionApi.getUserTransactions(address);
      }
      setTransactions(data);
    } catch (err: any) {
      setError(err.response?.data?.message || '获取交易记录失败');
      console.error('Error fetching transactions:', err);
    } finally {
      setLoading(false);
    }
  };

  // 当地址或合约ID变化时获取交易记录
  useEffect(() => {
    if (address) {
      fetchTransactions();
    } else {
      setTransactions([]);
    }
  }, [address, contractId]);

  return { transactions, loading, error, fetchTransactions };
}; 