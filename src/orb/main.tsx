import React from 'react';
import ReactDOM from 'react-dom/client';
import { MotionConfig } from 'motion/react';

import { ThemeProvider } from '@/components/theme-provider';

import { Orb } from './Orb';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ThemeProvider defaultTheme="dark" storageKey="ui-theme">
      <MotionConfig reducedMotion="user">
        <Orb />
      </MotionConfig>
    </ThemeProvider>
  </React.StrictMode>
);
