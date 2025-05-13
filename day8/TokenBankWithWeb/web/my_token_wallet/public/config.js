// 配置文件 - 部署应用前需要修改这些配置
window.APP_CONFIG = {
  // 合约地址配置
  contracts: {
    // TokenBank合约地址 - 需要替换为实际部署的合约地址
    tokenBank: '0xcDaF61d4e50f84DDC44b05B67d2283b875AD04fe',
    // ERC20代币合约地址 - 需要替换为实际部署的合约地址
    erc20: '0x0A8eBFD3C59169cDc3f3A17Ffd093BA5e26B848A',
    // NFTMarket合约地址 - 需要替换为实际部署的合约地址
    nftMarket: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'
  },
  // 网络配置
  network: {
    // 使用的网络名称
    name: '本地anvil测试网',
    // 区块浏览器URL前缀
    explorerUrl: 'https://sepolia.etherscan.io/'
  },
  // 代币配置
  token: {
    // 代币符号
    symbol: 'MTK',
    // 代币小数位数
    decimals: 18
  }
};