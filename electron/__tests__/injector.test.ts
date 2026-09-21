import { describe, expect, it, vi } from 'vitest';

import { createInjector } from '../injector';

function setup(sendPaste = vi.fn(), copied = 'field text') {
  const log: string[] = [];
  const injector = createInjector({
    snapshot: () => {
      log.push('snapshot');
      return 'old clipboard';
    },
    restore: (s) => log.push(`restore:${s}`),
    writeText: (t) => log.push(`write:${t}`),
    readText: () => {
      log.push('read');
      return copied;
    },
    sendPaste: () => {
      log.push('paste');
      sendPaste();
    },
    sendCopy: () => log.push('copy'),
    sendSelectAll: () => log.push('selectAll'),
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

  it('selects the whole field before pasting when asked to replace it', async () => {
    const { injector, log } = setup();
    await injector.paste('hello', { selectAll: true });
    expect(log).toEqual([
      'snapshot',
      'write:hello',
      'delay:50',
      'selectAll',
      'delay:50',
      'paste',
      'delay:200',
      'restore:old clipboard',
    ]);
  });

  it('copies the whole field and gives the clipboard back', async () => {
    const { injector, log } = setup();
    await expect(injector.copyAll()).resolves.toBe('field text');
    expect(log).toEqual([
      'snapshot',
      'write:',
      'selectAll',
      'delay:50',
      'copy',
      'delay:150',
      'read',
      'restore:old clipboard',
    ]);
  });
});
