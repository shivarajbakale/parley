import type { Meta, StoryObj } from '@storybook/react';

import { eventArgTypes, handlers } from 'storybook/story-helpers';

import type { ParleyApi } from '../../electron/types';

import { MiniMaxOffer } from './MiniMaxOffer';

/** MiniMax asked for on first use: opens over settings when a voice edit or Explain gesture is refused for a missing key. */
const meta = {
  title: 'Parley/Onboarding/MiniMaxOffer',
  component: MiniMaxOffer,
  tags: ['autodocs'],
  parameters: { layout: 'padded' },
  argTypes: { ...eventArgTypes(['onClose']) },
  decorators: [
    Story => {
      window.parley = {
        ...window.parley,
        setRewriteKey: async () => ({ ok: false, message: 'MiniMax rejected that key' }),
      } as ParleyApi;
      return <Story />;
    },
  ],
} satisfies Meta<typeof MiniMaxOffer>;

export default meta;
type Story = StoryObj<typeof MiniMaxOffer>;

/** The first refusal: no key yet, form empty. */
export const Open: Story = { args: { opened: true, withinPortal: false, hasRewriteKey: false, ...handlers(['onClose']) } };
/** Same frame; the mock rejects every key, so submitting shows MiniMax's reason under the field. */
export const KeyRejected: Story = {
  args: { opened: true, withinPortal: false, hasRewriteKey: false, ...handlers(['onClose']) },
};

/** The key just stored: the offer says to try again, then closes itself. */
export const Stored: Story = { args: { opened: true, withinPortal: false, hasRewriteKey: true, ...handlers(['onClose']) } };
