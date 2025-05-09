// 配置文件 - 部署应用前需要修改这些配置
window.APP_CONFIG = {
  // 合约地址配置
  contracts: {
    // TokenBank合约地址 - 需要替换为实际部署的合约地址
    tokenBank: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
    // ERC20代币合约地址 - 需要替换为实际部署的合约地址
    erc20: '0x5FbDB2315678afecb367f032d93F642f64180aa3'
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