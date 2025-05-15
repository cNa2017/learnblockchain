import React, { useContext, useState } from 'react';
import { UserContext } from '../../context/UserContext';
import { loginUser } from '../../services/authService';

const Login: React.FC = () => {
  const { connectWallet, setUser } = useContext(UserContext);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleLogin = async () => {
    try {
      setLoading(true);
      setError(null);

      // 请求连接钱包
      const walletData = await connectWallet();
      
      if (!walletData) {
        throw new Error('无法连接钱包');
      }
      
      // 登录到后端
      const user = await loginUser(walletData.address);
      setUser(user);
      
    } catch (err: any) {
      console.error('登录错误:', err);
      setError(err.message || '登录失败，请重试');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-md mx-auto my-16 p-6 bg-white rounded-lg shadow-lg">
      <h2 className="text-2xl font-bold text-center mb-6">连接钱包登录</h2>
      
      {error && (
        <div className="mb-4 p-3 bg-red-100 text-red-700 rounded">
          {error}
        </div>
      )}
      
      <p className="text-gray-600 mb-6 text-center">
        请连接您的以太坊钱包以访问ERC20交易数据跟踪系统
      </p>
      
      <button
        onClick={handleLogin}
        disabled={loading}
        className="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 disabled:opacity-50"
      >
        {loading ? (
          <span className="flex justify-center items-center">
            <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            连接中...
          </span>
        ) : (
          '连接MetaMask钱包'
        )}
      </button>
      
      <div className="mt-6 text-center text-sm text-gray-500">
        <p>需要MetaMask浏览器扩展</p>
        <p className="mt-2">
          没有MetaMask？ 
          <a 
            href="https://metamask.io/download/" 
            target="_blank" 
            rel="noopener noreferrer"
            className="text-blue-600 hover:underline"
          >
            点击安装
          </a>
        </p>
      </div>
    </div>
  );
};

export default Login; 