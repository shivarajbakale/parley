import React from 'react';
import ReactDOM from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MotionConfig } from 'motion/react';

import { ThemeProvider } from '@/components/theme-provider';

import { SettingsApp } from './SettingsApp';

const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <ThemeProvider defaultTheme="dark" storageKey="ui-theme">
        <MotionConfig reducedMotion="user">
          <SettingsApp />
        </MotionConfig>
      </ThemeProvider>
    </QueryClientProvider>
  </React.StrictMode>
);
