import { describe, expect, it, vi } from 'vitest';

import { trayMenuTemplate } from '../tray';

const actions = () => ({ copyLast: vi.fn(), openSettings: vi.fn(), quit: vi.fn() });

describe('tray menu', () => {
  it('shows the status line and disables Copy last transcript when there is none', () => {
    const items = trayMenuTemplate({ ready: true, lastTranscript: null }, actions());
    expect(items[0]).toMatchObject({ label: 'Parley is ready', enabled: false });
    expect(items.find((i) => i.label === 'Copy last transcript')).toMatchObject({ enabled: false });
  });

  it('says setup is needed when not ready', () => {
    const items = trayMenuTemplate({ ready: false, lastTranscript: null }, actions());
    expect(items[0].label).toBe('Setup needed — open Settings');
  });

  it('wires the actions', () => {
    const a = actions();
    const items = trayMenuTemplate({ ready: true, lastTranscript: 'hello' }, a);
    const click = (label: string) => items.find((i) => i.label === label)?.click?.();
    click('Copy last transcript');
    click('Settings…');
    click('Quit Parley');
    expect(a.copyLast).toHaveBeenCalled();
    expect(a.openSettings).toHaveBeenCalled();
    expect(a.quit).toHaveBeenCalled();
  });
});
