import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import { DEFAULT_SETTINGS, type ParleyApi } from '../../../electron/types';
import { SettingsApp } from '../SettingsApp';

function mockApi(overrides: Partial<ParleyApi> = {}): ParleyApi {
  return {
    onOrbPhase: () => () => {},
    sendAudio: vi.fn(),
    getSettings: vi.fn().mockResolvedValue({ ...DEFAULT_SETTINGS, hasApiKey: true, hasRewriteKey: true }),
    updateSettings: vi
      .fn()
      .mockImplementation(async (patch) => ({ ...DEFAULT_SETTINGS, ...patch, hasApiKey: true, hasRewriteKey: true })),
    setApiKey: vi.fn().mockResolvedValue({ ok: true, message: 'Key works' }),
    setRewriteKey: vi.fn().mockResolvedValue({ ok: true, message: 'Key works' }),
    getPermissions: vi.fn().mockResolvedValue({ microphone: true, accessibility: true }),
    requestPermission: vi.fn().mockResolvedValue({ microphone: true, accessibility: true }),
    ...overrides,
  };
}

function mount(api: ParleyApi) {
  window.parley = api;
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <ThemeProvider defaultTheme="dark" storageKey="test-color-scheme">
        <SettingsApp />
      </ThemeProvider>
    </QueryClientProvider>
  );
}

describe('SettingsShell tab persistence', () => {
  beforeEach(() => vi.clearAllMocks());

  it('keeps a half-typed API key when switching tabs away and back', async () => {
    mount(mockApi());

    await userEvent.click(await screen.findByRole('tab', { name: 'Setup' }));
    const keyInput = await screen.findByLabelText('Groq API key');
    await userEvent.type(keyInput, 'gsk_half-typed');
    expect(keyInput).toHaveValue('gsk_half-typed');

    await userEvent.click(await screen.findByRole('tab', { name: 'General' }));

    await userEvent.click(await screen.findByRole('tab', { name: 'Setup' }));
    const keyInputAgain = await screen.findByLabelText('Groq API key');
    expect(keyInputAgain).toHaveValue('gsk_half-typed');
  });

  it('every tab resolves aria-controls to a panel present in the DOM', async () => {
    mount(mockApi());

    for (const name of ['Setup', 'Gesture', 'General']) {
      const tab = await screen.findByRole('tab', { name });
      const controls = tab.getAttribute('aria-controls');
      expect(controls).toBeTruthy();
      const panel = controls ? document.getElementById(controls) : null;
      expect(panel).toBeInTheDocument();
    }
  });
});
