import { Box, Group, Tabs, Text, ThemeIcon, Title } from '@mantine/core';
import { Keyboard, Mic, ShieldCheck, SlidersHorizontal } from 'lucide-react';

export function TabRail({ needsSetup }: { needsSetup: boolean }) {
  return (
    <Tabs.List w={190} p="md" bg="var(--mantine-color-default-hover)">
      <Group gap="xs" px="xs" pb="md" wrap="nowrap">
        <ThemeIcon size="lg" radius="md" variant="light">
          <Mic size={18} />
        </ThemeIcon>
        <Box miw={0}>
          <Title order={5}>Parley</Title>
          <Text size="xs" c={needsSetup ? 'yellow' : 'teal'}>
            {needsSetup ? 'Setup needed' : 'Ready'}
          </Text>
        </Box>
      </Group>
      <Tabs.Tab value="setup" leftSection={<ShieldCheck size={16} />}>
        Setup
      </Tabs.Tab>
      <Tabs.Tab value="gesture" leftSection={<Keyboard size={16} />}>
        Gesture
      </Tabs.Tab>
      <Tabs.Tab value="general" leftSection={<SlidersHorizontal size={16} />}>
        General
      </Tabs.Tab>
    </Tabs.List>
  );
}
