'use client';

import { AppKitProvider } from './appkit-demo/appkit-config';

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <AppKitProvider>
      {children}
    </AppKitProvider>
  );
} 