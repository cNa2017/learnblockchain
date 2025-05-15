import React, { useContext } from 'react';
import { UserContext } from '../../context/UserContext';
import { logoutUser } from '../../services/authService';

type LayoutProps = {
  children: React.ReactNode;
};

const Layout: React.FC<LayoutProps> = ({ children }) => {
  const { user, setUser } = useContext(UserContext);

  const handleLogout = () => {
    logoutUser();
    setUser(null);
  };

  return (
    <div className="min-h-screen flex flex-col">
      {/* 顶部导航栏 */}
      <header className="bg-blue-600 text-white shadow">
        <div className="container mx-auto px-4 py-3 flex justify-between items-center">
          <h1 className="text-lg md:text-xl font-bold">ERC20交易浏览器</h1>
          
          {user && (
            <div className="flex items-center space-x-4">
              <div className="hidden md:block">
                <span className="text-sm">钱包地址: </span>
                <span className="font-mono text-xs md:text-sm">
                  {user.address.substring(0, 6)}...{user.address.substring(user.address.length - 4)}
                </span>
              </div>
              <button 
                onClick={handleLogout}
                className="bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded text-sm"
              >
                登出
              </button>
            </div>
          )}
        </div>
      </header>

      {/* 主要内容区域 */}
      <main className="flex-grow container mx-auto px-4 py-6">
        {children}
      </main>

      {/* 页脚 */}
      <footer className="bg-gray-800 text-white py-4">
        <div className="container mx-auto px-4 text-center text-sm">
          <p>ERC20交易浏览器 &copy; {new Date().getFullYear()}</p>
        </div>
      </footer>
    </div>
  );
};

export default Layout; 