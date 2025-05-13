'use client';

import { useAppKit } from '@reown/appkit/react';
import { useEffect, useState } from 'react';
import { useAccount, useDisconnect } from 'wagmi';

export function AppKitWallet() {
  const { address, isConnected } = useAccount();
  const { disconnect } = useDisconnect();
  const appKit = useAppKit();
  const [mounted, setMounted] = useState(false);

  // 仅在客户端挂载后执行
  useEffect(() => {
    setMounted(true);
  }, []);

  // 格式化地址显示
  const formatAddress = (address: string): string => {
    return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
  };

  // 如果尚未挂载，返回一个占位按钮
  if (!mounted) {
    return (
      <button
        className="bg-blue-500 text-white font-medium py-2 px-4 rounded"
      >
        连接钱包
      </button>
    );
  }

  if (isConnected && address) {
    return (
      <div className="flex items-center gap-2">
        <span className="text-sm font-mono">{formatAddress(address)}</span>
        <button
          onClick={() => disconnect()}
          className="bg-red-500 hover:bg-red-600 text-white font-medium py-2 px-4 rounded text-sm"
        >
          断开连接
        </button>
      </div>
    );
  }

  return (
    <button
      onClick={() => appKit.open()}
      className="bg-blue-500 hover:bg-blue-600 text-white font-medium py-2 px-4 rounded"
    >
      连接钱包
    </button>
  );
} 