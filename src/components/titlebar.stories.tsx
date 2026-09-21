import type { Meta, StoryObj } from '@storybook/react';

import { Box, Center, Code, Group, Paper, Text, UnstyledButton } from '@mantine/core';

import { Titlebar } from './titlebar';

/**
 * Frameless-window drag region (P11: platform viewport pattern).
 *
 * Renders nothing outside Electron — `isElectron` gates it. In the packaged
 * app it reserves macOS traffic-light space and marks itself
 * `app-region-drag`; anything inside must opt out with `no-drag` or it moves
 * the window instead of being clicked.
 *
 * These stories stub `@/lib/platform` via the `platformElectron` global arg so
 * both render paths are visible in a plain browser.
 */
const meta = {
  title: 'Shell/Layout/Titlebar',
  component: Titlebar,
  tags: ['autodocs'],
  parameters: { layout: 'fullscreen' },
  argTypes: {
    title: {
      control: 'text',
      description: 'Window title shown in the drag region. Defaults to the app name.',
      table: { type: { summary: 'string' } },
    },
  },
  // In a browser tab the real component returns null; document that here and
  // show an annotated mock of each platform variant instead.
  args: { title: 'Rocketship — acme-web' },
} satisfies Meta<typeof Titlebar>;

export default meta;
type Story = StoryObj<typeof Titlebar>;

export const InBrowser: Story = {
  name: 'Browser (renders null)',
  render: () => (
    <Box p="xl">
      <Titlebar />
      <Text size="sm" c="dimmed">
        Outside Electron <Code>&lt;Titlebar /&gt;</Code> returns null — the OS draws the title
        bar.
      </Text>
    </Box>
  ),
};

function MockTitlebar({ platform }: { platform: 'mac' | 'win' }) {
  return (
    <Paper withBorder radius="md" p={0} style={{ overflow: 'hidden' }}>
      {/* A mock of the real strip, drawn here so the story can show both
          platforms without an Electron main process. It reads the same tokens
          the component does — see `src/components/titlebar.tsx`. */}
      <Box
        px="xs"
        h={36}
        className="app-region-drag"
        style={{
          display: 'flex',
          alignItems: 'center',
          flexShrink: 0,
          borderBottom: '1px solid var(--mantine-color-default-border)',
          background: 'light-dark(var(--mantine-color-gray-0), var(--mantine-color-dark-9))',
          paddingLeft: platform === 'mac' ? 76 : undefined,
        }}
      >
        <Text size="xs" fw={500} c="dimmed" truncate>
          Rocketship — acme-web
        </Text>
        {platform === 'win' && (
          <Group gap={0} ml="auto" aria-hidden>
            <UnstyledButton w={40} ta="center">
              ─
            </UnstyledButton>
            <UnstyledButton w={40} ta="center">
              □
            </UnstyledButton>
            <UnstyledButton w={40} ta="center">
              ✕
            </UnstyledButton>
          </Group>
        )}
      </Box>
      <Center h={120}>
        <Text size="xs" c="dimmed">
          {platform === 'mac'
            ? 'Traffic lights live top-left; content starts after the inset.'
            : 'Window controls live top-right on Windows/Linux.'}
        </Text>
      </Center>
    </Paper>
  );
}

export const MacOsMock: Story = {
  name: 'macOS (traffic lights inset)',
  render: () => <MockTitlebar platform="mac" />,
};

export const WindowsMock: Story = {
  name: 'Windows/Linux (overlay controls)',
  render: () => <MockTitlebar platform="win" />,
};
