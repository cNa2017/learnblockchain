<template>
  <div class="token-operations">
    <div class="operation-card">
      <h3>存入代币到TokenBank</h3>
      <div class="input-group">
        <input 
          type="number" 
          v-model="depositAmount" 
          placeholder="输入存款金额" 
          :disabled="!walletConnected || loading"
          step="0.01"
          min="0"
        />
        <button 
          @click="deposit" 
          :disabled="!walletConnected || loading || !isValidAmount(depositAmount)"
          class="action-button deposit-button"
        >
          <span v-if="loading && operationType === 'deposit'">
            <i class="loading-spinner"></i> 处理中
          </span>
          <span v-else>存入</span>
        </button>
      </div>
      <p v-if="depositError" class="error-message">{{ depositError }}</p>
    </div>
    
    <div class="operation-card">
      <h3>从TokenBank取出代币</h3>
      <div class="input-group">
        <input 
          type="number" 
          v-model="withdrawAmount" 
          placeholder="输入取款金额" 
          :disabled="!walletConnected || loading"
          step="0.01"
          min="0"
        />
        <button 
          @click="withdraw" 
          :disabled="!walletConnected || loading || !isValidAmount(withdrawAmount)"
          class="action-button withdraw-button"
        >
          <span v-if="loading && operationType === 'withdraw'">
            <i class="loading-spinner"></i> 处理中
          </span>
          <span v-else>取出</span>
        </button>
      </div>
      <p v-if="withdrawError" class="error-message">{{ withdrawError }}</p>
    </div>
    
    <div v-if="transactionStatus" class="transaction-status" :class="{ 'success': transactionStatus.success }">
      <p>{{ transactionStatus.message }}</p>
      <a v-if="transactionStatus.hash" :href="explorerUrl + '/tx/' + transactionStatus.hash" target="_blank" class="tx-link">
        查看交易
      </a>
    </div>
  </div>
</template>

<script>
import { depositToBank, withdrawFromBank, getERC20Balance, getTokenBankBalance } from '../services/contractService';

export default {
  name: 'TokenOperations',
  props: {
    walletConnected: {
      type: Boolean,
      default: false
    }
  },
  data() {
    return {
      depositAmount: '',
      withdrawAmount: '',
      loading: false,
      operationType: null, // 'deposit' 或 'withdraw'
      transactionStatus: null,
      depositError: '',
      withdrawError: '',
      explorerUrl: window.APP_CONFIG?.network?.explorerUrl || 'https://sepolia.etherscan.io',
      tokenSymbol: window.APP_CONFIG?.token?.symbol || 'TOKEN'
    };
  },
  methods: {
    isValidAmount(amount) {
      if (!amount) return false;
      const numAmount = parseFloat(amount);
      return !isNaN(numAmount) && numAmount > 0;
    },
    
    clearErrors() {
      this.depositError = '';
      this.withdrawError = '';
    },
    
    async validateDeposit() {
      try {
        if (!this.walletConnected) {
          this.depositError = '请先连接钱包';
          return false;
        }
        
        if (!this.isValidAmount(this.depositAmount)) {
          this.depositError = '请输入有效的存款金额';
          return false;
        }
        
        // 检查用户ERC20余额是否足够
        const balance = await getERC20Balance();
        if (parseFloat(balance) < parseFloat(this.depositAmount)) {
          this.depositError = `余额不足，当前余额: ${balance} ${this.tokenSymbol}`;
          return false;
        }
        
        return true;
      } catch (error) {
        this.depositError = `验证失败: ${error.message}`;
        return false;
      }
    },
    
    async validateWithdraw() {
      try {
        if (!this.walletConnected) {
          this.withdrawError = '请先连接钱包';
          return false;
        }
        
        if (!this.isValidAmount(this.withdrawAmount)) {
          this.withdrawError = '请输入有效的取款金额';
          return false;
        }
        
        // 检查用户在TokenBank中的余额是否足够
        const balance = await getTokenBankBalance();
        if (parseFloat(balance) < parseFloat(this.withdrawAmount)) {
          this.withdrawError = `余额不足，当前余额: ${balance} ${this.tokenSymbol}`;
          return false;
        }
        
        return true;
      } catch (error) {
        this.withdrawError = `验证失败: ${error.message}`;
        return false;
      }
    },
    
    async deposit() {
      this.clearErrors();
      
      // 验证存款操作
      const isValid = await this.validateDeposit();
      if (!isValid) return;
      
      try {
        this.loading = true;
        this.operationType = 'deposit';
        this.transactionStatus = { message: '存款交易处理中...', success: false };
        console.log('Deposit Amount:', this.depositAmount);
        const result = await depositToBank(this.depositAmount.toString());
        
        if (result.success) {
          this.transactionStatus = {
            message: `成功存入 ${this.depositAmount} ${this.tokenSymbol}`,
            success: true,
            hash: result.hash
          };
          this.depositAmount = '';
          this.$emit('transaction-completed');
        } else {
          this.depositError = result.error || '存款失败';
          this.transactionStatus = {
            message: `存款失败: ${result.error}`,
            success: false
          };
        }
      } catch (error) {
        this.depositError = error.message || '存款失败';
        this.transactionStatus = {
          message: `存款失败: ${error.message}`,
          success: false
        };
      } finally {
        this.loading = false;
        this.operationType = null;
      }
    },
    
    async withdraw() {
      this.clearErrors();
      
      // 验证取款操作
      const isValid = await this.validateWithdraw();
      if (!isValid) return;
      
      try {
        this.loading = true;
        this.operationType = 'withdraw';
        this.transactionStatus = { message: '取款交易处理中...', success: false };
        
        const result = await withdrawFromBank(this.withdrawAmount.toString());
        
        if (result.success) {
          this.transactionStatus = {
            message: `成功取出 ${this.withdrawAmount} ${this.tokenSymbol}`,
            success: true,
            hash: result.hash
          };
          this.withdrawAmount = '';
          this.$emit('transaction-completed');
        } else {
          this.withdrawError = result.error || '取款失败';
          this.transactionStatus = {
            message: `取款失败: ${result.error}`,
            success: false
          };
        }
      } catch (error) {
        this.withdrawError = error.message || '取款失败';
        this.transactionStatus = {
          message: `取款失败: ${error.message}`,
          success: false
        };
      } finally {
        this.loading = false;
        this.operationType = null;
      }
    }
  }
};
</script>

<style scoped>
.token-operations {
  margin-bottom: 20px;
}

.operation-card {
  background-color: #ffffff;
  border-radius: 8px;
  padding: 15px;
  margin-bottom: 15px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.operation-card h3 {
  margin-top: 0;
  color: #333;
  font-size: 18px;
}

.input-group {
  display: flex;
  margin-top: 10px;
}

.input-group input {
  flex: 1;
  padding: 10px;
  border: 1px solid #ced4da;
  border-radius: 4px 0 0 4px;
  font-size: 16px;
}

.input-group input:focus {
  outline: none;
  border-color: #80bdff;
  box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
}

.action-button {
  padding: 10px 20px;
  border: none;
  border-radius: 0 4px 4px 0;
  color: white;
  font-size: 16px;
  cursor: pointer;
  transition: background-color 0.3s;
  min-width: 100px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.deposit-button {
  background-color: #28a745;
}

.deposit-button:hover:not(:disabled) {
  background-color: #218838;
}

.withdraw-button {
  background-color: #dc3545;
}

.withdraw-button:hover:not(:disabled) {
  background-color: #c82333;
}

.action-button:disabled {
  background-color: #6c757d;
  cursor: not-allowed;
}

.loading-spinner {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-radius: 50%;
  border-top-color: #fff;
  animation: spin 1s ease-in-out infinite;
  margin-right: 8px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.transaction-status {
  margin-top: 20px;
  padding: 15px;
  border-radius: 8px;
  background-color: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
  transition: all 0.3s ease;
}

.transaction-status.success {
  background-color: #d4edda;
  color: #155724;
  border-color: #c3e6cb;
}

.tx-link {
  display: inline-block;
  margin-top: 10px;
  color: #0275d8;
  text-decoration: none;
}

.tx-link:hover {
  text-decoration: underline;
}

.error-message {
  color: #dc3545;
  font-size: 14px;
  margin-top: 8px;
  margin-bottom: 0;
}


.transaction-status.success {
  background-color: #d4edda;
  color: #155724;
}

.tx-link {
  display: inline-block;
  margin-top: 5px;
  color: #0275d8;
  text-decoration: none;
}

.tx-link:hover {
  text-decoration: underline;
}
</style>