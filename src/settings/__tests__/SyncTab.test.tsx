import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactElement } from 'react';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import {
  DEFAULT_SETTINGS,
  OFFLINE_AGENT_SUMMARY,
  type ParleyApi,
  type SettingsView,
} from '../../../electron/types';
import { SyncTab } from '../SyncTab';
import { useSettings } from '../use-parley';

const settledView: SettingsView = {
  ...DEFAULT_SETTINGS,
  tourSeen: true,
  onboardingComplete: true,
  hasApiKey: true,
  hasRewriteKey: true,
  wordsDictated: 0,
  hasSyncToken: false,
  syncLastAt: 0,
  syncLastError: '',
  agent: OFFLINE_AGENT_SUMMARY,
};

/** Holds the settings query open, as SettingsApp does in the real window. */
function SettingsProbe() {
  useSettings();
  return null;
}

function renderWithProviders(ui: ReactElement) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <ThemeProvider>
        <SettingsProbe />
        {ui}
      </ThemeProvider>
    </QueryClientProvider>
  );
}

describe('SyncTab', () => {
  beforeEach(() => {
    window.parley = {
      getSettings: vi.fn(async () => settledView),
      signInSync: vi.fn(async () => ({ ok: true, message: 'Signed in' })),
      signOutSync: vi.fn(async () => settledView),
      syncNow: vi.fn(async () => ({ ok: true, pushed: 0, pulled: 0, message: 'Synced 0 up, 0 down', at: 1 })),
    } as unknown as ParleyApi;
  });

  it('signed out: shows the email form and no Sync now', () => {
    renderWithProviders(<SyncTab settings={{ ...settledView, hasSyncToken: false }} onChange={() => {}} />);
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /sync now/i })).toBeNull();
  });

  it('synced: shows the account, last sync time, and Sync now calls the bridge', async () => {
    window.parley.syncNow = vi.fn().mockResolvedValue({ ok: true, pushed: 1, pulled: 0, message: 'Synced 1 up, 0 down', at: 1 });
    renderWithProviders(
      <SyncTab settings={{ ...settledView, hasSyncToken: true, syncEmail: 'me@example.com', syncLastAt: Date.now(), syncLastError: '' }} onChange={() => {}} />,
    );
    expect(screen.getByText('me@example.com')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /sync now/i }));
    expect(window.parley.syncNow).toHaveBeenCalled();
    expect(await screen.findByText(/synced 1 up/i)).toBeInTheDocument();
  });

  it('error: the last failure stays visible with dictation reassurance', () => {
    renderWithProviders(
      <SyncTab settings={{ ...settledView, hasSyncToken: true, syncLastAt: 5, syncLastError: 'fetch failed' }} onChange={() => {}} />,
    );
    expect(screen.getByRole('alert')).toHaveTextContent('fetch failed');
    expect(screen.getByText(/dictation keeps working/i)).toBeInTheDocument();
  });

  it('a never-synced account reads Never', () => {
    renderWithProviders(
      <SyncTab settings={{ ...settledView, hasSyncToken: true, syncEmail: 'me@example.com', syncLastAt: 0 }} onChange={() => {}} />,
    );
    expect(screen.getByText('Never')).toBeInTheDocument();
  });

  it('signs in with a valid email only, and shows a refused sign-in', async () => {
    const user = userEvent.setup();
    const signInSync = vi.fn(async () => ({ ok: false, message: 'Could not reach the sync server' }));
    window.parley.signInSync = signInSync;
    renderWithProviders(<SyncTab settings={settledView} onChange={() => {}} />);
    const field = screen.getByLabelText(/email/i);
    await user.type(field, 'not an email');
    await user.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(await screen.findByText('Enter a valid email')).toBeInTheDocument();
    expect(signInSync).not.toHaveBeenCalled();
    await user.clear(field);
    await user.type(field, 'me@example.com');
    await user.click(screen.getByRole('button', { name: 'Sign in' }));
    await waitFor(() => expect(signInSync).toHaveBeenCalledWith('me@example.com'));
    expect(await screen.findByText('Could not reach the sync server')).toBeInTheDocument();
  });

  it('signs out through the bridge', async () => {
    const user = userEvent.setup();
    renderWithProviders(
      <SyncTab settings={{ ...settledView, hasSyncToken: true, syncEmail: 'me@example.com' }} onChange={() => {}} />,
    );
    await user.click(screen.getByRole('button', { name: 'Sign out' }));
    expect(window.parley.signOutSync).toHaveBeenCalledTimes(1);
  });

  it('saves the sync URL on blur, and only an http(s) one', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    renderWithProviders(<SyncTab settings={settledView} onChange={onChange} />);
    const field = screen.getByLabelText('Sync URL');
    await user.clear(field);
    await user.type(field, 'nope');
    await user.tab();
    expect(await screen.findByText('Use an http(s) URL')).toBeInTheDocument();
    expect(onChange).not.toHaveBeenCalled();
    await user.clear(field);
    await user.type(field, 'https://sync.example.com');
    await user.tab();
    expect(onChange).toHaveBeenCalledWith({ syncUrl: 'https://sync.example.com' });
  });

  it('refetches settings when the window regains focus, since a scheduled sync has no push', async () => {
    renderWithProviders(<SyncTab settings={{ ...settledView, hasSyncToken: true }} onChange={() => {}} />);
    await waitFor(() => expect(window.parley.getSettings).toHaveBeenCalledTimes(1));
    act(() => {
      window.dispatchEvent(new Event('focus'));
    });
    await waitFor(() => expect(window.parley.getSettings).toHaveBeenCalledTimes(2));
  });
});
