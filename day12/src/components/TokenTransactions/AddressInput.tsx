import React, { useState } from 'react';
import { useMutation, useQueryClient } from 'react-query';
import { contractApi } from '../../services/api';

const AddressInput: React.FC = () => {
  const [address, setAddress] = useState('');
  const queryClient = useQueryClient();

  const mutation = useMutation(contractApi.add, {
    onSuccess: () => {
      // 成功后清空输入框并刷新合约列表
      setAddress('');
      queryClient.invalidateQueries('contracts');
    }
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!address) {
      return;
    }
    
    // 验证地址格式
    if (!/^0x[a-fA-F0-9]{40}$/.test(address)) {
      alert('请输入有效的以太坊地址！');
      return;
    }
    
    mutation.mutate(address);
  };

  return (
    <div className="bg-white rounded-lg shadow p-4">
      <h2 className="text-lg font-medium text-gray-800 mb-3">添加ERC20合约</h2>
      
      <form onSubmit={handleSubmit} className="space-y-3">
        <div>
          <label htmlFor="address" className="sr-only">ERC20合约地址</label>
          <input
            id="address"
            type="text"
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            placeholder="输入ERC20合约地址"
            className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            disabled={mutation.isLoading}
          />
        </div>
        
        <button
          type="submit"
          disabled={!address || mutation.isLoading}
          className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-md shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {mutation.isLoading ? '处理中...' : '获取交易记录'}
        </button>
        
        {mutation.isError && (
          <p className="text-red-600 text-sm mt-2">
            {(mutation.error as Error).message || '添加合约失败，请重试'}
          </p>
        )}
        
        {mutation.isSuccess && (
          <p className="text-green-600 text-sm mt-2">
            合约添加成功，开始获取交易记录
          </p>
        )}
      </form>
    </div>
  );
};

export default AddressInput; 