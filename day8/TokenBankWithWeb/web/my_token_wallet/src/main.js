import Vue from 'vue'
import App from './App.vue'
// 导入事件监听服务
import { startEventListening } from './services/eventService'

// 从config.js获取合约地址
window.CONTRACT_ADDRESSES = {
  TOKEN_BANK: window.APP_CONFIG?.contracts?.tokenBank || '0x0000000000000000000000000000000000000000',
  ERC20: window.APP_CONFIG?.contracts?.erc20 || '0x0000000000000000000000000000000000000000',
  NFT_MARKET: window.APP_CONFIG?.contracts?.nftMarket || '0x0000000000000000000000000000000000000000'
};

// 检查是否安装了MetaMask
if (typeof window.ethereum === 'undefined') {
  alert('请安装MetaMask钱包插件以使用本应用');
}

// 初始化NFT事件监听
const stopEventListening = startEventListening();

// 在应用关闭时停止监听
window.addEventListener('beforeunload', () => {
  if (stopEventListening) {
    stopEventListening();
    console.log('应用关闭，已停止NFT事件监听');
  }
});

Vue.config.productionTip = false

new Vue({
  render: h => h(App),
}).$mount('#app')
