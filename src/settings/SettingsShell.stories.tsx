import type { Meta, StoryObj } from '@storybook/react';

import { eventArgTypes, handlers } from 'storybook/story-helpers';
import { expect, userEvent, within } from 'storybook/test';

import {
  DEFAULT_SETTINGS,
  OFFLINE_AGENT_SUMMARY,
  type AgentSummary,
  type ParleyApi,
  type ServerStatus,
  type SettingsView,
} from '../../electron/types';

import { SettingsShell } from './SettingsShell';

const settled: SettingsView = {
  ...DEFAULT_SETTINGS,
  tourSeen: true,
  onboardingComplete: true,
  wordsDictated: 1340,
  hasSyncToken: false,
  syncLastAt: 0,
  syncLastError: '',
  agent: OFFLINE_AGENT_SUMMARY,
};

const RUNNING: ServerStatus = {
  reachable: true,
  url: 'http://localhost:3100',
  keys: { groq: true, deepgram: false, minimax: true },
};

const NOT_RUNNING: ServerStatus = { reachable: false, url: 'http://localhost:3100', keys: null };

const ONLINE_AGENT: AgentSummary = {
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

const BROKEN_AGENT: AgentSummary = { ...OFFLINE_AGENT_SUMMARY, message: 'refused on :4111' };

const WAITING_AGENT: AgentSummary = {
  ...ONLINE_AGENT,
  currentRun: { status: 'awaiting_approval', summary: 'Delete 3 events?', callId: 'c9' },
};

/** The settings window after first run: Overview first, then the grouped Gesture and General tabs. */
const meta = {
  title: 'Parley/Settings/SettingsShell',
  component: SettingsShell,
  tags: ['autodocs'],
  parameters: { layout: 'fullscreen' },
  argTypes: { ...eventArgTypes(['onChange']) },
  decorators: [
    (Story, context) => {
      const agent =
        (context as { parameters?: { agent?: AgentSummary } }).parameters?.agent ??
        OFFLINE_AGENT_SUMMARY;
      const signInSync = (context as { parameters?: { signInSync?: ParleyApi['signInSync'] } })
        .parameters?.signInSync;
      const server =
        (context as { parameters?: { server?: ServerStatus } }).parameters?.server ?? RUNNING;
      window.parley = {
        ...window.parley,
        setTranscriptionProvider: async transcriptionProvider => ({
          ...settled,
          transcriptionProvider,
        }),
        serverStatus: async () => server,
        setAgentUrl: async () => ({ ok: true, message: 'Starting…', mcpServers: [] }),
        testAgent: async () => ({ ok: agent.online, message: agent.message || 'Agent works', mcpServers: agent.mcpServers }),
        restartAgent: async () => ({ ok: true, message: 'Restarting…', mcpServers: agent.mcpServers }),
        decideApproval: async () => true,
        agentStatus: async () => agent,
        requestPermission: async () => ({ microphone: true, accessibility: true }),
        updateSettings: async patch => ({ ...settled, ...patch }),
        signInSync: signInSync ?? (async () => ({ ok: true, message: 'Signed in and synced' })),
        signOutSync: async () => settled,
        syncNow: async () => ({
          ok: true,
          pushed: 3,
          pulled: 1,
          message: 'Synced 3 up, 1 down',
          at: Date.now(),
        }),
      } as ParleyApi;
      return <Story />;
    },
  ],
} satisfies Meta<typeof SettingsShell>;

export default meta;
type Story = StoryObj<typeof SettingsShell>;

const base = {
  settings: settled,
  permissions: { microphone: true, accessibility: true },
  saveFailed: false,
  ...handlers(['onChange']),
};

/** Everything green, with a running time-saved figure. */
export const Ready: Story = { args: base };

/** Accessibility revoked and the Parley server down: the title counts both, the server group says how to start it. */
export const NeedsSetup: Story = {
  args: {
    ...base,
    settings: { ...settled, wordsDictated: 0 },
    permissions: { microphone: true, accessibility: false },
  },
  parameters: { server: NOT_RUNNING },
};

/** The server is up without a MiniMax key: voice edit and Act say which variable to add. */
export const MiniMaxKeyMissing: Story = {
  args: base,
  parameters: { server: { ...RUNNING, keys: { groq: true, deepgram: false, minimax: false } } },
};

/** The Gesture tab as a grouped list: Keys, then Timing. */
export const Gesture: Story = { args: { ...base, initialTab: 'gesture' } };

/** The General tab: Behaviour, Dictation and Help groups. */
export const General: Story = { args: { ...base, initialTab: 'general' } };

/** Deepgram Nova-3 selected and the server has no Deepgram key: the row says Not set and names DEEPGRAM_API_KEY. */
export const DeepgramNeedsKey: Story = {
  args: {
    ...base,
    settings: { ...settled, transcriptionProvider: 'deepgram' },
  },
};

/** The Agent tab with a healthy server: reachability, the safety contract, an example. */
export const AgentOnline: Story = {
  args: {
    ...base,
    initialTab: 'agent',
    settings: { ...settled, agent: ONLINE_AGENT },
  },
  parameters: { agent: ONLINE_AGENT },
};

/** No server: the tab says dictation is unaffected and Advanced waits below. */
export const AgentOffline: Story = {
  args: { ...base, initialTab: 'agent' },
  parameters: { agent: OFFLINE_AGENT_SUMMARY },
};

/** A failed spawn stays visible with its message and a way into Advanced. */
export const AgentTestError: Story = {
  args: {
    ...base,
    initialTab: 'agent',
    settings: { ...settled, agent: BROKEN_AGENT },
  },
  parameters: { agent: BROKEN_AGENT },
};

/** A waiting approval mirrors with Approve and Decline. */
export const AgentAwaitingApproval: Story = {
  args: {
    ...base,
    initialTab: 'agent',
    settings: { ...settled, agent: WAITING_AGENT },
  },
  parameters: { agent: WAITING_AGENT },
};

const SIGNED_IN: SettingsView = {
  ...settled,
  hasSyncToken: true,
  syncEnabled: true,
  syncEmail: 'me@example.com',
};

/** Sync, signed out: the server address and an email form. */
export const SyncSignedOut: Story = { args: { ...base, initialTab: 'sync' } };

/** Sync while the server answers: Sign in spins and the email field waits. */
export const SyncSigningIn: Story = {
  args: { ...base, initialTab: 'sync' },
  parameters: { signInSync: () => new Promise(() => {}) },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.type(canvas.getByLabelText('Email'), 'me@example.com');
    await userEvent.click(canvas.getByRole('button', { name: 'Sign in' }));
    await expect(canvas.getByLabelText('Email')).toBeDisabled();
  },
};

/** Sync, signed in and healthy: the account, the switch, Last sync and Sync now. */
export const SyncSynced: Story = {
  args: {
    ...base,
    initialTab: 'sync',
    settings: { ...SIGNED_IN, syncLastAt: Date.now() - 2 * 60_000 },
  },
};

/** The last run failed: the message stays up with the reassurance that dictation is fine. */
export const SyncError: Story = {
  args: {
    ...base,
    initialTab: 'sync',
    settings: {
      ...SIGNED_IN,
      syncLastAt: Date.now() - 3 * 60 * 60_000,
      syncLastError: 'fetch failed',
    },
  },
};
