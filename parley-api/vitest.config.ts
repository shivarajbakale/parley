import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['test/**/*.test.ts'],
    // e2e tests that need a live database opt in by checking RUN_DB_TESTS.
    // The default suite (health, validation, error envelope) needs no DB.
    pool: 'forks',
  },
});
