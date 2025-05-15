import React, { useEffect, useState } from 'react';
import { QueryClient, QueryClientProvider } from 'react-query';
import { createWalletClient, custom } from 'viem';
import { mainnet } from 'viem/chains';
import Login from './components/Auth/Login';
import Dashboard from './components/Dashboard/Dashboard';
import Layout from './components/Layout/Layout';
import { UserContext } from './context/UserContext';
import { getStoredUser } from './services/authService';

// 创建查询客户端
const queryClient = new QueryClient();

const App: React.FC = () => {
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [walletClient, setWalletClient] = useState<any>(null);

  // 检查是否已登录
  useEffect(() => {
    const checkAuth = async () => {
      try {
        const storedUser = getStoredUser();
        if (storedUser) {
          setUser(storedUser);
        }
      } catch (error) {
        console.error('检查认证错误:', error);
      } finally {
        setLoading(false);
      }
    };

    checkAuth();
  }, []);

  // 连接钱包
  const connectWallet = async () => {
    try {
      if (!window.ethereum) {
        alert('请安装MetaMask!');
        return;
      }

      // 创建钱包客户端
      const client = createWalletClient({
        chain: mainnet,
        transport: custom(window.ethereum)
      });

      // 请求账户
      const [address] = await client.requestAddresses();
      
      setWalletClient(client);
      
      return {
        client,
        address
      };
    } catch (error) {
      console.error('连接钱包错误:', error);
      throw error;
    }
  };

  return (
    <QueryClientProvider client={queryClient}>
      <UserContext.Provider value={{ user, setUser, walletClient, setWalletClient, connectWallet }}>
        <Layout>
          {loading ? (
            <div className="flex justify-center items-center h-screen">
              <div className="animate-spin rounded-full h-16 w-16 border-t-2 border-b-2 border-blue-500"></div>
            </div>
          ) : user ? (
            <Dashboard />
          ) : (
            <Login />
          )}
        </Layout>
      </UserContext.Provider>
    </QueryClientProvider>
  );
};

export default App; 