import React from 'react';
import ReactDOM from 'react-dom/client';
import { RouterProvider } from '@tanstack/react-router';
import { QueryClientProvider } from '@tanstack/react-query';
import { HotkeysProvider } from '@tanstack/react-hotkeys';
import router from './router/router';
import { ThemeProvider } from './components/theme-provider';
import { ErrorBoundary } from './components/ErrorBoundary';
import { queryClient } from './lib/queryClient';

/**
 * Enable MSW (Mock Service Worker) in development.
 * Set VITE_ENABLE_MOCKING=true in .env to run with mock data and no backend.
 */
async function enableMocking() {
  if (import.meta.env.DEV && import.meta.env.VITE_ENABLE_MOCKING === 'true') {
    const { worker } = await import('./mocks/browser');
    return worker.start({ onUnhandledRequest: 'bypass' });
  }
}

enableMocking().then(() => {
  ReactDOM.createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <ErrorBoundary>
        <QueryClientProvider client={queryClient}>
          <ThemeProvider defaultTheme="dark" storageKey="ui-theme">
            {/* `HotkeysProvider` is not what makes `useHotkey` work — registrations
                go to a module-level `HotkeyManager` either way. It is the one
                place that sets the defaults they all inherit, which is why it is
                mounted even though nothing would throw without it. */}
            <HotkeysProvider>
              <RouterProvider router={router} />
            </HotkeysProvider>
          </ThemeProvider>
        </QueryClientProvider>
      </ErrorBoundary>
    </React.StrictMode>
  );
});
