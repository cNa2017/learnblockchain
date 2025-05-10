// 配置文件 - 部署应用前需要修改这些配置
window.APP_CONFIG = {
  // 合约地址配置
  contracts: {
    // TokenBank合约地址 - 需要替换为实际部署的合约地址
    tokenBank: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
    // ERC20代币合约地址 - 需要替换为实际部署的合约地址
    erc20: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
    // NFTMarket合约地址 - 需要替换为实际部署的合约地址
    nftMarket: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'
  },
  // 网络配置
  network: {
    // 使用的网络名称
    name: '本地anvil测试网',
    // 区块浏览器URL前缀
    explorerUrl: 'http://127.0.0.1:8545'
  },
  // 代币配置
  token: {
    // 代币符号
    symbol: 'MTK',
    // 代币小数位数
    decimals: 18
  }
};