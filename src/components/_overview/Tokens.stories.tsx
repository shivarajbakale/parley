import type { Meta, StoryObj } from '@storybook/react';
import { Box, Group, Paper, SimpleGrid, Stack, Text, Title } from '@mantine/core';


/** The brand ramp Mantine derives from the theme's `brand` colour. */
const BRAND_SHADES = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

/** Surfaces, in the order they stack: page, panel, control. */
const SURFACES = [
  { token: '--mantine-color-body', label: 'Page', note: 'The ground everything sits on.' },
  { token: '--app-surface', label: 'Surface', note: 'Paper, Card, Menu — one step up.' },
  { token: '--app-control', label: 'Control', note: 'A control that appears on both.' },
];

const SEMANTIC = [
  { token: '--mantine-primary-color-filled', label: 'Primary' },
  { token: '--mantine-color-green-filled', label: 'Success' },
  { token: '--mantine-color-yellow-filled', label: 'Warning' },
  { token: '--mantine-color-red-filled', label: 'Danger' },
];

const RADII = ['xs', 'sm', 'md', 'lg', 'xl'] as const;
const SHADOWS = ['xs', 'sm', 'md', 'lg', 'xl'] as const;
const SPACING = ['xs', 'sm', 'md', 'lg', 'xl'] as const;

function Swatch({ token, label, note }: { token: string; label: string; note?: string }) {
  return (
    <Stack gap={4}>
      <Paper
        withBorder
        radius="md"
        p="sm"
        h={80}
        bg={`var(${token})`}
        style={{ display: 'flex', alignItems: 'flex-end' }}
      >
        <Text size="xs" fw={600} ff="monospace">
          {label}
        </Text>
      </Paper>
      <Text size="xs" c="dimmed" ff="monospace">
        {token}
      </Text>
      {note && (
        <Text size="xs" c="dimmed">
          {note}
        </Text>
      )}
    </Stack>
  );
}

function SectionHeader({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <Stack gap={4}>
      <Title order={2} size="h4">
        {title}
      </Title>
      <Text size="sm" c="dimmed">
        {children}
      </Text>
    </Stack>
  );
}

/**
 * Design tokens — the CSS variables every surface in this app paints with.
 *
 * They are Mantine's, generated from `src/theme.ts`: change the theme and this
 * page changes with it. There are exactly two of our own, `--app-surface` and
 * `--app-control`, because Mantine paints Paper with the page colour and this
 * starter is built on a raised surface instead (see `cssVariablesResolver` in
 * the theme).
 *
 * The Toolbar `Theme` toggle flips the whole grid between dark and light. A
 * component should spend the token, never the literal — `add-ui-component`
 * rejects an inline hex/rgb/oklch in a component for that reason.
 */
const meta = {
  title: 'Overview/Tokens',
  parameters: { layout: 'fullscreen' },
  tags: ['autodocs'],
} satisfies Meta;

export default meta;
type Story = StoryObj;

export const Surfaces: Story = {
  name: 'Surfaces',
  render: () => (
    <Stack gap="md" p="lg">
      <SectionHeader title="Surfaces">
        Three steps, and no more: the page, the panel raised off it, and the control
        that has to read on either.
      </SectionHeader>
      <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="sm">
        {SURFACES.map(s => (
          <Swatch key={s.token} token={s.token} label={s.label} note={s.note} />
        ))}
      </SimpleGrid>
    </Stack>
  ),
};

export const Brand: Story = {
  name: 'Brand ramp',
  render: () => (
    <Stack gap="md" p="lg">
      <SectionHeader title="Brand ramp">
        Mantine derives ten shades from the theme's `brand` colour. Components spend
        a shade through a variant — `variant="light"` is the tint, `filled` is 6.
      </SectionHeader>
      <SimpleGrid cols={{ base: 5, md: 10 }} spacing="xs">
        {BRAND_SHADES.map(i => (
          <Stack key={i} gap={4}>
            <Box h={56} bg={`var(--mantine-color-brand-${i})`} style={{ borderRadius: 'var(--mantine-radius-sm)' }} />
            <Text size="xs" c="dimmed" ta="center" ff="monospace">
              {i}
            </Text>
          </Stack>
        ))}
      </SimpleGrid>
      <SimpleGrid cols={{ base: 2, md: 4 }} spacing="sm">
        {SEMANTIC.map(s => (
          <Swatch key={s.token} token={s.token} label={s.label} />
        ))}
      </SimpleGrid>
    </Stack>
  ),
};

export const Radii: Story = {
  name: 'Radii',
  render: () => (
    <Stack gap="md" p="lg">
      <SectionHeader title="Radii">
        `theme.defaultRadius` picks which one a component reaches for; the scale is
        what a component may choose between.
      </SectionHeader>
      <Group gap="lg" align="flex-start" wrap="wrap">
        {RADII.map(r => (
          <Stack key={r} gap={6}>
            <Paper withBorder w={80} h={80} radius={r} />
            <Text size="xs" c="dimmed" ff="monospace">
              --mantine-radius-{r}
            </Text>
          </Stack>
        ))}
      </Group>
    </Stack>
  ),
};

export const Elevation: Story = {
  name: 'Elevation',
  render: () => (
    <Stack gap="md" p="lg">
      <SectionHeader title="Elevation">
        A shadow means the thing floats above the page — a menu, a modal, a
        dragged row. A panel that merely sits on the page takes a border instead.
      </SectionHeader>
      <Group gap="lg" wrap="wrap">
        {SHADOWS.map(s => (
          <Stack key={s} gap={6}>
            <Paper w={110} h={80} radius="md" shadow={s} />
            <Text size="xs" c="dimmed" ff="monospace">
              --mantine-shadow-{s}
            </Text>
          </Stack>
        ))}
      </Group>
    </Stack>
  ),
};

export const Spacing: Story = {
  name: 'Spacing',
  render: () => (
    <Stack gap="md" p="lg">
      <SectionHeader title="Spacing">
        The same scale answers `gap`, `p` and `m`. A layout that needs a value off
        this scale is usually a layout that wants a different component.
      </SectionHeader>
      <Stack gap="sm">
        {SPACING.map(s => (
          <Group key={s} gap="sm" align="center">
            <Text size="xs" c="dimmed" ff="monospace" w={140}>
              --mantine-spacing-{s}
            </Text>
            <Box
              h={16}
              w={`var(--mantine-spacing-${s})`}
              bg="var(--mantine-primary-color-filled)"
              style={{ borderRadius: 'var(--mantine-radius-xs)' }}
            />
          </Group>
        ))}
      </Stack>
    </Stack>
  ),
};
