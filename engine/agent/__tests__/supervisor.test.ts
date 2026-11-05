import { describe, expect, it, vi } from 'vitest';

import {
  createSupervisor,
  type HealthReading,
  type SupervisorChild,
  type SupervisorConfig,
} from '../supervisor';

const HEALTHY: HealthReading = {
  ok: true,
  message: 'Agent works',
  mcpServers: [{ name: 'Files', tools: 12 }],
};
const REFUSED: HealthReading = { ok: false, message: 'refused on :4111', mcpServers: [] };

function config(over: Partial<SupervisorConfig> = {}): SupervisorConfig {
  return {
    autoStart: true,
    managed: true,
    spawn: {
      command: 'mastra',
      args: ['dev'],
      cwd: '/proj',
      env: {},
      description: 'mastra dev in /proj',
    },
    port: 4111,
    pollMs: 5,
    readyTimeoutMs: 40,
    backoffMs: [5, 5, 5],
    killGraceMs: 5,
    ...over,
  };
}

function fakeChild() {
  const listeners: Record<string, ((...args: unknown[]) => void)[]> = {};
  const dataListeners: ((chunk: string) => void)[] = [];
  const child = {
    killed: false,
    exitCode: null as number | null,
    killSignals: [] as (string | undefined)[],
    on(event: string, cb: (...args: unknown[]) => void) {
      (listeners[event] ??= []).push(cb);
    },
    emit(event: string, ...args: unknown[]) {
      for (const cb of listeners[event] ?? []) cb(...args);
    },
    sendStderr(line: string) {
      for (const cb of dataListeners) cb(line);
    },
    kill(signal?: string) {
      child.killed = true;
      child.killSignals.push(signal);
    },
    stderr: {
      on(_event: string, cb: (chunk: string) => void) {
        dataListeners.push(cb);
      },
    },
  };
  return child as unknown as SupervisorChild & {
    emit(event: string, ...args: unknown[]): void;
    sendStderr(line: string): void;
    killed: boolean;
    killSignals: (string | undefined)[];
  };
}

function deps(over: Record<string, unknown> = {}) {
  const children: ReturnType<typeof fakeChild>[] = [];
  return {
    children,
    getConfig: () => config(),
    spawn: vi.fn((_command: string, _args: string[], _opts: unknown) => {
      const child = fakeChild();
      children.push(child);
      return child;
    }),
    checkHealth: vi.fn(async () => HEALTHY),
    onLog: vi.fn(),
    ...over,
  };
}

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

describe('agent supervisor', () => {
  it('attaches when the port already answers, without spawning', async () => {
    const d = deps();
    const supervisor = createSupervisor(d);
    supervisor.start();
    await sleep(20);
    expect(d.spawn).not.toHaveBeenCalled();
    expect(supervisor.status()).toMatchObject({
      state: 'online',
      managed: false,
      mcpServers: [{ name: 'Files', tools: 12 }],
    });
  });

  it('stays offline with cause when auto-start is off and nothing answers', async () => {
    const d = deps({
      getConfig: () => config({ autoStart: false }),
      checkHealth: vi.fn(async () => REFUSED),
    });
    const supervisor = createSupervisor(d);
    supervisor.start();
    await sleep(20);
    expect(d.spawn).not.toHaveBeenCalled();
    expect(supervisor.status()).toMatchObject({ state: 'offline', managed: false });
    expect(supervisor.status().message).toMatch(/auto-start is off/i);
  });

  it('spawns and comes online once health passes', async () => {
    const checkHealth = vi.fn(async () => REFUSED);
    const d = deps({ checkHealth });
    const supervisor = createSupervisor(d);
    supervisor.start();
    await sleep(10);
    expect(d.spawn).toHaveBeenCalledTimes(1);
    expect(d.spawn).toHaveBeenCalledWith(
      'mastra',
      ['dev'],
      expect.objectContaining({ cwd: '/proj' })
    );
    expect(supervisor.status().state).toBe('starting');
    checkHealth.mockResolvedValue(HEALTHY);
    await sleep(20);
    expect(supervisor.status()).toMatchObject({ state: 'online', managed: true, attempt: 0 });
  });

  it('gives up after the ready timeout and kills the child', async () => {
    const d = deps({ checkHealth: vi.fn(async () => REFUSED) });
    const supervisor = createSupervisor(d);
    supervisor.start();
    await sleep(80);
    expect(supervisor.status()).toMatchObject({ state: 'offline', managed: true });
    expect(supervisor.status().message).toMatch(/did not answer/);
    expect(d.children).toHaveLength(1);
    expect(d.children[0].killed).toBe(true);
    expect(d.spawn).toHaveBeenCalledTimes(1);
  });

  it('names a spawn that fails outright, without retrying', async () => {
    const failure = Object.assign(new Error('spawn ENOENT'), { code: 'ENOENT' });
    const d = deps({
      checkHealth: vi.fn(async () => REFUSED),
      spawn: vi.fn(() => {
        throw failure;
      }),
    });
    const supervisor = createSupervisor(d);
    supervisor.start();
    await sleep(20);
    expect(supervisor.status().message).toMatch(/mastra dev in \/proj.*ENOENT/);
    expect(d.spawn).toHaveBeenCalledTimes(1);
  });

  it('goes straight to offline when the port is held by a stranger', async () => {
    const d = deps({ checkHealth: vi.fn(async () => REFUSED) });
    const supervisor = createSupervisor(d);
    supervisor.start();
    await sleep(10);
    d.children[0].sendStderr('Error: listen EADDRINUSE: address already in use :::4111');
    d.children[0].emit('exit', 1);
    await sleep(20);
    expect(supervisor.status()).toMatchObject({ state: 'offline' });
    expect(supervisor.status().message).toMatch(/port busy.*:4111/);
    expect(d.spawn).toHaveBeenCalledTimes(1);
  });

  it('restarts a crashed server three times, then reports the last error', async () => {
    const checkHealth = vi.fn(async () => REFUSED);
    const d = deps({ checkHealth });
    const supervisor = createSupervisor(d);
    supervisor.start();
    await sleep(10);
    checkHealth.mockResolvedValue(HEALTHY);
    await sleep(20);
    expect(supervisor.status()).toMatchObject({ state: 'online', managed: true });

    for (let crash = 0; crash < 4; crash += 1) {
      const child = d.children[d.children.length - 1];
      child.sendStderr(`boom ${crash}`);
      child.emit('exit', 1);
      await sleep(30);
    }
    expect(d.spawn).toHaveBeenCalledTimes(4);
    expect(supervisor.status()).toMatchObject({ state: 'offline', managed: true });
    expect(supervisor.status().message).toMatch(/keeps crashing.*boom 3/);
  });

  it('forgives old crashes after steady health', async () => {
    const checkHealth = vi.fn(async () => REFUSED);
    const d = deps({
      checkHealth,
      getConfig: () => config({ steadyMs: 200 }),
    });
    const supervisor = createSupervisor(d);
    supervisor.start();
    await sleep(10);
    checkHealth.mockResolvedValue(HEALTHY);
    await sleep(20);
    d.children[0].emit('exit', 1);
    await sleep(30);
    expect(d.spawn).toHaveBeenCalledTimes(2);
    await sleep(250);
    for (let crash = 0; crash < 4; crash += 1) {
      d.children[d.children.length - 1].emit('exit', 1);
      await sleep(30);
    }
    expect(d.spawn).toHaveBeenCalledTimes(5);
    expect(supervisor.status().state).toBe('offline');
  });

  it('stops the child and clears back to offline', async () => {
    const d = deps({ checkHealth: vi.fn(async () => REFUSED) });
    const supervisor = createSupervisor(d);
    supervisor.start();
    await sleep(10);
    expect(d.children).toHaveLength(1);
    supervisor.stop();
    expect(d.children[0].killed).toBe(true);
    expect(supervisor.status()).toMatchObject({ state: 'offline', message: '', attempt: 0 });
    await sleep(30);
    expect(d.spawn).toHaveBeenCalledTimes(1);
  });

  it('refresh returns the live reading for settings:get', async () => {
    const checkHealth = vi.fn(async () => HEALTHY);
    const d = deps({ checkHealth });
    const supervisor = createSupervisor(d);
    supervisor.start();
    await sleep(20);
    await expect(supervisor.refresh()).resolves.toMatchObject({
      online: true,
      managed: false,
      mcpServers: [{ name: 'Files', tools: 12 }],
    });
    checkHealth.mockResolvedValue(REFUSED);
    await expect(supervisor.refresh()).resolves.toMatchObject({ online: false });
    expect(supervisor.status().state).toBe('offline');
  });
});
