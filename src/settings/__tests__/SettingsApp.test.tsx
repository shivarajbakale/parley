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
      wordsDictated: 0,
      hasSyncToken: false,
      syncLastAt: 0,
      syncLastError: '',
      agent: OFFLINE_AGENT_SUMMARY,
    }),
    updateSettings: vi.fn().mockImplementation(async patch => ({
      ...DEFAULT_SETTINGS,
      tourSeen: true,
      onboardingComplete: true,
      ...patch,
      agent: OFFLINE_AGENT_SUMMARY,
    })),
    setTranscriptionProvider: vi.fn().mockImplementation(async transcriptionProvider => ({
      ...DEFAULT_SETTINGS,
      tourSeen: true,
      onboardingComplete: true,
      transcriptionProvider,
      wordsDictated: 0,
      hasSyncToken: false,
      syncLastAt: 0,
      syncLastError: '',
      agent: OFFLINE_AGENT_SUMMARY,
    })),
    serverStatus: vi.fn().mockResolvedValue({
      reachable: true,
      url: 'http://localhost:3100',
      keys: { groq: true, deepgram: false, minimax: true },
    }),
    setAgentUrl: vi.fn(async () => ({ ok: true, message: 'Agent works', mcpServers: [] })),
    testAgent: vi.fn(async () => ({ ok: true, message: 'Agent works', mcpServers: [] })),
    restartAgent: vi.fn(async () => ({ ok: true, message: 'Agent works', mcpServers: [] })),
    decideApproval: vi.fn(async () => true),
    agentStatus: vi.fn(async () => OFFLINE_AGENT_SUMMARY),
    signInSync: vi.fn(),
    signOutSync: vi.fn(),
    syncNow: vi.fn(),
    getPermissions: vi.fn().mockResolvedValue({ microphone: true, accessibility: true }),
    requestPermission: vi.fn().mockResolvedValue({ microphone: true, accessibility: true }),
    onExplain: () => () => {},
    reportExplainHeight: vi.fn(),
    copyExplain: vi.fn(),
    dismissExplain: vi.fn(),
    openExternal: vi.fn(),
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

  it('shows the setup banner when the server has no key for the selected provider', async () => {
    mount(
      mockApi({
        serverStatus: vi.fn().mockResolvedValue({
          reachable: true,
          url: 'http://localhost:3100',
          keys: { groq: false, deepgram: false, minimax: true },
        }),
      })
    );
    expect(await screen.findByText('Finish setup')).toBeInTheDocument();
    expect(screen.getByText('GROQ_API_KEY')).toBeInTheDocument();
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

  it('shows the Parley server running and the keys it holds, never a key field', async () => {
    mount(mockApi());
    expect(await screen.findByText('Running')).toBeInTheDocument();
    expect(await screen.findAllByText('On the server')).toHaveLength(2);
    expect(screen.queryByLabelText(/API key/)).not.toBeInTheDocument();
    expect(await screen.findByText('Parley is ready')).toBeInTheDocument();
  });

  it('says how to start the server when it does not answer, and counts it as setup', async () => {
    mount(
      mockApi({
        serverStatus: vi.fn().mockResolvedValue({ reachable: false, url: 'http://localhost:3100', keys: null }),
      })
    );
    expect(await screen.findByText('Not running')).toBeInTheDocument();
    expect(screen.getByRole('alert')).toHaveTextContent('Start it with make api in the parley folder.');
    expect(await screen.findByText('Finish setup')).toBeInTheDocument();
  });

  it('names the .env variable for a key the server lacks', async () => {
    mount(
      mockApi({
        serverStatus: vi.fn().mockResolvedValue({
          reachable: true,
          url: 'http://localhost:3100',
          keys: { groq: true, deepgram: false, minimax: false },
        }),
      })
    );
    expect(await screen.findByText('MINIMAX_API_KEY')).toBeInTheDocument();
    expect(screen.getByText('Not set')).toBeInTheDocument();
  });

  it('checks the server again on request', async () => {
    const api = mockApi();
    mount(api);
    await screen.findByText('Running');
    await userEvent.click(screen.getByRole('button', { name: 'Check again' }));
    await waitFor(() => expect(api.serverStatus).toHaveBeenCalledTimes(2));
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

  describe('transcription provider', () => {
    const view = (over: Record<string, unknown> = {}) => ({
      ...DEFAULT_SETTINGS,
      tourSeen: true,
      onboardingComplete: true,
      wordsDictated: 0,
      hasSyncToken: false,
      syncLastAt: 0,
      syncLastError: '',
      agent: OFFLINE_AGENT_SUMMARY,
      ...over,
    });

    it('switches to Deepgram and says the server has no Deepgram key', async () => {
      // Stateful, as main is: the refetch sees the switch.
      let current = view();
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
      expect(await screen.findByText('DEEPGRAM_API_KEY')).toBeInTheDocument();
      expect(await screen.findByText('Finish setup')).toBeInTheDocument();
    });

    it('shows an alert when switching the provider rejects', async () => {
      const api = mockApi({
        getSettings: vi.fn().mockResolvedValue(view()),
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
            wordsDictated: 0,
            hasSyncToken: false,
            syncLastAt: 0,
            syncLastError: '',
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
