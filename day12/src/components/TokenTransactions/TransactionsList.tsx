import React from 'react';
import { useQuery } from 'react-query';
import { contractApi, transactionApi } from '../../services/api';

interface TransactionsListProps {
  title: string;
  contractId?: number;
  userAddress?: string;
}

const TransactionsList: React.FC<TransactionsListProps> = ({ title, contractId, userAddress }) => {
  // 获取交易数据
  const { data, isLoading, error } = useQuery(
    ['transactions', contractId, userAddress],
    () => {
      if (contractId) {
        // 获取合约交易
        return contractApi.getTransactions(contractId);
      } else if (userAddress) {
        // 获取用户交易
        return transactionApi.getUserTransactions(userAddress);
      } else {
        // 获取所有最新交易
        return transactionApi.getLatest();
      }
    },
    {
      refetchInterval: 10000, // 每10秒刷新一次
      enabled: true
    }
  );

  // 格式化数值显示
  const formatValue = (value: string, decimals: number = 18) => {
    try {
      if (!value) return '0';
      
      // 将字符串转为BigInt
      const bigValue = BigInt(value);
      
      // 转换为显示值（简单实现）
      const divisor = BigInt(10) ** BigInt(decimals);
      const integerPart = bigValue / divisor;
      const fractionalPart = bigValue % divisor;
      
      return `${integerPart}.${fractionalPart.toString().padStart(decimals, '0').substring(0, 6)}`;
    } catch (e) {
      return value;
    }
  };

  if (isLoading) {
    return (
      <div className="bg-white rounded-lg shadow p-4">
        <h2 className="text-lg font-medium text-gray-800 mb-3">{title}</h2>
        <div className="py-4 text-center text-gray-500">加载中...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-lg shadow p-4">
        <h2 className="text-lg font-medium text-gray-800 mb-3">{title}</h2>
        <div className="py-4 text-center text-red-500">
          加载失败: {(error as Error).message}
        </div>
      </div>
    );
  }

  const transactions = data?.transactions || [];

  return (
    <div className="bg-white rounded-lg shadow p-4">
      <h2 className="text-lg font-medium text-gray-800 mb-3">{title}</h2>
      
      {transactions.length === 0 ? (
        <div className="py-4 text-center text-gray-500">
          暂无交易记录
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th scope="col" className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  交易哈希
                </th>
                <th scope="col" className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  转出
                </th>
                <th scope="col" className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  转入
                </th>
                <th scope="col" className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  数量
                </th>
                <th scope="col" className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  时间
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {transactions.map((tx: any) => (
                <tr key={tx.id} className="hover:bg-gray-50">
                  <td className="px-3 py-2 whitespace-nowrap text-xs font-mono">
                    <a 
                      href={`https://sepolia.etherscan.io/tx/${tx.tx_hash}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-blue-600 hover:underline"
                    >
                      {tx.tx_hash.substring(0, 8)}...{tx.tx_hash.substring(tx.tx_hash.length - 6)}
                    </a>
                  </td>
                  <td className="px-3 py-2 whitespace-nowrap text-xs font-mono">
                    <a 
                      href={`https://sepolia.etherscan.io/address/${tx.from_address}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className={`hover:underline ${userAddress && tx.from_address.toLowerCase() === userAddress.toLowerCase() ? 'text-green-600 font-bold' : 'text-gray-900'}`}
                    >
                      {tx.from_address.substring(0, 6)}...{tx.from_address.substring(tx.from_address.length - 4)}
                    </a>
                  </td>
                  <td className="px-3 py-2 whitespace-nowrap text-xs font-mono">
                    <a 
                      href={`https://sepolia.etherscan.io/address/${tx.to_address}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className={`hover:underline ${userAddress && tx.to_address.toLowerCase() === userAddress.toLowerCase() ? 'text-green-600 font-bold' : 'text-gray-900'}`}
                    >
                      {tx.to_address.substring(0, 6)}...{tx.to_address.substring(tx.to_address.length - 4)}
                    </a>
                  </td>
                  <td className="px-3 py-2 whitespace-nowrap text-xs">
                    {formatValue(tx.value, tx.contract_decimals || 18)}
                    {tx.contract_symbol && <span className="text-gray-500 ml-1">{tx.contract_symbol}</span>}
                  </td>
                  <td className="px-3 py-2 whitespace-nowrap text-xs text-gray-500">
                    {new Date(tx.timestamp).toLocaleString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default TransactionsList; 