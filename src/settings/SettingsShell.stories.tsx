import type { Meta, StoryObj } from '@storybook/react';

import { eventArgTypes, handlers } from 'storybook/story-helpers';

import { DEFAULT_SETTINGS, type ParleyApi, type SettingsView } from '../../electron/types';

import { SettingsShell } from './SettingsShell';

const settled: SettingsView = {
  ...DEFAULT_SETTINGS,
  tourSeen: true,
  onboardingComplete: true,
  hasApiKey: true,
  hasRewriteKey: false,
  wordsDictated: 1340,
};

/** The settings window after first run: Overview first, then the grouped Gesture and General tabs. */
const meta = {
  title: 'Parley/Settings/SettingsShell',
  component: SettingsShell,
  tags: ['autodocs'],
  parameters: { layout: 'fullscreen' },
  argTypes: { ...eventArgTypes(['onChange']) },
  decorators: [
    Story => {
      window.parley = {
        ...window.parley,
        setApiKey: async () => ({ ok: true, message: 'Key works' }),
        setDeepgramKey: async () => ({ ok: true, message: 'Key works' }),
        setTranscriptionProvider: async transcriptionProvider => ({
          ...settled,
          transcriptionProvider,
        }),
        setRewriteKey: async () => ({ ok: true, message: 'Key works' }),
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
