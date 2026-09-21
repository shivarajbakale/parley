import React from 'react';
import ReactDOM from 'react-dom/client';

import { ThemeProvider } from '@/components/theme-provider';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ThemeProvider defaultTheme="dark" storageKey="ui-theme">
      <span />
    </ThemeProvider>
  </React.StrictMode>
);
