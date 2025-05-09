<template>
  <div id="app">
    <div class="container">
      <h1 class="app-title">我的代币钱包</h1>
      <p class="app-description">管理ERC20代币与TokenBank合约交互</p>
      
      <WalletConnect 
        @wallet-connected="handleWalletConnected" 
        @wallet-disconnected="handleWalletDisconnected"
      />
      
      <div v-if="walletConnected" class="wallet-content">
        <BalanceDisplay 
          :walletConnected="walletConnected" 
          :account="account"
          ref="balanceDisplay"
        />
        
        <TokenOperations 
          :walletConnected="walletConnected"
          @transaction-completed="refreshBalances"
        />
      </div>
      
      <div v-else class="connect-prompt">
        <p>请连接钱包以使用应用功能</p>
      </div>
    </div>
  </div>
</template>

<script>
import WalletConnect from './components/WalletConnect.vue';
import BalanceDisplay from './components/BalanceDisplay.vue';
import TokenOperations from './components/TokenOperations.vue';

export default {
  name: 'App',
  components: {
    WalletConnect,
    BalanceDisplay,
    TokenOperations
  },
  data() {
    return {
      walletConnected: false,
      account: ''
    };
  },
  methods: {
    handleWalletConnected(account) {
      this.walletConnected = true;
      this.account = account;
    },
    handleWalletDisconnected() {
      this.walletConnected = false;
      this.account = '';
    },
    refreshBalances() {
      if (this.$refs.balanceDisplay) {
        this.$refs.balanceDisplay.refreshBalances();
      }
    }
  }
};
</script>

<style>
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 30px;
}

.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

.app-title {
  font-size: 28px;
  margin-bottom: 10px;
  color: #0275d8;
}

.app-description {
  font-size: 16px;
  color: #6c757d;
  margin-bottom: 30px;
}

.wallet-content {
  margin-top: 20px;
}

.connect-prompt {
  margin-top: 30px;
  padding: 20px;
  background-color: #f8f9fa;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.connect-prompt p {
  font-size: 18px;
  color: #6c757d;
}
</style>
