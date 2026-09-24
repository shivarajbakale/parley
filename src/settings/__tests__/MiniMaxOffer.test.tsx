import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import {
  DEFAULT_SETTINGS,
  type ParleyApi,
  type SessionBlockedReason,
  type SettingsView,
} from '../../../electron/types';
import { SettingsApp } from '../SettingsApp';

/** A settled user (onboarding done) with no MiniMax key, as on a first edit gesture. */
function mount(pending: SessionBlockedReason | null = null) {
  let settings: SettingsView = {
    ...DEFAULT_SETTINGS,
    tourSeen: true,
    onboardingComplete: true,
    hasApiKey: true,
    hasRewriteKey: false,
    wordsDictated: 0,
  };
  let push: ((reason: SessionBlockedReason) => void) | null = null;
  const api: ParleyApi = {
    onOrbPhase: () => () => {},
    sendAudio: vi.fn(),
    getSettings: vi.fn(async () => settings),
    updateSettings: vi.fn(async patch => (settings = { ...settings, ...patch })),
    setApiKey: vi.fn(async () => ({ ok: true, message: 'Key works' })),
    setDeepgramKey: vi.fn(async () => ({ ok: true, message: 'Key works' })),
    setTranscriptionProvider: vi.fn(async transcriptionProvider => ({ ...settings, transcriptionProvider })),
    setRewriteKey: vi.fn(async () => {
      settings = { ...settings, hasRewriteKey: true };
      return { ok: true, message: 'Key works' };
    }),
    getPermissions: vi.fn(async () => ({ microphone: true, accessibility: true })),
    requestPermission: vi.fn(async () => ({ microphone: true, accessibility: true })),
    onExplain: () => () => {},
    reportExplainHeight: vi.fn(),
    copyExplain: vi.fn(),
    dismissExplain: vi.fn(),
    onSessionBlocked: vi.fn(listener => {
      push = listener;
      return () => {};
    }),
    takeBlockedReason: vi.fn(async () => pending),
  };
  window.parley = api;
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  render(
    <QueryClientProvider client={client}>
      <ThemeProvider defaultTheme="dark" storageKey="test-color-scheme">
        <SettingsApp />
      </ThemeProvider>
    </QueryClientProvider>
  );
  return { api, push: (reason: SessionBlockedReason) => act(() => push?.(reason)) };
}

const TITLE = 'Voice edit and Explain need MiniMax';

describe('MiniMax first-use offer', () => {
  it('stays closed on a normal open', async () => {
    const { api } = mount();
    await screen.findByRole('tab', { name: 'Gesture' });
    await waitFor(() => expect(api.takeBlockedReason).toHaveBeenCalled());
    expect(screen.queryByRole('dialog', { name: TITLE })).not.toBeInTheDocument();
  });

  it('opens when the refused gesture is what opened the window', async () => {
    mount('rewriteKey');
    expect(await screen.findByRole('dialog', { name: TITLE })).toBeInTheDocument();
  });

  it('opens on a live refusal while the window is up', async () => {
    const { push } = mount();
    await screen.findByRole('tab', { name: 'Gesture' });
    push('rewriteKey');
    expect(await screen.findByRole('dialog', { name: TITLE })).toBeInTheDocument();
  });

  it('does not open for the other refusals', async () => {
    const { push } = mount();
    await screen.findByRole('tab', { name: 'Gesture' });
    push('apiKey');
    expect(screen.queryByRole('dialog', { name: TITLE })).not.toBeInTheDocument();
  });

  it('stores a key and says to try again', async () => {
    const { api } = mount('rewriteKey');
    const dialog = await screen.findByRole('dialog', { name: TITLE });
    await userEvent.type(await screen.findByLabelText('MiniMax API key'), 'mm_key');
    await userEvent.click(screen.getByRole('button', { name: 'Test and save MiniMax key' }));
    expect(api.setRewriteKey).toHaveBeenCalledWith('mm_key');
    expect(await screen.findByText('Try the gesture again.')).toBeInTheDocument();
    expect(dialog).toBeInTheDocument();
  });
});
