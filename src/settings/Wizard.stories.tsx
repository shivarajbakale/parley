import type { Meta, StoryObj } from '@storybook/react';

import {
  DEFAULT_SETTINGS,
  type ParleyApi,
  type PermissionStatus,
  type SettingsView,
} from '../../electron/types';

import { WizardShell } from './wizard/WizardShell';

/**
 * Setup wizard: step rail plus one step pane. Each story pins the persisted
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
      setRewriteKey: async () => ({ ok: true, message: 'Key works' }),
      getPermissions: async () => permissions,
      requestPermission: async () => permissions,
      onExplain: () => () => {},
      reportExplainHeight: () => {},
      copyExplain: () => {},
      dismissExplain: () => {},
      onSessionBlocked: () => () => {},
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
};

/** Setup wizard: step rail plus one step pane, opened mid-flow as a resume would. */
const meta = {
  title: 'Parley/Onboarding/Wizard',
  component: WizardShell,
  tags: ['autodocs'],
  parameters: { layout: 'padded' },
} satisfies Meta<typeof WizardShell>;

export default meta;
type Story = StoryObj<typeof WizardShell>;

export const FreshStart: Story = {
  decorators: [withParley(fresh, { microphone: false, accessibility: false })],
};

export const AccessibilityStep: Story = {
  decorators: [withParley({ ...fresh, wizardStep: 1 }, { microphone: true, accessibility: false })],
};

export const HotkeysStep: Story = {
  decorators: [
    withParley(
      { ...fresh, wizardStep: 4, hasApiKey: true, hasRewriteKey: true },
      { microphone: true, accessibility: true }
    ),
  ],
};

export const Done: Story = {
  decorators: [
    withParley(
      { ...fresh, wizardStep: 6, hasApiKey: true, hasRewriteKey: true },
      { microphone: true, accessibility: true }
    ),
  ],
};
