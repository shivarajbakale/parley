import type { Meta, StoryObj } from '@storybook/react';

import {
  DEFAULT_SETTINGS,
  OFFLINE_AGENT_SUMMARY,
  type ParleyApi,
  type PermissionStatus,
  type SettingsView,
} from '../../electron/types';

import { WizardShell } from './wizard/WizardShell';

/**
 * First-run flow: an orb progress ring above one screen, on the first-run Scene. Each story pins the persisted
 * settings, so the shell opens mid-flow exactly as a resume would.
 */
function withParley(settings: SettingsView, permissions: PermissionStatus) {
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
      setApiKey: async () => ({ ok: true, message: 'Key works' }),
      setDeepgramKey: async () => ({ ok: true, message: 'Key works' }),
      setTranscriptionProvider: async transcriptionProvider => {
        current = { ...current, transcriptionProvider };
        return current;
      },
      setRewriteKey: async () => ({ ok: true, message: 'Key works' }),
      setAgentUrl: async () => ({ ok: true, message: 'Agent works', mcpServers: [] }),
      testAgent: async () => ({ ok: true, message: 'Agent works', mcpServers: [] }),
      restartAgent: async () => ({ ok: true, message: 'Agent works', mcpServers: [] }),
      decideApproval: async () => true,
      agentStatus: async () => OFFLINE_AGENT_SUMMARY,
      getPermissions: async () => permissions,
      requestPermission: async () => permissions,
      onExplain: () => () => {},
      reportExplainHeight: () => {},
      copyExplain: () => {},
      dismissExplain: () => {},
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
  hasApiKey: false,
  hasRewriteKey: false,
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

export const GestureTrainer: Story = {
  decorators: [
    withParley({ ...fresh, wizardStep: 4, hasApiKey: true }, { microphone: true, accessibility: true }),
  ],
};

export const Finale: Story = {
  decorators: [
    withParley({ ...fresh, wizardStep: 6, hasApiKey: true }, { microphone: true, accessibility: true }),
  ],
};

export const FinaleWithMissing: Story = {
  decorators: [withParley({ ...fresh, wizardStep: 6 }, { microphone: true, accessibility: false })],
};
