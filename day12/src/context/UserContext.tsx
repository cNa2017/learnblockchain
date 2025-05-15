import React, { createContext } from 'react';

type UserContextType = {
  user: any;
  setUser: React.Dispatch<React.SetStateAction<any>>;
  walletClient: any;
  setWalletClient: React.Dispatch<React.SetStateAction<any>>;
  connectWallet: () => Promise<{ client: any; address: string } | undefined>;
};

export const UserContext = createContext<UserContextType>({
  user: null,
  setUser: () => {},
  walletClient: null,
  setWalletClient: () => {},
  connectWallet: async () => undefined,
}); 