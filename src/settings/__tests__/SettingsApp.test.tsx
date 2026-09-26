import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';
import { toast } from '@/lib/notify';

import {
  DEFAULT_SETTINGS,
  OFFLINE_AGENT_SUMMARY,
  type ParleyApi,
} from '../../../electron/types';
import { SettingsApp } from '../SettingsApp';

function mockApi(overrides: Partial<ParleyApi> = {}): ParleyApi {
  return {
    onOrbPhase: () => () => {},
    sendAudio: vi.fn(),
    getSettings: vi.fn().mockResolvedValue({
      ...DEFAULT_SETTINGS,
      tourSeen: true,
      onboardingComplete: true,
      hasApiKey: true,
      hasRewriteKey: true,
      wordsDictated: 0,
      agent: OFFLINE_AGENT_SUMMARY,
    }),
    updateSettings: vi.fn().mockImplementation(async patch => ({
      ...DEFAULT_SETTINGS,
      tourSeen: true,
      onboardingComplete: true,
      ...patch,
      hasApiKey: true,
      hasRewriteKey: true,
      agent: OFFLINE_AGENT_SUMMARY,
    })),
    setApiKey: vi.fn().mockResolvedValue({ ok: true, message: 'Key works' }),
    setDeepgramKey: vi.fn().mockResolvedValue({ ok: true, message: 'Key works' }),
    setTranscriptionProvider: vi.fn().mockImplementation(async transcriptionProvider => ({
      ...DEFAULT_SETTINGS,
      tourSeen: true,
      onboardingComplete: true,
      transcriptionProvider,
      hasApiKey: false,
      hasRewriteKey: true,
      wordsDictated: 0,
      agent: OFFLINE_AGENT_SUMMARY,
    })),
    setRewriteKey: vi.fn().mockResolvedValue({ ok: true, message: 'Key works' }),
    setAgentUrl: vi.fn(async () => ({ ok: true, message: 'Agent works', mcpServers: [] })),
    testAgent: vi.fn(async () => ({ ok: true, message: 'Agent works', mcpServers: [] })),
    restartAgent: vi.fn(async () => ({ ok: true, message: 'Agent works', mcpServers: [] })),
    decideApproval: vi.fn(async () => true),
    agentStatus: vi.fn(async () => OFFLINE_AGENT_SUMMARY),
    getPermissions: vi.fn().mockResolvedValue({ microphone: true, accessibility: true }),
    requestPermission: vi.fn().mockResolvedValue({ microphone: true, accessibility: true }),
    onExplain: () => () => {},
    reportExplainHeight: vi.fn(),
    copyExplain: vi.fn(),
    dismissExplain: vi.fn(),
    onSessionBlocked: vi.fn(() => () => {}),
    takeBlockedReason: vi.fn(async () => null),
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

  it('opens on the Overview, ready, when everything is in place', async () => {
    mount(mockApi());
    expect(await screen.findByRole('heading', { name: 'Parley is ready' })).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'Overview' })).toHaveAttribute('aria-selected', 'true');
    expect(screen.queryByText('Finish setup')).not.toBeInTheDocument();
  });

  it('shows time saved from the dictated word count', async () => {
    mount(
      mockApi({
        getSettings: vi.fn().mockResolvedValue({
          ...DEFAULT_SETTINGS,
          tourSeen: true,
          onboardingComplete: true,
          hasApiKey: true,
          hasRewriteKey: true,
          wordsDictated: 600,
          agent: OFFLINE_AGENT_SUMMARY,
        }),
      })
    );
    expect(await screen.findByText('11 min')).toBeInTheDocument();
    expect(screen.getByText(/600 words dictated/)).toBeInTheDocument();
  });

  it('invites a first dictation instead of showing zero', async () => {
    mount(mockApi());
    expect(await screen.findByText('Your first dictation starts the count.')).toBeInTheDocument();
  });

  it('shows the setup banner and a Grant button when Accessibility is missing', async () => {
    const api = mockApi({
      getPermissions: vi.fn().mockResolvedValue({ microphone: true, accessibility: false }),
    });
    mount(api);
    expect(await screen.findByText('Finish setup')).toBeInTheDocument();
    expect(screen.getByText('One thing needs you before the gesture works.')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Grant Accessibility' }));
    expect(api.requestPermission).toHaveBeenCalledWith('accessibility');
  });

  it('shows the setup banner when no API key is stored', async () => {
    mount(
      mockApi({
        getSettings: vi.fn().mockResolvedValue({
          ...DEFAULT_SETTINGS,
          tourSeen: true,
          onboardingComplete: true,
          hasApiKey: false,
          hasRewriteKey: false,
          agent: OFFLINE_AGENT_SUMMARY,
        }),
      })
    );
    expect(await screen.findByText('Finish setup')).toBeInTheDocument();
    // The missing key's form is the fix, so it is already open.
    expect(screen.getByRole('button', { name: 'Add transcription key' })).toHaveAttribute(
      'aria-expanded',
      'true'
    );
  });

  it('saves a toggle at once', async () => {
    const api = mockApi();
    mount(api);
    await userEvent.click(await screen.findByRole('tab', { name: 'General' }));
    await userEvent.click(
      await screen.findByRole('switch', { name: 'Play sounds when recording starts and stops' })
    );
    expect(api.updateSettings).toHaveBeenCalledWith({ tickSound: false });
  });

  it('tests and saves the API key, and shows the result', async () => {
    const api = mockApi();
    mount(api);
    await userEvent.click(await screen.findByRole('button', { name: 'Replace transcription key' }));
    await userEvent.type(await screen.findByLabelText('Groq API key'), 'gsk_abc');
    await userEvent.click(screen.getByRole('button', { name: 'Test and save' }));
    await waitFor(() => expect(api.setApiKey).toHaveBeenCalledWith('gsk_abc'));
    expect(await screen.findByText('Key works')).toBeInTheDocument();
  });

  it('adds the optional MiniMax key from its own row', async () => {
    let hasRewriteKey = false;
    const api = mockApi({
      getSettings: vi.fn(async () => ({
        ...DEFAULT_SETTINGS,
        tourSeen: true,
        onboardingComplete: true,
        hasApiKey: true,
        hasRewriteKey,
        wordsDictated: 0,
        agent: OFFLINE_AGENT_SUMMARY,
      })),
      setRewriteKey: vi.fn(async () => {
        hasRewriteKey = true;
        return { ok: true, message: 'Key works' };
      }),
    });
    mount(api);
    expect(await screen.findByText('Optional')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Add MiniMax key' }));
    await userEvent.type(await screen.findByLabelText('MiniMax API key'), 'mm_abc');
    await userEvent.click(screen.getByRole('button', { name: 'Test and save MiniMax key' }));
    await waitFor(() => expect(api.setRewriteKey).toHaveBeenCalledWith('mm_abc'));
    // The stored key closes the form and the row flips to Stored.
    expect(await screen.findByRole('button', { name: 'Replace MiniMax key' })).toHaveAttribute(
      'aria-expanded',
      'false'
    );
  });

  it('rejects an empty key without calling main', async () => {
    const api = mockApi();
    mount(api);
    await userEvent.click(await screen.findByRole('button', { name: 'Replace transcription key' }));
    await userEvent.click(await screen.findByRole('button', { name: 'Test and save' }));
    expect(await screen.findByText('Enter your Groq API key')).toBeInTheDocument();
    expect(api.setApiKey).not.toHaveBeenCalled();
  });

  it('shows an alert when saving a setting rejects', async () => {
    const api = mockApi({
      updateSettings: vi.fn().mockRejectedValue(new Error('keychain locked')),
    });
    mount(api);
    await userEvent.click(await screen.findByRole('tab', { name: 'General' }));
    await userEvent.click(
      await screen.findByRole('switch', { name: 'Play sounds when recording starts and stops' })
    );
    expect(await screen.findByText('Could not save settings')).toBeInTheDocument();
  });

  it('shows an alert when requesting a permission rejects', async () => {
    const api = mockApi({
      getPermissions: vi.fn().mockResolvedValue({ microphone: true, accessibility: false }),
      requestPermission: vi.fn().mockRejectedValue(new Error('denied')),
    });
    mount(api);
    await userEvent.click(await screen.findByRole('button', { name: 'Grant Accessibility' }));
    expect(await screen.findByText('Could not open System Settings')).toBeInTheDocument();
  });

  it('shows an alert when testing the API key rejects, without rendering the key', async () => {
    const api = mockApi({ setApiKey: vi.fn().mockRejectedValue(new Error('network down')) });
    mount(api);
    await userEvent.click(await screen.findByRole('button', { name: 'Replace transcription key' }));
    await userEvent.type(await screen.findByLabelText('Groq API key'), 'gsk_secret');
    await userEvent.click(screen.getByRole('button', { name: 'Test and save' }));
    const alert = await screen.findByText('Could not test the key');
    expect(alert).toBeInTheDocument();
    expect(screen.queryByText(/gsk_secret/)).not.toBeInTheDocument();
  });
  describe('transcription provider', () => {
    const view = (over: Record<string, unknown> = {}) => ({
      ...DEFAULT_SETTINGS,
      tourSeen: true,
      onboardingComplete: true,
      hasApiKey: true,
      hasRewriteKey: true,
      wordsDictated: 0,
      agent: OFFLINE_AGENT_SUMMARY,
      ...over,
    });

    it('switches to Deepgram and tests and saves a Deepgram key, not a Groq one', async () => {
      // Stateful, as main is: the refetch after a saved key sees the switch.
      let current = view({ hasApiKey: false });
      const api = mockApi({
        getSettings: vi.fn(async () => current),
        setTranscriptionProvider: vi.fn(async transcriptionProvider => {
          current = { ...current, transcriptionProvider };
          return current;
        }),
      });
      mount(api);
      expect(await screen.findByText('Groq’s Whisper turns speech into text.')).toBeInTheDocument();
      expect(screen.getByRole('radio', { name: 'Whisper (Groq)' })).toBeChecked();

      await userEvent.click(screen.getByRole('radio', { name: 'Deepgram Nova-3' }));
      await waitFor(() => expect(api.setTranscriptionProvider).toHaveBeenCalledWith('deepgram'));
      expect(
        await screen.findByText('Deepgram Nova-3 turns speech into text.')
      ).toBeInTheDocument();
      expect(screen.queryByLabelText('Groq API key')).not.toBeInTheDocument();

      await userEvent.type(await screen.findByLabelText('Deepgram API key'), 'dg_abc');
      await userEvent.click(screen.getByRole('button', { name: 'Test and save' }));
      await waitFor(() => expect(api.setDeepgramKey).toHaveBeenCalledWith('dg_abc'));
      expect(api.setApiKey).not.toHaveBeenCalled();
      expect(await screen.findByText('Key works')).toBeInTheDocument();
    });

    it('keeps the form open when switching to a provider that already has a key', async () => {
      const api = mockApi({
        getSettings: vi.fn().mockResolvedValue(view({ hasApiKey: false })),
        setTranscriptionProvider: vi.fn(async transcriptionProvider =>
          view({ transcriptionProvider, hasApiKey: true })
        ),
      });
      mount(api);
      await userEvent.click(await screen.findByRole('radio', { name: 'Deepgram Nova-3' }));
      expect(await screen.findByText('Parley is ready')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Replace transcription key' })).toHaveAttribute(
        'aria-expanded',
        'true'
      );
    });

    it('shows an alert when switching the provider rejects', async () => {
      const api = mockApi({
        getSettings: vi.fn().mockResolvedValue(view({ hasApiKey: false })),
        setTranscriptionProvider: vi.fn().mockRejectedValue(new Error('disk full')),
      });
      mount(api);
      await userEvent.click(await screen.findByRole('radio', { name: 'Deepgram Nova-3' }));
      expect(
        await screen.findByText('Could not switch the transcription provider')
      ).toBeInTheDocument();
    });

    it('names Deepgram in the vocabulary description when it is selected', async () => {
      mount(
        mockApi({
          getSettings: vi.fn().mockResolvedValue(view({ transcriptionProvider: 'deepgram' })),
        })
      );
      await userEvent.click(await screen.findByRole('tab', { name: 'General' }));
      expect(
        await screen.findByText('Names and jargon Deepgram should recognise, separated by commas.')
      ).toBeInTheDocument();
    });

    it('names the selected provider’s key when a refused gesture opened the window', async () => {
      const error = vi.spyOn(toast, 'error').mockImplementation(() => {});
      mount(
        mockApi({
          getSettings: vi
            .fn()
            .mockResolvedValue(view({ transcriptionProvider: 'deepgram', hasApiKey: false })),
          takeBlockedReason: vi.fn(async () => 'apiKey' as const),
        })
      );
      await waitFor(() =>
        expect(error).toHaveBeenCalledWith('Add a Deepgram API key before trying the gesture.')
      );
      error.mockRestore();
    });
  });

  describe('agent block', () => {
    it('opens the Agent tab and names the fix when the agent refused the gesture', async () => {
      const error = vi.spyOn(toast, 'error').mockImplementation(() => {});
      mount(
        mockApi({
          takeBlockedReason: vi.fn(async () => 'agent' as const),
        })
      );
      await waitFor(() =>
        expect(error).toHaveBeenCalledWith('Start the agent before trying the gesture.')
      );
      const tab = await screen.findByRole('tab', { name: 'Agent' });
      await waitFor(() => expect(tab).toHaveAttribute('aria-selected', 'true'));
      error.mockRestore();
    });

    it('names the missing servers when the agent is up but cannot act', async () => {
      const error = vi.spyOn(toast, 'error').mockImplementation(() => {});
      mount(
        mockApi({
          getSettings: vi.fn().mockResolvedValue({
            ...DEFAULT_SETTINGS,
            tourSeen: true,
            onboardingComplete: true,
            hasApiKey: true,
            hasRewriteKey: true,
            wordsDictated: 0,
            agent: { ...OFFLINE_AGENT_SUMMARY, online: true, serverState: 'online' as const },
          }),
          takeBlockedReason: vi.fn(async () => 'agent' as const),
        })
      );
      await waitFor(() =>
        expect(error).toHaveBeenCalledWith('Connect an MCP server before trying the gesture.')
      );
      error.mockRestore();
    });

    it('jumps from the Overview Agent row to the Agent tab', async () => {
      mount(mockApi());
      await userEvent.click(await screen.findByRole('button', { name: 'Open' }));
      const tab = await screen.findByRole('tab', { name: 'Agent' });
      await waitFor(() => expect(tab).toHaveAttribute('aria-selected', 'true'));
    });
  });
});
