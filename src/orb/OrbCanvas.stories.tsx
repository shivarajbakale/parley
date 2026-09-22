import type { Meta, StoryObj } from '@storybook/react';
import { Center } from '@mantine/core';

import { numberArg } from 'storybook/story-helpers';

import type { OrbPhase } from '../../electron/types';

import type { OrbFraming } from './orb-shader';

import type { Bands } from './bands';
import { OrbCanvas } from './OrbCanvas';

type Signal = 'silence' | 'speech' | 'sweep';

/** Speech-like: syllable bursts at about 4 Hz with a slower phrase contour. */
function synth(signal: Signal, seconds: number): Bands {
  if (signal === 'silence') return { low: 0, mid: 0, high: 0 };
  if (signal === 'sweep') {
    const position = (seconds % 6) / 6;
    return {
      low: Math.max(0, 1 - position * 3),
      mid: Math.max(0, 1 - Math.abs(position - 0.5) * 3),
      high: Math.max(0, position * 3 - 2),
    };
  }
  const syllable = Math.max(0, Math.sin(seconds * Math.PI * 4)) ** 2;
  const phrase = 0.5 + 0.5 * Math.sin(seconds * 0.9);
  const energy = syllable * phrase;
  return { low: energy * 0.9, mid: energy * 0.7, high: energy * 0.4 * (0.5 + 0.5 * Math.sin(seconds * 11)) };
}

function Demo({
  size,
  phase,
  signal,
  framing = 'flame',
}: {
  size: number;
  phase: OrbPhase;
  signal: Signal;
  framing?: OrbFraming;
}) {
  return (
    <Center w={size + 40} h={size + 40}>
      <OrbCanvas
        size={size}
        framing={framing}
        running
        read={() => ({ bands: synth(signal, performance.now() / 1000), phase })}
      />
    </Center>
  );
}

/** The orb renderer, fed synthetic audio. Judge it by eye: fluid, lit, never bouncing. */
const meta = {
  title: 'Parley/Orb/OrbCanvas',
  component: Demo,
  tags: ['autodocs'],
  parameters: { layout: 'centered' },
  argTypes: {
    size: numberArg('size', { description: 'Canvas size in CSS pixels.', defaultValue: 240 }),
    phase: {
      control: 'select',
      options: ['listening', 'transcribing', 'done', 'error', 'cancelled'],
      description: 'Orb phase. Changes crossfade over 300 ms.',
    },
    signal: {
      control: 'select',
      options: ['silence', 'speech', 'sweep'],
      description: 'Synthetic audio fed to the orb.',
    },
    framing: {
      control: 'select',
      options: ['flame', 'badge'],
      description: 'flame sits the body low with room for tongues; badge centres it for settings.',
    },
  },
} satisfies Meta<typeof Demo>;

export default meta;
type Story = StoryObj<typeof Demo>;

export const Default: Story = { args: { size: 240, phase: 'listening', signal: 'speech' } };
export const Idle: Story = { args: { size: 240, phase: 'listening', signal: 'silence' } };
export const BandSweep: Story = { args: { size: 240, phase: 'listening', signal: 'sweep' } };
export const Transcribing: Story = { args: { size: 240, phase: 'transcribing', signal: 'silence' } };
export const Done: Story = { args: { size: 240, phase: 'done', signal: 'silence' } };
export const Failed: Story = { args: { size: 240, phase: 'error', signal: 'silence' } };
export const Mini: Story = { args: { size: 48, phase: 'listening', signal: 'silence' } };
export const Badge: Story = { args: { size: 136, phase: 'listening', signal: 'silence', framing: 'badge' } };
export const BadgeSmall: Story = { args: { size: 32, phase: 'listening', signal: 'silence', framing: 'badge' } };
