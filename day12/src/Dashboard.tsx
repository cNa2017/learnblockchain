import React, { useContext, useState } from 'react';
import AddressInput from './components/TokenTransactions/AddressInput';
import ContractList from './components/TokenTransactions/ContractList';
import TransactionLog from './components/TokenTransactions/TransactionLog';
import TransactionsList from './components/TokenTransactions/TransactionsList';
import { UserContext } from './context/UserContext';

const Dashboard: React.FC = () => {
  const { user } = useContext(UserContext);
  const [selectedContractId, setSelectedContractId] = useState<number | null>(null);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* 左侧区域 */}
      <div className="space-y-6">
        <AddressInput />
        
        <ContractList 
          onSelectContract={setSelectedContractId} 
          selectedContractId={selectedContractId} 
        />
        
        <TransactionLog 
          contractId={selectedContractId !== null ? selectedContractId : undefined} 
        />
      </div>
      
      {/* 右侧区域 */}
      <div className="space-y-6">
        <div className="bg-white rounded-lg shadow p-4">
          <h2 className="text-lg font-medium text-gray-800 mb-4">用户信息</h2>
          
          <div className="p-3 bg-gray-100 rounded mb-4">
            <p className="text-sm text-gray-600">钱包地址</p>
            <p className="font-mono text-sm break-all">{user?.address}</p>
          </div>
        </div>
        
        <TransactionsList 
          title={selectedContractId ? "合约交易记录" : "所有交易记录"}
          contractId={selectedContractId !== null ? selectedContractId : undefined}
          userAddress={user?.address}
        />
      </div>
    </div>
  );
};

export default Dashboard; 