import { render, screen, waitFor } from '@testing-library/react';
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
    getSettings: vi.fn().mockResolvedValue({ ...DEFAULT_SETTINGS, hasApiKey: true }),
    updateSettings: vi
      .fn()
      .mockImplementation(async (patch) => ({ ...DEFAULT_SETTINGS, ...patch, hasApiKey: true })),
    setApiKey: vi.fn().mockResolvedValue({ ok: true, message: 'Key works' }),
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

describe('SettingsApp', () => {
  beforeEach(() => vi.clearAllMocks());

  it('shows no setup banner when everything is in place', async () => {
    mount(mockApi());
    expect(await screen.findByText('Gesture')).toBeInTheDocument();
    expect(screen.queryByText('Finish setup')).not.toBeInTheDocument();
  });

  it('shows the setup banner and a Grant button when Accessibility is missing', async () => {
    const api = mockApi({
      getPermissions: vi.fn().mockResolvedValue({ microphone: true, accessibility: false }),
    });
    mount(api);
    expect(await screen.findByText('Finish setup')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Grant Accessibility' }));
    expect(api.requestPermission).toHaveBeenCalledWith('accessibility');
  });

  it('shows the setup banner when no API key is stored', async () => {
    mount(
      mockApi({
        getSettings: vi.fn().mockResolvedValue({ ...DEFAULT_SETTINGS, hasApiKey: false }),
      })
    );
    expect(await screen.findByText('Finish setup')).toBeInTheDocument();
  });

  it('saves a toggle at once', async () => {
    const api = mockApi();
    mount(api);
    await userEvent.click(await screen.findByRole('switch', { name: 'Play a tick when recording stops' }));
    expect(api.updateSettings).toHaveBeenCalledWith({ tickSound: false });
  });

  it('tests and saves the API key, and shows the result', async () => {
    const api = mockApi();
    mount(api);
    await userEvent.type(await screen.findByLabelText('Groq API key'), 'gsk_abc');
    await userEvent.click(screen.getByRole('button', { name: 'Test and save' }));
    await waitFor(() => expect(api.setApiKey).toHaveBeenCalledWith('gsk_abc'));
    expect(await screen.findByText('Key works')).toBeInTheDocument();
  });

  it('rejects an empty key without calling main', async () => {
    const api = mockApi();
    mount(api);
    await userEvent.click(await screen.findByRole('button', { name: 'Test and save' }));
    expect(await screen.findByText('Enter your Groq API key')).toBeInTheDocument();
    expect(api.setApiKey).not.toHaveBeenCalled();
  });
});
