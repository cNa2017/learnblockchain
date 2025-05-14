'use client';

import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';
import { AppKitNetwork, foundry, sepolia } from '@reown/appkit/networks';
import { createAppKit } from '@reown/appkit/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactNode } from 'react';
import { WagmiProvider } from 'wagmi';


// 0. Setup queryClient
const queryClient = new QueryClient()

// 1. Get projectId from https://cloud.reown.com
const projectId = '6170addf649e3c6f6820f6288ad50e6c'

// 2. Create a metadata object - optional
const metadata = {
  name: 'cna-link',
  description: 'NFT市场与TokenBank应用',
  url: 'https://reown.com/appkit', // origin must match your domain & subdomain
  icons: ['https://assets.reown.com/reown-profile-pic.png']
}

// 3. Set the networks - 包含我们使用的foundry和sepolia网络
// 至少需要一个网络，后面跟着其他网络
const networks: [AppKitNetwork, ...AppKitNetwork[]] = [sepolia, foundry]
// const networks = [sepolia, foundry]

// 4. Create Wagmi Adapter
const wagmiAdapter = new WagmiAdapter({
  networks,
  projectId,
  ssr: true
});

// 5. Create modal
createAppKit({
  adapters: [wagmiAdapter],
  networks,
  projectId,
  metadata,
  features: {
    analytics: true // Optional - defaults to your Cloud configuration
  }
})

export function AppKitProvider({ children }: { children: ReactNode }) {
  return (
    <WagmiProvider config={wagmiAdapter.wagmiConfig}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  )
}
    