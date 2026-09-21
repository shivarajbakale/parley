import type { Meta, StoryObj } from '@storybook/react';
import { Moon, Sun } from 'lucide-react';

import { Group, Paper, Text } from '@mantine/core';

import { ThemeToggle } from './theme-toggle';

/**
 * Cycles between light and dark. The design system is dark-first; the
 * global toolbar `theme` global flips the surrounding ThemeProvider so
 * every theme story reads from the same source of truth.
 */
const meta = {
  title: 'Shell/Theme/Theme Toggle',
  component: ThemeToggle,
  tags: ['autodocs'],
  parameters: { layout: 'centered' },
  // ThemeToggle takes no props — variation is via the `theme` global type
  // declared in preview.tsx. The block is declared (rather than omitted) so
  // the story participates in the Controls panel standard alongside the
  // other shell stories.
  argTypes: {},
} satisfies Meta<typeof ThemeToggle>;

export default meta;
type Story = StoryObj<typeof ThemeToggle>;

/**
 * Canonical interactive cycle. Click the button to flip from dark → light
 * (or vice versa); the icon swaps to match.
 */
export const Default: Story = {
  render: () => (
    <Group gap="md">
      <ThemeToggle />
      <Text component="span" size="xs" c="dimmed">
        <Group gap={4} component="span" display="inline-flex">
          <Sun size={12} />/<Moon size={12} /> cycles
        </Group>
      </Text>
    </Group>
  ),
};

/** Toolbar global forces the dark theme. */
export const DarkTheme: Story = {
  globals: { theme: 'dark' },
  render: () => (
    <Group gap="md">
      <ThemeToggle />
      <Text component="span" size="xs" c="dimmed">forced dark</Text>
    </Group>
  ),
};

/** Toolbar global forces the light theme. */
export const LightTheme: Story = {
  globals: { theme: 'light' },
  render: () => (
    <Group gap="md">
      <ThemeToggle />
      <Text component="span" size="xs" c="dimmed">forced light</Text>
    </Group>
  ),
};

/** Toolbar global sets system — the toggle defers to prefers-color-scheme. */
export const SystemTheme: Story = {
  globals: { theme: 'system' },
  render: () => (
    <Group gap="md">
      <ThemeToggle />
      <Text component="span" size="xs" c="dimmed">system follows OS</Text>
    </Group>
  ),
};

/**
 * Real-world usage inside a Topbar-like wrapper. Shows the toggle sitting
 * next to a sidebar trigger on the dark surface it normally lives on.
 */
export const InContext: Story = {
  name: 'In context (topbar)',
  globals: { theme: 'dark' },
  render: () => (
    <>
      <Paper
        component="header"
        withBorder
        radius="md"
        px="md"
        h={56}
        w="100%"
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 'var(--mantine-spacing-xs)',
          backdropFilter: 'blur(12px)',
        }}
      >
        <Text component="h1" size="sm" fw={500}>Console</Text>
        <Group gap={6} ml="auto">
          <ThemeToggle />
        </Group>
      </Paper>
    </>
  ),
  parameters: { layout: 'fullscreen' },
};
