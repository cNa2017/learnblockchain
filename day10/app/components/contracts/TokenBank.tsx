'use client';

import { useCallback, useEffect, useState } from 'react';
import { formatEther, parseEther } from 'viem';
import {
  useAccount,
  useReadContract,
  useWaitForTransactionReceipt,
  useWriteContract
} from 'wagmi';
import ERC20_ABI from '../../contracts/ERC20.json';
import TOKEN_BANK_ABI from '../../contracts/tokenBank.json';

// 自定义钩子用于格式化地址
const useFormattedAddress = (address?: `0x${string}`) => {
  if (!address) return '';
  return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
};

// Token Bank 组件
export function TokenBank({ 
  tokenAddress, 
  bankAddress
}: { 
  tokenAddress: `0x${string}`,
  bankAddress: `0x${string}`
}) {
  const [depositAmount, setDepositAmount] = useState<string>('');
  const [withdrawAmount, setWithdrawAmount] = useState<string>('');
  // 添加客户端状态
  const [mounted, setMounted] = useState(false);
  // 添加交易类型状态
  const [txType, setTxType] = useState<'none' | 'approve' | 'deposit' | 'withdraw'>('none');
  
  const { address } = useAccount();
  const formattedAddress = useFormattedAddress(address);

  // 仅在客户端挂载后执行
  useEffect(() => {
    setMounted(true);
  }, []);

  // 获取用户 Token 余额
  const { data: tokenBalance, refetch: refetchTokenBalance } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  // 获取用户在 TokenBank 中存款余额 - 使用balances映射
  const { data: bankBalance, refetch: refetchBankBalance } = useReadContract({
    address: bankAddress,
    abi: TOKEN_BANK_ABI,
    functionName: 'balances',
    args: address ? [address] : undefined,
  });

  // 检查授权额度
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address && bankAddress ? [address, bankAddress] : undefined,
  });

  // 获取 Token 符号
  const { data: tokenSymbol } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'symbol',
  });

  // 获取 Token 小数位数
  const { data: tokenDecimals } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'decimals',
  });

  // 写入合约函数
  const { writeContract, data: txHash, isPending, reset: resetWriteContract } = useWriteContract();
  
  // 等待交易完成
  const { isLoading: isConfirming, isSuccess: isConfirmed } = 
    useWaitForTransactionReceipt({ 
      hash: txHash,
    });

  // 刷新所有数据
  const refreshAllData = useCallback(() => {
    refetchTokenBalance();
    refetchBankBalance();
    refetchAllowance();
  }, [refetchTokenBalance, refetchBankBalance, refetchAllowance]);

  // 执行存款操作
  const executeDeposit = useCallback(() => {
    if (!depositAmount || !address) return;
    
    try {
      setTxType('deposit');
      writeContract({
        address: bankAddress,
        abi: TOKEN_BANK_ABI,
        functionName: 'deposit',
        args: [parseEther(depositAmount)],
      });
    } catch (error) {
      console.error('存款失败:', error);
      setTxType('none');
    }
  }, [address, bankAddress, depositAmount, writeContract]);

  // 执行授权操作
  const executeApprove = useCallback(() => {
    if (!depositAmount || !address) return;
    
    try {
      setTxType('approve');
      writeContract({
        address: tokenAddress,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [bankAddress, parseEther(depositAmount)],
      });
    } catch (error) {
      console.error('授权失败:', error);
      setTxType('none');
    }
  }, [address, tokenAddress, bankAddress, depositAmount, writeContract]);

  // 存款处理函数 - 根据授权状态决定执行哪个操作
  const handleDeposit = useCallback(() => {
    if (!depositAmount || !address) return;
    
    const amountToDeposit = parseEther(depositAmount);
    const currentAllowance = allowance as bigint || BigInt(0);
    
    // 如果授权不足，先授权
    if (currentAllowance < amountToDeposit) {
      executeApprove();
    } else {
      // 如果已授权，直接存款
      executeDeposit();
    }
  }, [address, depositAmount, allowance, executeApprove, executeDeposit]);

  // 取款处理函数
  const handleWithdraw = useCallback(() => {
    if (!withdrawAmount || !address) return;
    
    try {
      setTxType('withdraw');
      writeContract({
        address: bankAddress,
        abi: TOKEN_BANK_ABI,
        functionName: 'withdraw',
        args: [parseEther(withdrawAmount)],
      });
    } catch (error) {
      console.error('取款失败:', error);
      setTxType('none');
    }
  }, [address, bankAddress, withdrawAmount, writeContract]);

  // 处理交易成功
  useEffect(() => {
    if (isConfirmed && txHash) {
      // 刷新数据
      refreshAllData();
      
      // 如果是授权成功，执行存款操作
      if (txType === 'approve') {
        // 添加短暂延迟确保状态已更新
        setTimeout(() => {
          executeDeposit();
        }, 500);
      } 
      // 如果是存款或取款成功，重置状态
      else if (txType === 'deposit' || txType === 'withdraw') {
        setDepositAmount('');
        setWithdrawAmount('');
        setTxType('none');
        resetWriteContract();
      }
    }
  }, [isConfirmed, txHash, txType, executeDeposit, refreshAllData, resetWriteContract]);

  // 格式化 Token 数量显示
  const formatTokenAmount = (amount: bigint | undefined): string => {
    if (!amount) return '0';
    return formatEther(amount);
  };

  // 检查取款金额是否超过存款余额
  const isWithdrawDisabled = (): boolean => {
    if (!withdrawAmount || !bankBalance) return true;
    try {
      return parseEther(withdrawAmount) > (bankBalance as bigint);
    } catch (error) {
      return true;
    }
  };

  // 如果尚未挂载，返回一个占位组件
  if (!mounted) {
    return (
      <div className="w-full max-w-md mx-auto p-6 bg-white rounded-lg shadow-md">
        <h2 className="text-2xl font-bold text-center mb-6">Token Bank</h2>
        <div className="text-center">
          <p className="mb-4">正在加载...</p>
        </div>
      </div>
    );
  }

  // 获取当前存款按钮文本
  const getDepositButtonText = () => {
    if (isPending || isConfirming) return '处理中...';
    
    // 检查是否需要授权
    if (!depositAmount) return '存款';
    
    const amountToDeposit = parseEther(depositAmount);
    const currentAllowance = allowance as bigint || BigInt(0);
    
    if (currentAllowance < amountToDeposit) {
      return '授权并存款';
    } else {
      return '存款';
    }
  };

  return (
    <div className="w-full max-w-md mx-auto p-6 bg-white rounded-lg shadow-md">
      <h2 className="text-2xl font-bold text-center mb-6">Token Bank</h2>
      
      {address ? (
        <>
          <div className="mb-4">
            <p className="text-sm text-gray-600">Connected Account</p>
            <p className="font-mono">{formattedAddress}</p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
            <div className="bg-gray-100 p-4 rounded-md">
              <p className="text-sm text-gray-600">Token Balance</p>
              <p className="text-xl font-semibold">
                {formatTokenAmount(tokenBalance as bigint)} {typeof tokenSymbol === 'string' ? tokenSymbol : ''}
              </p>
            </div>
            
            <div className="bg-blue-50 p-4 rounded-md">
              <p className="text-sm text-gray-600">Your Deposits</p>
              <p className="text-xl font-semibold">
                {formatTokenAmount(bankBalance as bigint)} {typeof tokenSymbol === 'string' ? tokenSymbol : ''}
              </p>
            </div>
          </div>
          
          <div className="mb-6">
            <h3 className="text-lg font-semibold mb-2">Deposit</h3>
            <div className="flex space-x-2">
              <input
                type="number"
                className="flex-1 p-2 border rounded"
                placeholder="Amount"
                value={depositAmount}
                onChange={(e) => setDepositAmount(e.target.value)}
                disabled={isPending || isConfirming}
              />
              <button
                className="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600 disabled:bg-gray-300"
                onClick={handleDeposit}
                disabled={isPending || isConfirming || !depositAmount}
              >
                {getDepositButtonText()}
              </button>
            </div>
          </div>
          
          <div>
            <h3 className="text-lg font-semibold mb-2">Withdraw</h3>
            <div className="flex space-x-2">
              <input
                type="number"
                className="flex-1 p-2 border rounded"
                placeholder="Amount"
                value={withdrawAmount}
                onChange={(e) => setWithdrawAmount(e.target.value)}
                disabled={isPending || isConfirming}
              />
              <button
                className="bg-red-500 text-white px-4 py-2 rounded hover:bg-red-600 disabled:bg-gray-300"
                onClick={handleWithdraw}
                disabled={isPending || isConfirming || !withdrawAmount || isWithdrawDisabled()}
              >
                {isPending || isConfirming ? '处理中...' : '取款'}
              </button>
            </div>
          </div>
        </>
      ) : (
        <div className="text-center">
          <p className="mb-4">请连接钱包使用Token Bank功能</p>
        </div>
      )}
    </div>
  );
} 