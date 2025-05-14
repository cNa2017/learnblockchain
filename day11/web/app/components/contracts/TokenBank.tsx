'use client';

import { useCallback, useEffect, useState } from 'react';
import { formatEther, parseEther } from 'viem';
import {
  useAccount,
  useChainId,
  useReadContract,
  useSignTypedData,
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
// 声明全局Window接口扩展
declare global {
  interface Window {
    signatureDeadline?: bigint;
  }
}

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
  const [txType, setTxType] = useState<'none' | 'approve' | 'deposit' | 'withdraw' | 'permitDeposit'>('none');
  
  const { address } = useAccount();
  const formattedAddress = useFormattedAddress(address);
  const chainId = useChainId();

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

  // 获取用户 nonce 值
  const { data: nonce } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'nonces',
    args: address ? [address] : undefined,
  });

  // 获取 DOMAIN_SEPARATOR
  const { data: domainSeparator } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'DOMAIN_SEPARATOR',
  });

  // 获取 Token 名称
  const { data: tokenName } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'name',
  });

  // 签名类型数据
  const { signTypedData, data: signature, isPending: isSignPending, reset: resetSignature } = useSignTypedData();

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

  // 处理签名存款
  const handleSignDeposit = useCallback(async () => {
    if (!depositAmount || !address || !tokenName) return;
    
    try {
      // 存储deadline到组件状态中，确保签名和提交使用相同的值
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1小时后过期
      // 将deadline存储到window对象中，以便在executePermitDeposit中使用
      window.signatureDeadline = deadline;
      
      console.log('签名使用的deadline:', deadline.toString());
      
      const domain = {
        name: tokenName as string,
        version: '1',
        chainId,
        verifyingContract: tokenAddress,
      };

      const types = {
        Permit: [
          { name: 'owner', type: 'address' },
          { name: 'spender', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
          { name: 'deadline', type: 'uint256' },
        ],
      };

      const message = {
        owner: address,
        spender: bankAddress,
        value: parseEther(depositAmount),
        nonce: nonce as bigint,
        deadline,
      };

      console.log('签名消息:', message);

      await signTypedData({
        domain,
        types,
        primaryType: 'Permit',
        message,
      });
    } catch (error) {
      console.error('签名失败:', error);
    }
  }, [address, bankAddress, tokenAddress, depositAmount, nonce, signTypedData, tokenName, chainId]);
  


  // 提交签名存款
  const executePermitDeposit = useCallback(() => {
    if (!depositAmount || !address || !signature) return;
    console.log('执行签名存款--------------------------------');
    try {
      // 解析签名
      const signatureBytes = signature as `0x${string}`;
      console.log('原始签名:', signatureBytes);
      
      // 正确解析EIP-712签名
      // r和s是32字节的十六进制字符串，v是一个单字节值
      const r = `0x${signatureBytes.slice(2, 66)}` as `0x${string}`;
      const s = `0x${signatureBytes.slice(66, 130)}` as `0x${string}`;
      // 修正v值的解析方式 - 确保符合EIP-712标准
      // 在某些情况下，v值可能需要调整
      let v = parseInt(signatureBytes.slice(130, 132), 16);
      
      // 如果v值是0或1，需要加上27以符合以太坊标准
      // 如果v值已经是27或28，则保持不变
      if (v < 27) {
        v += 27;
      }
      
      console.log('解析后的签名参数:', { r, s, v });
      
      // 使用与签名时相同的deadline
      const deadline = window.signatureDeadline || BigInt(Math.floor(Date.now() / 1000) + 3600);
      console.log('提交使用的deadline:', deadline.toString());
      
      setTxType('permitDeposit');
      writeContract({
        address: bankAddress,
        abi: TOKEN_BANK_ABI,
        functionName: 'permitDeposit',
        args: [
          parseEther(depositAmount),
          deadline,
          v,
          r,
          s
        ],
      });
    } catch (error) {
      console.error('签名存款失败:', error);
      setTxType('none');
    }
  }, [address, bankAddress, depositAmount, signature, writeContract]);


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
      else if (txType === 'deposit' || txType === 'withdraw' || txType === 'permitDeposit') {
        setDepositAmount('');
        setWithdrawAmount('');
        setTxType('none');
        resetWriteContract();
        resetSignature();
        
        // 清除签名deadline
        if (window.signatureDeadline) {
          delete window.signatureDeadline;
        }
      }
    }
  }, [isConfirmed, txHash, txType, executeDeposit, refreshAllData, resetWriteContract, resetSignature]);

  // 签名成功后执行permitDeposit
  useEffect(() => {
    if (signature && !isPending && !isSignPending && txType === 'none') {
      executePermitDeposit();
    }
  }, [signature, isPending, isSignPending, txType, executePermitDeposit]);
  
  // 组件卸载时清理全局状态
  useEffect(() => {
    return () => {
      // 清除window对象上的deadline
      if (window.signatureDeadline) {
        delete window.signatureDeadline;
      }
    };
  }, []);

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
            <div className="flex space-x-2 mb-2">
              <input
                type="number"
                className="flex-1 p-2 border rounded"
                placeholder="Amount"
                value={depositAmount}
                onChange={(e) => setDepositAmount(e.target.value)}
                disabled={isPending || isConfirming || isSignPending}
              />
              <button
                className="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600 disabled:bg-gray-300"
                onClick={handleDeposit}
                disabled={isPending || isConfirming || isSignPending || !depositAmount}
              >
                {getDepositButtonText()}
              </button>
            </div>
            
            <button
              className="w-full bg-purple-500 text-white px-4 py-2 rounded hover:bg-purple-600 disabled:bg-gray-300"
              onClick={handleSignDeposit}
              disabled={isPending || isConfirming || isSignPending || !depositAmount}
            >
              {isSignPending ? '签名中...' : isPending || isConfirming ? '处理中...' : '签名存款'}
            </button>
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
                disabled={isPending || isConfirming || isSignPending}
              />
              <button
                className="bg-red-500 text-white px-4 py-2 rounded hover:bg-red-600 disabled:bg-gray-300"
                onClick={handleWithdraw}
                disabled={isPending || isConfirming || isSignPending || !withdrawAmount || isWithdrawDisabled()}
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