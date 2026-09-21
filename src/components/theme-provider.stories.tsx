import type { Meta, StoryObj } from '@storybook/react';
import { Button, Code, Group, Paper, Text } from '@mantine/core';

import { ThemeProvider, useTheme } from './theme-provider';

/**
 * App-wide colour scheme. Not a visual component — this story documents the
 * contract: mount it once in `main.tsx`, read and flip through
 * `useTheme()`, and let Mantine own the stored choice.
 *
 * Every story in this Storybook already renders inside a provider, so the
 * toolbar switch works everywhere; these stories exist to show the three
 * starting positions and to prove `'system'` resolves rather than sticking.
 */
const meta = {
  title: 'Shell/Theme/Theme Provider',
  component: ThemeProvider,
  tags: ['autodocs'],
  parameters: { layout: 'centered' },
  argTypes: {
    defaultTheme: {
      control: { type: 'inline-radio' },
      options: ['dark', 'light', 'system'],
      description: "Starting scheme. 'system' is Mantine's 'auto'.",
      table: { category: 'Behaviour' },
    },
    storageKey: {
      control: { type: 'text' },
      description: 'localStorage key the choice is written to.',
      table: { category: 'Behaviour' },
    },
  },
} satisfies Meta<typeof ThemeProvider>;

export default meta;
type Story = StoryObj<typeof ThemeProvider>;

/** Reads the scheme back out of the provider and flips it, so a story proves
 *  both halves of the hook rather than only that it mounted. */
function CurrentTheme() {
  const { theme, setTheme } = useTheme();
  return (
    <Paper withBorder radius="md" p="md">
      <Group gap="sm">
        <Text size="sm">
          Active theme: <Code>{theme}</Code>
        </Text>
        <Button
          variant="default"
          size="xs"
          onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
        >
          Toggle to {theme === 'dark' ? 'light' : 'dark'}
        </Button>
      </Group>
    </Paper>
  );
}

/** Dark start, and the toggle that moves off it. */
export const ReadAndToggle: Story = {
  args: { defaultTheme: 'dark', storageKey: 'storybook-theme-provider-demo' },
  render: (args) => (
    <ThemeProvider {...args}>
      <CurrentTheme />
    </ThemeProvider>
  ),
};

/** Follows the OS. The label reads `system` while the paint follows the media
 *  query — the two are not the same value, which is the point of the story. */
export const SystemMode: Story = {
  args: { defaultTheme: 'system', storageKey: 'storybook-theme-provider-system' },
  render: (args) => (
    <ThemeProvider {...args}>
      <CurrentTheme />
    </ThemeProvider>
  ),
};

/** Light start — the app is dark-first, so this is the deliberate opt-out. */
export const LightExplicit: Story = {
  args: { defaultTheme: 'light', storageKey: 'storybook-theme-provider-light' },
  render: (args) => (
    <ThemeProvider {...args}>
      <CurrentTheme />
    </ThemeProvider>
  ),
};
