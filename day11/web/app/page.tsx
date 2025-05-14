'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import {
  useAccount,
  useBalance,
  useChainId,
  useChains
} from 'wagmi';
import { AppKitWallet, TokenBank } from './components';
import { getContractAddresses } from './constants/contracts';

export default function Home() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const chains = useChains();
  const currentChain = chains.find(chain => chain.id === chainId);
  // 添加客户端状态
  const [mounted, setMounted] = useState(false);

  // 仅在客户端挂载后执行
  useEffect(() => {
    setMounted(true);
  }, []);

  // 使用 useBalance 获取余额
  const { data: balance } = useBalance({
    address,
  });

  // 获取当前链对应的合约地址
  const { tokenAddress, tokenBankAddress } = getContractAddresses(chainId);

  // 服务器端渲染或未挂载时的占位内容
  if (!mounted) {
    return (
      <div className="min-h-screen flex flex-col items-center p-8">
        <header className="w-full max-w-4xl flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold">Token Bank</h1>
          <div className="w-32 h-10"></div>
        </header>
        
        <main className="w-full max-w-4xl">
          <div className="bg-white p-6 rounded-lg shadow-lg">
            <div className="text-center py-20">
              <h2 className="text-2xl font-bold mb-4">欢迎使用 Token Bank</h2>
              <p className="text-gray-600 mb-8">正在加载...</p>
            </div>
          </div>
        </main>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col items-center p-8">
      <header className="w-full max-w-4xl flex justify-between items-center mb-8">
        <div className="flex items-center gap-8">
          <h1 className="text-3xl font-bold">Token Bank</h1>
          <Link 
            href="/nft-market" 
            className="text-blue-500 hover:text-blue-700 font-medium"
          >
            NFT 市场
          </Link>
        </div>
        <AppKitWallet />
      </header>
      
      <main className="w-full max-w-4xl">
        <div className="bg-white p-6 rounded-lg shadow-lg">
          {isConnected ? (
            <div className="space-y-8">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <p className="text-gray-600">钱包地址:</p>
                  <p className="font-mono break-all text-sm">{address}</p>
                </div>
                <div>
                  <p className="text-gray-600">当前网络:</p>
                  <p className="font-mono">
                    {currentChain?.name || '未知网络'} (Chain ID: {chainId})
                  </p>
                </div>
                <div>
                  <p className="text-gray-600">ETH 余额:</p>
                  <p className="font-mono">
                    {balance?.formatted || '0'} {balance?.symbol}
                  </p>
                </div>
              </div>
              
              <div className="border-t pt-8">
                <TokenBank 
                  tokenAddress={tokenAddress}
                  bankAddress={tokenBankAddress}
                />
              </div>
            </div>
          ) : (
            <div className="text-center py-20">
              <h2 className="text-2xl font-bold mb-4">欢迎使用 Token Bank</h2>
              <p className="text-gray-600 mb-8">请连接钱包以继续使用</p>
              <div className="flex justify-center">
                <AppKitWallet />
              </div>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
