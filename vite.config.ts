import { defineConfig } from 'vite';
import path from 'node:path';
import electron from 'vite-plugin-electron/simple';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig(({ command }) => {
  // Only watch the main/preload processes during `vite` (dev server);
  // for `vite build` we produce a one-shot bundle so the command exits.
  const electronWatch = command === 'serve' ? {} : null;

  return {
  plugins: [
    react(),
    electron({
      main: {
        entry: 'electron/main.ts',
        onstart({ startup }) {
          // Only restart Electron when main process files change
          startup();
        },
        vite: {
          build: {
            // Watch main process files (dev only)
            watch: electronWatch,
            rollupOptions: {
              external: ['electron', 'uiohook-napi'],
            },
          },
        },
      },
      preload: {
        input: path.join(__dirname, 'electron/preload.ts'),
        onstart({ reload }) {
          // Reload preload scripts without restarting Electron
          reload();
        },
        vite: {
          build: {
            watch: electronWatch,
            rollupOptions: {
              external: ['electron'],
            },
          },
        },
      },
      renderer: process.env.NODE_ENV === 'test' ? undefined : {},
    }),
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 5174, // Changed from default 5173 to avoid conflict with React web app
    strictPort: true, // Fail if port is already in use
    host: true, // Listen on all addresses
    hmr: {
      overlay: true,
    },
  },
  preview: {
    port: 5174,
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    css: true,
  },
  };
});
