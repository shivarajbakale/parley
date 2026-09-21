import React from 'react';
import ReactDOM from 'react-dom/client';

import { ThemeProvider } from '@/components/theme-provider';

import { Orb } from './Orb';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ThemeProvider defaultTheme="dark" storageKey="ui-theme">
      <Orb />
    </ThemeProvider>
  </React.StrictMode>
);
