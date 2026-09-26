import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import {
  DEFAULT_SETTINGS,
  OFFLINE_AGENT_SUMMARY,
  type AgentSummary,
  type ParleyApi,
  type SettingsView,
} from '../../../electron/types';
import { AgentTab } from '../AgentTab';

function view(agent: AgentSummary): SettingsView {
  return {
    ...DEFAULT_SETTINGS,
    tourSeen: true,
    onboardingComplete: true,
    hasApiKey: true,
    hasRewriteKey: true,
    wordsDictated: 0,
    agent,
  };
}

const ONLINE: AgentSummary = {
  online: true,
  managed: true,
  serverState: 'online',
  message: '',
  currentRun: null,
  mcpServers: [
    { name: 'Files', tools: 12 },
    { name: 'Calendar', tools: 8 },
  ],
};

function mount(settings: SettingsView, api: Partial<ParleyApi> = {}) {
  window.parley = {
    agentStatus: vi.fn(async () => settings.agent),
    setAgentUrl: vi.fn(async () => ({ ok: true, message: 'Agent works', mcpServers: [] })),
    testAgent: vi.fn(async () => ({ ok: true, message: 'Agent works', mcpServers: [] })),
    restartAgent: vi.fn(async () => ({ ok: true, message: 'Restarting…', mcpServers: [] })),
    decideApproval: vi.fn(async () => true),
    ...api,
  } as ParleyApi;
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <ThemeProvider>
        <AgentTab settings={settings} onChange={vi.fn()} />
      </ThemeProvider>
    </QueryClientProvider>
  );
}

describe('AgentTab', () => {
  beforeEach(() => vi.useRealTimers());

  it('leads with reachability, the safety contract and an example', async () => {
    mount(view(ONLINE));
    expect(await screen.findByText('Files · Calendar · 20 tools')).toBeInTheDocument();
    expect(screen.getByText('Parley always asks before changing anything.')).toBeInTheDocument();
    expect(screen.getByText('book dentist Tuesday 9am')).toBeInTheDocument();
    // Server machinery waits under Advanced.
    expect(screen.getByLabelText('Agent URL')).not.toBeVisible();
    await userEvent.click(screen.getByRole('button', { name: 'Show Advanced' }));
    expect(await screen.findByLabelText('Agent URL')).toBeInTheDocument();
    expect(screen.getByText('Files')).toBeInTheDocument();
    expect(screen.getByText('12 tools')).toBeInTheDocument();
  });

  it('keeps a failed spawn visible with a way forward', async () => {
    mount(
      view({
        ...OFFLINE_AGENT_SUMMARY,
        message: 'refused on :4111',
      })
    );
    expect(await screen.findByText('refused on :4111')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Open Advanced' }));
    await waitFor(() => expect(screen.getByLabelText('Agent URL')).toBeVisible());
  });

  it('tests the connection and shows what came back', async () => {
    const user = userEvent.setup();
    mount(view(ONLINE));
    await user.click(await screen.findByRole('button', { name: 'Test connection' }));
    expect(window.parley.testAgent).toHaveBeenCalledTimes(1);
    expect(await screen.findByText('Agent works')).toBeInTheDocument();
  });

  it('answers a waiting approval from the mirrored buttons', async () => {
    const user = userEvent.setup();
    const decideApproval = vi.fn(async () => true);
    mount(
      view({
        ...ONLINE,
        currentRun: { status: 'awaiting_approval', summary: 'Delete 3 events?', callId: 'c9' },
      }),
      { decideApproval }
    );
    expect(await screen.findByText('Delete 3 events?')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Approve' }));
    expect(decideApproval).toHaveBeenCalledWith('c9', true);
  });

  it('says when the pill answered first', async () => {
    const user = userEvent.setup();
    mount(
      view({
        ...ONLINE,
        currentRun: { status: 'awaiting_approval', summary: 'Delete 3 events?', callId: 'c9' },
      }),
      { decideApproval: vi.fn(async () => false) }
    );
    await user.click(await screen.findByRole('button', { name: 'Decline' }));
    expect(await screen.findByText('Already answered on the pill.')).toBeInTheDocument();
  });

  it('saves a URL only when it parses as http(s)', async () => {
    const user = userEvent.setup();
    const setAgentUrl = vi.fn(async () => ({ ok: true, message: 'Starting…', mcpServers: [] }));
    mount(view(OFFLINE_AGENT_SUMMARY), { setAgentUrl });
    await user.click(screen.getByRole('button', { name: 'Show Advanced' }));
    const field = await screen.findByLabelText('Agent URL');
    await user.clear(field);
    await user.type(field, 'not a url');
    await user.click(screen.getByRole('button', { name: 'Save address' }));
    expect(await screen.findByText('Use an http(s) URL')).toBeInTheDocument();
    expect(setAgentUrl).not.toHaveBeenCalled();
    await user.clear(field);
    await user.type(field, 'http://localhost:4222');
    await user.click(screen.getByRole('button', { name: 'Save address' }));
    await waitFor(() => expect(setAgentUrl).toHaveBeenCalledWith('http://localhost:4222'));
  });

  it('disables Restart for an attached server', async () => {
    const user = userEvent.setup();
    mount(view({ ...ONLINE, managed: false }));
    expect(await screen.findByText('Attached · Files · Calendar · 20 tools')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Show Advanced' }));
    expect(await screen.findByRole('button', { name: 'Restart' })).toBeDisabled();
  });

  it('restarts the server Parley started', async () => {
    const user = userEvent.setup();
    mount(view(ONLINE));
    await user.click(screen.getByRole('button', { name: 'Show Advanced' }));
    const restart = await screen.findByRole('button', { name: 'Restart' });
    expect(restart).toBeEnabled();
    await user.click(restart);
    expect(window.parley.restartAgent).toHaveBeenCalledTimes(1);
  });
});
