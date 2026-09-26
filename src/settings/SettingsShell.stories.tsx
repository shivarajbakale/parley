import type { Meta, StoryObj } from '@storybook/react';

import { eventArgTypes, handlers } from 'storybook/story-helpers';

import {
  DEFAULT_SETTINGS,
  OFFLINE_AGENT_SUMMARY,
  type AgentSummary,
  type ParleyApi,
  type SettingsView,
} from '../../electron/types';

import { SettingsShell } from './SettingsShell';

const settled: SettingsView = {
  ...DEFAULT_SETTINGS,
  tourSeen: true,
  onboardingComplete: true,
  hasApiKey: true,
  hasRewriteKey: false,
  wordsDictated: 1340,
  agent: OFFLINE_AGENT_SUMMARY,
};

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
      window.parley = {
        ...window.parley,
        setApiKey: async () => ({ ok: true, message: 'Key works' }),
        setDeepgramKey: async () => ({ ok: true, message: 'Key works' }),
        setTranscriptionProvider: async transcriptionProvider => ({
          ...settled,
          transcriptionProvider,
        }),
        setRewriteKey: async () => ({ ok: true, message: 'Key works' }),
        setAgentUrl: async () => ({ ok: true, message: 'Starting…', mcpServers: [] }),
        testAgent: async () => ({ ok: agent.online, message: agent.message || 'Agent works', mcpServers: agent.mcpServers }),
        restartAgent: async () => ({ ok: true, message: 'Restarting…', mcpServers: agent.mcpServers }),
        decideApproval: async () => true,
        agentStatus: async () => agent,
        requestPermission: async () => ({ microphone: true, accessibility: true }),
        updateSettings: async patch => ({ ...settled, ...patch }),
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

/** Accessibility revoked and no transcription key: the title says so and each row carries its fix. */
export const NeedsSetup: Story = {
  args: {
    ...base,
    settings: { ...settled, hasApiKey: false, wordsDictated: 0 },
    permissions: { microphone: true, accessibility: false },
  },
};

/** The Gesture tab as a grouped list: Keys, then Timing. */
export const Gesture: Story = { args: { ...base, initialTab: 'gesture' } };

/** The General tab: Behaviour, Dictation and Help groups. */
export const General: Story = { args: { ...base, initialTab: 'general' } };

/** Deepgram Nova-3 selected with no Deepgram key yet: the provider choice and its key form are open. */
export const DeepgramNeedsKey: Story = {
  args: {
    ...base,
    settings: { ...settled, transcriptionProvider: 'deepgram', hasApiKey: false },
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
