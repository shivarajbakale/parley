module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 2021,
    sourceType: 'module'
  },
  extends: ['eslint:recommended', 'prettier'],
  plugins: ['@typescript-eslint'],
  env: {
    node: true,
    es2021: true
  },
  ignorePatterns: ['dist/', 'node_modules/', '*.js'],
  rules: {
    '@typescript-eslint/explicit-module-boundary-types': 'off',
    '@typescript-eslint/no-explicit-any': 'warn',
    // TypeScript-aware unused-vars as a warning (the base rule misfires on type
    // imports and Express's required trailing `next`); prefix with `_` to opt out.
    '@typescript-eslint/no-unused-vars': [
      'warn',
      { argsIgnorePattern: '^_', varsIgnorePattern: '^_', args: 'none' }
    ],
    'no-unused-vars': 'off',
    // The TS compiler already reports undefined identifiers; the base rule
    // false-positives on globals like `globalThis`.
    'no-undef': 'off',
    'no-console': 'off'
  }
};
