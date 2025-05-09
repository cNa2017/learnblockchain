<template>
  <div class="balance-display">
    <div class="balance-card">
      <h3>ERC20 代币余额</h3>
      <p class="balance">{{ erc20Balance }} <span class="token-symbol">{{ tokenSymbol }}</span></p>
      <p v-if="loading" class="loading">加载中...</p>
    </div>
    
    <div class="balance-card">
      <h3>TokenBank 余额</h3>
      <p class="balance">{{ bankBalance }} <span class="token-symbol">{{ tokenSymbol }}</span></p>
      <p v-if="loading" class="loading">加载中...</p>
    </div>
    
    <button @click="refreshBalances" class="refresh-button" :disabled="loading || !walletConnected">
      刷新余额
    </button>
  </div>
</template>

<script>
import { getERC20Balance, getTokenBankBalance } from '../services/contractService';

export default {
  name: 'BalanceDisplay',
  props: {
    walletConnected: {
      type: Boolean,
      default: false
    },
    account: {
      type: String,
      default: ''
    }
  },
  data() {
    return {
      erc20Balance: '0',
      bankBalance: '0',
      loading: false,
      error: '',
      tokenSymbol: window.APP_CONFIG?.token?.symbol || 'TOKEN'
    };
  },
  watch: {
    account(newAccount) {
      if (newAccount) {
        this.refreshBalances();
      } else {
        this.resetBalances();
      }
    }
  },
  methods: {
    async refreshBalances() {
      if (!this.walletConnected) return;
      
      try {
        this.loading = true;
        this.error = '';
        console.log("this.account",this.account);
        // 获取ERC20余额
        this.erc20Balance = await getERC20Balance(this.account);
        
        // 获取TokenBank余额
        this.bankBalance = await getTokenBankBalance(this.account);
      } catch (error) {
        this.error = error.message || '获取余额失败';
        console.error('获取余额失败:', error);
      } finally {
        this.loading = false;
      }
    },
    resetBalances() {
      this.erc20Balance = '0';
      this.bankBalance = '0';
    }
  },
  mounted() {
    if (this.walletConnected && this.account) {
      this.refreshBalances();
    }
  }
};
</script>

<style scoped>
.balance-display {
  margin-bottom: 20px;
}

.balance-card {
  background-color: #ffffff;
  border-radius: 8px;
  padding: 15px;
  margin-bottom: 15px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.balance-card h3 {
  margin-top: 0;
  color: #333;
  font-size: 18px;
}

.balance {
  font-size: 24px;
  font-weight: bold;
  color: #0275d8;
  margin: 10px 0;
}

.token-symbol {
  font-size: 16px;
  color: #6c757d;
}

.loading {
  color: #6c757d;
  font-style: italic;
}

.refresh-button {
  background-color: #0275d8;
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 16px;
  transition: background-color 0.3s;
}

.refresh-button:hover:not(:disabled) {
  background-color: #025aa5;
}

.refresh-button:disabled {
  background-color: #6c757d;
  cursor: not-allowed;
}
</style>