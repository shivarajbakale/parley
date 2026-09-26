import { describe, expect, it } from 'vitest';

import { buildAgentEnv } from '../env';

describe('buildAgentEnv', () => {
  it('carries the port and drops undefined values', () => {
    const env = buildAgentEnv({
      processEnv: { PATH: '/bin', UNSET: undefined },
      port: 4111,
      rewriteKey: null,
      packaged: false,
      execPath: '/Parley',
    });
    expect(env.PORT).toBe('4111');
    expect(env.PATH).toBe('/bin');
    expect('UNSET' in env).toBe(false);
    expect('MINIMAX_API_KEY' in env).toBe(false);
  });

  it('hands the stored MiniMax key to the child', () => {
    const env = buildAgentEnv({
      processEnv: {},
      port: 4111,
      rewriteKey: 'mm-key',
      packaged: false,
      execPath: '/Parley',
    });
    expect(env.MINIMAX_API_KEY).toBe('mm-key');
  });

  it('lets an explicit environment key win over the stored one', () => {
    const env = buildAgentEnv({
      processEnv: { MINIMAX_API_KEY: 'shell-key' },
      port: 4111,
      rewriteKey: 'mm-key',
      packaged: false,
      execPath: '/Parley',
    });
    expect(env.MINIMAX_API_KEY).toBe('shell-key');
  });

  it('marks Electron-as-Node and its path only when packaged', () => {
    const dev = buildAgentEnv({
      processEnv: {},
      port: 4111,
      rewriteKey: null,
      packaged: false,
      execPath: '/Parley',
    });
    expect('ELECTRON_RUN_AS_NODE' in dev).toBe(false);
    expect('PARLEY_NODE_BIN' in dev).toBe(false);
    const packaged = buildAgentEnv({
      processEnv: {},
      port: 4111,
      rewriteKey: null,
      packaged: true,
      execPath: '/Parley',
    });
    expect(packaged.ELECTRON_RUN_AS_NODE).toBe('1');
    expect(packaged.PARLEY_NODE_BIN).toBe('/Parley');
  });
});
