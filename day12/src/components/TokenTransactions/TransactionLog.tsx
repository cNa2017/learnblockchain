import React from 'react';
import { useQuery } from 'react-query';
import { pollingLogApi } from '../../services/api';

interface TransactionLogProps {
  contractId?: number;
}

const TransactionLog: React.FC<TransactionLogProps> = ({ contractId }) => {
  const { data, isLoading, error } = useQuery(
    ['pollingLogs', contractId],
    () => contractId 
      ? pollingLogApi.getContractLogs(contractId) 
      : pollingLogApi.getLatest(),
    {
      refetchInterval: 5000, // 每5秒刷新一次
      enabled: true
    }
  );

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'pending':
        return <span className="px-2 py-1 text-xs rounded-full bg-yellow-100 text-yellow-800">等待中</span>;
      case 'processing':
        return <span className="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">处理中</span>;
      case 'completed':
        return <span className="px-2 py-1 text-xs rounded-full bg-green-100 text-green-800">已完成</span>;
      case 'failed':
        return <span className="px-2 py-1 text-xs rounded-full bg-red-100 text-red-800">失败</span>;
      default:
        return <span className="px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800">{status}</span>;
    }
  };

  if (isLoading) {
    return (
      <div className="bg-white rounded-lg shadow p-4">
        <h2 className="text-lg font-medium text-gray-800 mb-3">轮询日志</h2>
        <div className="py-4 text-center text-gray-500">加载中...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-lg shadow p-4">
        <h2 className="text-lg font-medium text-gray-800 mb-3">轮询日志</h2>
        <div className="py-4 text-center text-red-500">
          加载失败: {(error as Error).message}
        </div>
      </div>
    );
  }

  const logs = data?.logs || [];

  return (
    <div className="bg-white rounded-lg shadow p-4">
      <h2 className="text-lg font-medium text-gray-800 mb-3">
        轮询日志 {contractId ? '(选定合约)' : '(所有合约)'}
      </h2>
      
      {logs.length === 0 ? (
        <div className="py-4 text-center text-gray-500">
          暂无轮询日志
        </div>
      ) : (
        <div className="space-y-3 max-h-96 overflow-y-auto">
          {logs.map((log: any) => (
            <div key={log.id} className="border-b border-gray-200 pb-3 last:border-b-0 last:pb-0">
              <div className="flex justify-between items-center mb-1">
                <div className="text-sm font-medium">
                  {log.contract_address && (
                    <span className="font-mono text-xs">
                      {`${log.contract_address.substring(0, 6)}...${log.contract_address.substring(log.contract_address.length - 4)}`}
                    </span>
                  )}
                  {log.contract_symbol && (
                    <span className="ml-1 text-gray-600">({log.contract_symbol})</span>
                  )}
                </div>
                <div>
                  {getStatusBadge(log.status)}
                </div>
              </div>
              
              <div className="text-sm text-gray-600">
                {log.message}
              </div>
              
              <div className="text-xs text-gray-500 mt-1">
                {new Date(log.created_at).toLocaleString()}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default TransactionLog; 