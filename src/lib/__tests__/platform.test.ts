import { afterEach, describe, expect, it, vi } from 'vitest';

/**
 * `isElectron` is a module-level constant, so each case re-imports the module
 * with a different window shape.
 */
async function importWith(keys: string[]) {
  vi.resetModules();
  for (const key of ['parley', 'ipcRenderer']) {
    delete (window as unknown as Record<string, unknown>)[key];
  }
  for (const key of keys) {
    (window as unknown as Record<string, unknown>)[key] = {};
  }
  return import('../platform');
}

afterEach(() => {
  for (const key of ['parley', 'ipcRenderer']) {
    delete (window as unknown as Record<string, unknown>)[key];
  }
});

describe('isElectron', () => {
  it('is true when the parley bridge is present', async () => {
    expect((await importWith(['parley'])).isElectron).toBe(true);
  });

  it('is false in a plain browser', async () => {
    expect((await importWith([])).isElectron).toBe(false);
  });

  it('does not depend on the removed generic ipcRenderer bridge', async () => {
    expect((await importWith(['ipcRenderer'])).isElectron).toBe(false);
  });
});
