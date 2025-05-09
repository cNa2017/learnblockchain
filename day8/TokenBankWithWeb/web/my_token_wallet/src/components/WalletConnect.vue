<template>
  <div class="wallet-connect">
    <div v-if="!isConnected" class="connect-section">
      <button @click="connectWallet" class="connect-button">
        连接钱包
      </button>
      <p v-if="error" class="error-message">{{ error }}</p>
    </div>
    <div v-else class="account-info">
      <p class="account-address">
        <span>当前账户:</span>
        <span class="address">{{ formatAddress(account) }}</span>
      </p>
    </div>
  </div>
</template>

<script>
import { connectWallet } from '../services/contractService';

export default {
  name: 'WalletConnect',
  data() {
    return {
      isConnected: false,
      account: '',
      error: ''
    };
  },
  methods: {
    async connectWallet() {
      try {
        this.error = '';
        const result = await connectWallet();
        if (result.success) {
          this.isConnected = true;
          this.account = result.account;
          this.$emit('wallet-connected', result.account);
        } else {
          this.error = result.error || '连接钱包失败';
        }
      } catch (error) {
        this.error = error.message || '连接钱包失败';
      }
    },
    formatAddress(address) {
      if (!address) return '';
      return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
    }
  },
  mounted() {
    // 检查是否已经连接
    if (window.ethereum && window.ethereum.selectedAddress) {
      this.isConnected = true;
      this.account = window.ethereum.selectedAddress;
      this.$emit('wallet-connected', this.account);
    }

    // 监听账户变化
    if (window.ethereum) {
      window.ethereum.on('accountsChanged', (accounts) => {
        if (accounts.length === 0) {
          this.isConnected = false;
          this.account = '';
          this.$emit('wallet-disconnected');
        } else {
          this.account = accounts[0];
          this.isConnected = true;
          this.$emit('wallet-connected', accounts[0]);
        }
      });
    }
  }
};
</script>

<style scoped>
.wallet-connect {
  margin-bottom: 20px;
  padding: 15px;
  border-radius: 8px;
  background-color: #f8f9fa;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.connect-button {
  background-color: #4CAF50;
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 16px;
  transition: background-color 0.3s;
}

.connect-button:hover {
  background-color: #45a049;
}

.error-message {
  color: #d9534f;
  margin-top: 10px;
}

.account-info {
  display: flex;
  align-items: center;
  justify-content: center;
}

.account-address {
  font-size: 16px;
  margin: 0;
}

.account-address .address {
  font-weight: bold;
  margin-left: 5px;
  color: #0275d8;
}
</style>