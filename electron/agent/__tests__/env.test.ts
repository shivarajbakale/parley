import { describe, expect, it } from 'vitest';

import { buildAgentEnv, SERVER_KEY_PLACEHOLDER } from '../env';

const base = { port: 4111, serverUrl: 'http://localhost:3100', packaged: false, execPath: '/Parley' };

describe('buildAgentEnv', () => {
  it('carries the port and drops undefined values', () => {
    const env = buildAgentEnv({ ...base, processEnv: { PATH: '/bin', UNSET: undefined } });
    expect(env.PORT).toBe('4111');
    expect(env.PATH).toBe('/bin');
    expect('UNSET' in env).toBe(false);
  });

  it('points the agent model at the Parley server, which holds the MiniMax key', () => {
    const env = buildAgentEnv({ ...base, processEnv: {}, serverUrl: 'http://localhost:3100/' });
    expect(env.MINIMAX_BASE_URL).toBe('http://localhost:3100/api/providers/minimax/anthropic/v1');
    expect(env.MINIMAX_API_KEY).toBe(SERVER_KEY_PLACEHOLDER);
  });

  it('lets an exported key win and talk to MiniMax directly', () => {
    const env = buildAgentEnv({ ...base, processEnv: { MINIMAX_API_KEY: 'shell-key' } });
    expect(env.MINIMAX_API_KEY).toBe('shell-key');
    expect('MINIMAX_BASE_URL' in env).toBe(false);
  });

  it('marks Electron-as-Node and its path only when packaged', () => {
    const dev = buildAgentEnv({ ...base, processEnv: {} });
    expect('ELECTRON_RUN_AS_NODE' in dev).toBe(false);
    expect('PARLEY_NODE_BIN' in dev).toBe(false);
    const packaged = buildAgentEnv({ ...base, processEnv: {}, packaged: true });
    expect(packaged.ELECTRON_RUN_AS_NODE).toBe('1');
    expect(packaged.PARLEY_NODE_BIN).toBe('/Parley');
  });
});
