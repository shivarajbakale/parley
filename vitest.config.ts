import { defineConfig } from 'vitest/config';

// The engine is plain Node: no DOM, no renderer.
export default defineConfig({
  test: {
    environment: 'node',
    include: ['engine/**/*.test.ts', 'scripts/__tests__/**/*.test.ts'],
  },
});
