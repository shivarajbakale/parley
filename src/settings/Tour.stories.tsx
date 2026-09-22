import type { Meta, StoryObj } from '@storybook/react';

import { eventArgTypes, handlers, numberArg } from 'storybook/story-helpers';

import { Tour } from './tour/Tour';

/** First-run product tour: four animated mini-UI scenes, manual advance, Skip always visible. */
const meta = {
  title: 'Parley/Onboarding/Tour',
  component: Tour,
  tags: ['autodocs'],
  parameters: { layout: 'padded' },
  argTypes: {
    initialSlide: numberArg('initialSlide', {
      min: 0,
      max: 3,
      description: 'Slide on open. Only the visible slide animates.',
      defaultValue: 0,
    }),
    ...eventArgTypes(['onDone']),
  },
} satisfies Meta<typeof Tour>;

export default meta;
type Story = StoryObj<typeof Tour>;

export const Default: Story = { args: { initialSlide: 0, ...handlers(['onDone']) } };
export const VoiceEdit: Story = { args: { initialSlide: 1, ...handlers(['onDone']) } };
export const Explain: Story = { args: { initialSlide: 2, ...handlers(['onDone']) } };
export const Trust: Story = { args: { initialSlide: 3, ...handlers(['onDone']) } };
