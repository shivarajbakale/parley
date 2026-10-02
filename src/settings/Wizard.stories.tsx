import type { Meta, StoryObj } from '@storybook/react';

import {
  DEFAULT_SETTINGS,
  OFFLINE_AGENT_SUMMARY,
  type ParleyApi,
  type PermissionStatus,
  type ServerStatus,
  type SettingsView,
} from '../../electron/types';

import { WizardShell } from './wizard/WizardShell';

/**
 * First-run flow: an orb progress ring above one screen, on the first-run Scene. Each story pins the persisted
 * settings, so the shell opens mid-flow exactly as a resume would.
 */
const RUNNING: ServerStatus = {
  reachable: true,
  url: 'http://localhost:3100',
  keys: { groq: true, deepgram: false, minimax: true },
};
const NOT_RUNNING: ServerStatus = { reachable: false, url: 'http://localhost:3100', keys: null };

function withParley(settings: SettingsView, permissions: PermissionStatus, server: ServerStatus = RUNNING) {
  return (Story: () => React.JSX.Element) => {
    let current = settings;
    window.parley = {
      onOrbPhase: () => () => {},
      sendAudio: () => {},
      getSettings: async () => current,
      updateSettings: async patch => {
        current = { ...current, ...patch };
        return current;
      },
      setTranscriptionProvider: async transcriptionProvider => {
        current = { ...current, transcriptionProvider };
        return current;
      },
      serverStatus: async () => server,
      setAgentUrl: async () => ({ ok: true, message: 'Agent works', mcpServers: [] }),
      testAgent: async () => ({ ok: true, message: 'Agent works', mcpServers: [] }),
      restartAgent: async () => ({ ok: true, message: 'Agent works', mcpServers: [] }),
      decideApproval: async () => true,
      agentStatus: async () => OFFLINE_AGENT_SUMMARY,
      signInSync: async () => ({ ok: true, message: 'Signed in and synced' }),
      signOutSync: async () => current,
      syncNow: async () => ({ ok: true, pushed: 0, pulled: 0, message: 'Synced 0 up, 0 down', at: Date.now() }),
      getPermissions: async () => permissions,
      requestPermission: async () => permissions,
      onExplain: () => () => {},
      reportExplainHeight: () => {},
      copyExplain: () => {},
      dismissExplain: () => {},
      openExternal: () => {},
      onSessionBlocked: () => () => {},
      takeBlockedReason: async () => null,
    } satisfies ParleyApi;
    return <Story />;
  };
}

const fresh: SettingsView = {
  ...DEFAULT_SETTINGS,
  tourSeen: true,
  wizardStep: 0,
  onboardingComplete: false,
  wordsDictated: 0,
  hasSyncToken: false,
  syncLastAt: 0,
  syncLastError: '',
  agent: OFFLINE_AGENT_SUMMARY,
};

/** First-run flow: one screen at a time under the ring, opened mid-flow as a resume would. */
const meta = {
  title: 'Parley/Onboarding/Wizard',
  component: WizardShell,
  tags: ['autodocs'],
  parameters: { layout: 'padded' },
} satisfies Meta<typeof WizardShell>;

export default meta;
type Story = StoryObj<typeof WizardShell>;

export const Welcome: Story = {
  decorators: [withParley(fresh, { microphone: false, accessibility: false })],
};

export const AccessibilityStep: Story = {
  decorators: [withParley({ ...fresh, wizardStep: 2 }, { microphone: true, accessibility: false })],
};

/** The transcription step with parley-api up and holding the Groq key. */
export const ServerStep: Story = {
  decorators: [withParley({ ...fresh, wizardStep: 3 }, { microphone: true, accessibility: true })],
};

/** The same step with the server down: the start command, Check again, Continue still open. */
export const ServerStepNotRunning: Story = {
  decorators: [
    withParley({ ...fresh, wizardStep: 3 }, { microphone: true, accessibility: true }, NOT_RUNNING),
  ],
};

export const GestureTrainer: Story = {
  decorators: [
    withParley({ ...fresh, wizardStep: 4}, { microphone: true, accessibility: true }),
  ],
};

export const Finale: Story = {
  decorators: [
    withParley({ ...fresh, wizardStep: 6}, { microphone: true, accessibility: true }),
  ],
};

export const FinaleWithMissing: Story = {
  decorators: [
    withParley({ ...fresh, wizardStep: 6 }, { microphone: true, accessibility: false }, NOT_RUNNING),
  ],
};
