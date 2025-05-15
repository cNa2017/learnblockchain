-- 创建数据库
CREATE DATABASE IF NOT EXISTS viem_test;
USE viem_test;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  address VARCHAR(42) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_address (address)
);

-- ERC20合约表
CREATE TABLE IF NOT EXISTS contracts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  address VARCHAR(42) NOT NULL UNIQUE,
  name VARCHAR(100),
  symbol VARCHAR(20),
  decimals INT DEFAULT 18,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_address (address)
);

-- 交易记录表
CREATE TABLE IF NOT EXISTS transactions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tx_hash VARCHAR(66) NOT NULL UNIQUE,
  contract_id INT NOT NULL,
  from_address VARCHAR(42) NOT NULL,
  to_address VARCHAR(42) NOT NULL,
  value VARCHAR(78) NOT NULL, -- 大整数存为字符串
  block_number BIGINT NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (contract_id) REFERENCES contracts(id),
  INDEX idx_from_address (from_address),
  INDEX idx_to_address (to_address),
  INDEX idx_contract_id (contract_id),
  INDEX idx_block_number (block_number)
);

-- 轮询日志表
CREATE TABLE IF NOT EXISTS polling_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  contract_id INT NOT NULL,
  status ENUM('pending', 'processing', 'completed', 'failed') NOT NULL,
  last_block_number BIGINT,
  message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (contract_id) REFERENCES contracts(id),
  INDEX idx_contract_id (contract_id),
  INDEX idx_status (status)
); 