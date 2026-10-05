import { describe, expect, it } from 'vitest';
import { stdioLaunch } from '../src/mastra/parley/mcp.js';

describe('stdioLaunch', () => {
  it('runs a bare node command through Electron-as-Node when a binary is given', () => {
    expect(stdioLaunch({ command: 'node', args: ['notes.mjs'], env: { A: '1' } }, '/App/Parley')).toEqual({
      command: '/App/Parley',
      args: ['notes.mjs'],
      env: { A: '1', ELECTRON_RUN_AS_NODE: '1' },
    });
  });

  it('leaves node alone without a binary, and any other command untouched', () => {
    expect(stdioLaunch({ command: 'node', args: ['x.mjs'] }, undefined)).toEqual({ command: 'node', args: ['x.mjs'] });
    expect(stdioLaunch({ command: 'npx', args: ['-y', 'cal'] }, '/App/Parley')).toEqual({ command: 'npx', args: ['-y', 'cal'] });
  });
});
