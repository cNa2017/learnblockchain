<template>
  <div class="nft-event-log">
    <div class="log-header">
      <h2>NFT交易日志</h2>
      <div class="log-controls">
        <button @click="startListening" :disabled="isListening" class="control-button start-button">
          开始监听
        </button>
        <button @click="stopListening" :disabled="!isListening" class="control-button stop-button">
          停止监听
        </button>
        <button @click="clearLogs" class="control-button clear-button">
          清除日志
        </button>
      </div>
    </div>
    
    <div class="log-status" :class="{ 'listening': isListening }">
      <span v-if="isListening">正在监听NFT交易事件...</span>
      <span v-else>未监听NFT交易事件</span>
    </div>
    
    <div class="log-container" ref="logContainer">
      <div v-if="logs.length === 0" class="no-logs">
        暂无交易日志
      </div>
      <div v-else class="log-list">
        <div v-for="(log, index) in logs" :key="index" class="log-item" :class="log.type.toLowerCase()">
          <div class="log-time">{{ log.timestamp }}</div>
          <div class="log-type">{{ getEventTypeText(log.type) }}</div>
          <div class="log-details">
            <template v-if="log.type === 'NFTListed'">
              <p>卖家: {{ formatAddress(log.details.seller) }}</p>
              <p>Token ID: {{ log.details.tokenId }}</p>
              <p>价格: {{ log.details.price }} ETH</p>
            </template>
            <template v-else-if="log.type === 'NFTSold'">
              <p>买家: {{ formatAddress(log.details.buyer) }}</p>
              <p>卖家: {{ formatAddress(log.details.seller) }}</p>
              <p>Token ID: {{ log.details.tokenId }}</p>
              <p>价格: {{ log.details.price }} ETH</p>
            </template>
            <template v-else-if="log.type === 'TokensReceived'">
              <p>操作者: {{ formatAddress(log.details.operator) }}</p>
              <p>发送方: {{ formatAddress(log.details.from) }}</p>
              <p>接收方: {{ formatAddress(log.details.to) }}</p>
              <p>Token ID: {{ log.details.tokenId }}</p>
              <p>数量: {{ log.details.amount }}</p>
            </template>
          </div>
          <div class="log-tx">
            <a :href="`${explorerUrl}/tx/${log.transactionHash}`" target="_blank" class="tx-link">
              查看交易
            </a>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { startEventListening, getEventLogs, clearEventLogs } from '../services/eventService';

export default {
  name: 'NFTEventLog',
  data() {
    return {
      logs: [],
      isListening: false,
      unWatchFn: null,
      explorerUrl: window.APP_CONFIG.network.explorerUrl || 'http://localhost:8545',
      refreshInterval: null
    };
  },
  methods: {
    startListening() {
      if (this.isListening) return;
      
      this.unWatchFn = startEventListening();
      this.isListening = true;
      
      // 定期刷新日志
      this.refreshInterval = setInterval(() => {
        this.refreshLogs();
      }, 2000);
    },
    stopListening() {
      if (!this.isListening) return;
      
      if (this.unWatchFn) {
        this.unWatchFn();
        this.unWatchFn = null;
      }
      
      this.isListening = false;
      
      if (this.refreshInterval) {
        clearInterval(this.refreshInterval);
        this.refreshInterval = null;
      }
    },
    clearLogs() {
      clearEventLogs();
      this.logs = [];
    },
    refreshLogs() {
      this.logs = getEventLogs(50); // 获取最新的50条日志
    },
    formatAddress(address) {
      if (!address) return '';
      return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
    },
    getEventTypeText(type) {
      const typeMap = {
        'NFTListed': 'NFT上架',
        'NFTSold': 'NFT售出',
        'TokensReceived': '代币接收'
      };
      return typeMap[type] || type;
    },
    scrollToBottom() {
      if (this.$refs.logContainer) {
        this.$refs.logContainer.scrollTop = this.$refs.logContainer.scrollHeight;
      }
    }
  },
  mounted() {
    // 初始加载日志
    this.refreshLogs();
    
    // 如果页面刷新前已经在监听，则自动恢复监听状态
    if (window._eventListeningActive) {
      this.isListening = true;
      this.unWatchFn = window._eventListeningUnwatch;
      
      // 定期刷新日志
      this.refreshInterval = setInterval(() => {
        this.refreshLogs();
      }, 2000);
    }
  },
  beforeDestroy() {
    // 组件销毁前停止监听
    this.stopListening();
  },
  watch: {
    logs() {
      // 日志更新时滚动到底部
      this.$nextTick(() => {
        this.scrollToBottom();
      });
    }
  }
};
</script>

<style scoped>
.nft-event-log {
  width: 100%;
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
  background-color: #f8f9fa;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

.log-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
}

.log-header h2 {
  margin: 0;
  color: #e74c3c;
  font-size: 1.5rem;
}

.log-controls {
  display: flex;
  gap: 10px;
}

.control-button {
  padding: 8px 12px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-weight: bold;
  transition: background-color 0.3s;
}

.start-button {
  background-color: #2ecc71;
  color: white;
}

.start-button:hover:not(:disabled) {
  background-color: #27ae60;
}

.stop-button {
  background-color: #e74c3c;
  color: white;
}

.stop-button:hover:not(:disabled) {
  background-color: #c0392b;
}

.clear-button {
  background-color: #3498db;
  color: white;
}

.clear-button:hover {
  background-color: #2980b9;
}

.control-button:disabled {
  background-color: #95a5a6;
  cursor: not-allowed;
}

.log-status {
  padding: 8px 12px;
  margin-bottom: 15px;
  background-color: #ecf0f1;
  border-radius: 4px;
  text-align: center;
  font-weight: bold;
  color: #7f8c8d;
}

.log-status.listening {
  background-color: #2ecc71;
  color: white;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0% {
    opacity: 1;
  }
  50% {
    opacity: 0.8;
  }
  100% {
    opacity: 1;
  }
}

.log-container {
  height: 400px;
  overflow-y: auto;
  border: 1px solid #ddd;
  border-radius: 4px;
  background-color: white;
}

.no-logs {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100%;
  color: #95a5a6;
  font-style: italic;
}

.log-list {
  padding: 10px;
}

.log-item {
  margin-bottom: 10px;
  padding: 10px;
  border-radius: 4px;
  border-left: 4px solid #3498db;
  background-color: #f8f9fa;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.log-item.nftlisted {
  border-left-color: #f39c12;
}

.log-item.nftsold {
  border-left-color: #2ecc71;
}

.log-item.tokensreceived {
  border-left-color: #9b59b6;
}

.log-time {
  font-size: 0.8rem;
  color: #7f8c8d;
  margin-bottom: 5px;
}

.log-type {
  font-weight: bold;
  margin-bottom: 5px;
  color: #2c3e50;
}

.log-details {
  margin-bottom: 5px;
  font-size: 0.9rem;
}

.log-details p {
  margin: 3px 0;
}

.log-tx {
  text-align: right;
}

.tx-link {
  font-size: 0.8rem;
  color: #3498db;
  text-decoration: none;
}

.tx-link:hover {
  text-decoration: underline;
}
</style>