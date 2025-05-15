import React from 'react';
import { useQuery } from 'react-query';
import { contractApi } from '../../services/api';

interface ContractListProps {
  selectedContractId: number | null;
  onSelectContract: (id: number | null) => void;
}

const ContractList: React.FC<ContractListProps> = ({ selectedContractId, onSelectContract }) => {
  const { data, isLoading, error } = useQuery('contracts', contractApi.getAll);

  if (isLoading) {
    return (
      <div className="bg-white rounded-lg shadow p-4">
        <h2 className="text-lg font-medium text-gray-800 mb-3">合约列表</h2>
        <div className="py-4 text-center text-gray-500">加载中...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-lg shadow p-4">
        <h2 className="text-lg font-medium text-gray-800 mb-3">合约列表</h2>
        <div className="py-4 text-center text-red-500">
          加载失败: {(error as Error).message}
        </div>
      </div>
    );
  }

  const contracts = data?.contracts || [];

  return (
    <div className="bg-white rounded-lg shadow p-4">
      <h2 className="text-lg font-medium text-gray-800 mb-3">合约列表</h2>
      
      {contracts.length === 0 ? (
        <div className="py-4 text-center text-gray-500">
          暂无合约，请添加ERC20合约地址
        </div>
      ) : (
        <div className="space-y-2">
          <button
            onClick={() => onSelectContract(null)}
            className={`w-full text-left px-3 py-2 rounded ${
              selectedContractId === null
                ? 'bg-blue-100 text-blue-800'
                : 'hover:bg-gray-100'
            }`}
          >
            显示所有合约
          </button>
          
          {contracts.map((contract: any) => (
            <button
              key={contract.id}
              onClick={() => onSelectContract(contract.id)}
              className={`w-full text-left px-3 py-2 rounded flex items-center justify-between ${
                selectedContractId === contract.id
                  ? 'bg-blue-100 text-blue-800'
                  : 'hover:bg-gray-100'
              }`}
            >
              <div className="flex-1 min-w-0">
                <div className="font-medium truncate">
                  {contract.name || '未知合约'}
                </div>
                <div className="text-xs text-gray-500 truncate">
                  {contract.symbol ? `${contract.symbol} - ` : ''}
                  {`${contract.address.substring(0, 6)}...${contract.address.substring(contract.address.length - 4)}`}
                </div>
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
};

export default ContractList; 