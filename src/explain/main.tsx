import React from 'react';
import ReactDOM from 'react-dom/client';
import { MotionConfig } from 'motion/react';

import { ThemeProvider } from '@/components/theme-provider';

import { ExplainApp } from './ExplainCard';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ThemeProvider defaultTheme="dark" storageKey="ui-theme">
      <MotionConfig reducedMotion="user">
        <ExplainApp />
      </MotionConfig>
    </ThemeProvider>
  </React.StrictMode>
);
