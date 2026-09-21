import { describe, expect, it, vi } from 'vitest';

import { createInjector } from '../injector';

function setup(sendPaste = vi.fn()) {
  const log: string[] = [];
  const injector = createInjector({
    snapshot: () => {
      log.push('snapshot');
      return 'old clipboard';
    },
    restore: (s) => log.push(`restore:${s}`),
    writeText: (t) => log.push(`write:${t}`),
    sendPaste: () => {
      log.push('paste');
      sendPaste();
    },
    delay: async (ms) => {
      log.push(`delay:${ms}`);
    },
  });
  return { injector, log };
}

describe('injector', () => {
  it('snapshots, writes, pastes, then restores the clipboard', async () => {
    const { injector, log } = setup();
    await injector.paste('hello');
    expect(log).toEqual([
      'snapshot',
      'write:hello',
      'delay:50',
      'paste',
      'delay:200',
      'restore:old clipboard',
    ]);
  });

  it('restores the clipboard even when the paste keystroke throws', async () => {
    const { injector, log } = setup(
      vi.fn(() => {
        throw new Error('no accessibility');
      })
    );
    await expect(injector.paste('hello')).rejects.toThrow('no accessibility');
    expect(log.at(-1)).toBe('restore:old clipboard');
  });
});
