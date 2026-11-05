import { describe, expect, it, vi } from 'vitest';

import { createInjector, ERASE_BATCH, ERASE_SETTLE_MS } from '../injector';

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
    sendBackspace: () => log.push('backspace'),
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

  it('copies just the selection, never selecting anything, and gives the clipboard back', async () => {
    const { injector, log } = setup(vi.fn(), 'picked words');
    await expect(injector.copySelection()).resolves.toBe('picked words');
    expect(log).toEqual([
      'snapshot',
      'write:',
      'copy',
      'delay:150',
      'read',
      'restore:old clipboard',
    ]);
  });

  it('erases with backspaces, pausing every batch so a terminal keeps up', async () => {
    const { injector, log } = setup();
    await injector.erase(ERASE_BATCH + 2);
    expect(log.filter((entry) => entry === 'backspace')).toHaveLength(ERASE_BATCH + 2);
    expect(log.indexOf(`delay:${ERASE_SETTLE_MS}`)).toBe(ERASE_BATCH);
    expect(log.at(-1)).toBe(`delay:${ERASE_SETTLE_MS}`);
  });

  it('sends nothing when there is nothing to erase', async () => {
    const { injector, log } = setup();
    await injector.erase(0);
    expect(log).toEqual([]);
  });
});
