import { foundry, sepolia } from 'wagmi/chains';

// 合约地址常量
interface ContractAddresses {
  [chainId: number]: {
    tokenAddress: `0x${string}`;
    tokenBankAddress: `0x${string}`;
    nftAddress: `0x${string}`;
    nftMarketAddress: `0x${string}`;
  };
}

// 合约地址配置
export const CONTRACT_ADDRESSES: ContractAddresses = {
  [foundry.id]: {
    // Foundry 本地网络地址
    tokenAddress: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
    tokenBankAddress: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
    nftAddress: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
    nftMarketAddress: '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707',
  },
  [sepolia.id]: {
    // Sepolia 测试网地址
    tokenAddress: '0xeed964A1676fdd399f359e768B6A13Af7573998c',
    tokenBankAddress: '0xe638FA8ea6e3cE4cE42F0903607630A96C34696C',
    nftAddress: '0x610178dA211FEF7D417bC0e6FeD39F05609AD788',
    nftMarketAddress: '0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0',
  },
};

// 获取当前链上的合约地址
export function getContractAddresses(chainId: number = foundry.id) {
  return CONTRACT_ADDRESSES[chainId] || CONTRACT_ADDRESSES[foundry.id];
} 