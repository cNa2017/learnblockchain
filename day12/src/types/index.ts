export interface Address {
  id?: number;
  address: string;
  createdAt?: string;
}

export interface ERC20Contract {
  id: number;
  address: string;
  symbol?: string;
  name?: string;
  decimals?: number;
  firstAddedBy?: string;
  createdAt: string;
}

export interface Transaction {
  id: number;
  transactionHash: string;
  contractId: number;
  contractAddress?: string;
  contractSymbol?: string;
  fromAddress: string;
  toAddress: string;
  value: string;
  blockNumber: bigint;
  timestamp: string;
  gasUsed?: bigint;
  gasPrice?: string;
  status?: number;
  createdAt: string;
}

export interface PollingLog {
  id: number;
  contractId: number;
  contractAddress?: string;
  fromBlock: bigint;
  toBlock: bigint;
  transactionsFound: number;
  status: 'success' | 'failed';
  errorMessage?: string;
  startedAt: string;
  completedAt: string;
}
