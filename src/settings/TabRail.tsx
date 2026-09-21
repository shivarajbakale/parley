import { Box, Group, Tabs, Text, Title } from '@mantine/core';
import { Keyboard, ShieldCheck, SlidersHorizontal } from 'lucide-react';

import { SILENT_BANDS } from '../orb/bands';
import { OrbCanvas } from '../orb/OrbCanvas';

import classes from './settings.module.css';

const IDLE = () => ({ bands: SILENT_BANDS, phase: 'listening' as const });

export function TabRail({ needsSetup }: { needsSetup: boolean }) {
  return (
    <Tabs.List className={classes.rail}>
      <Group gap="xs" px="xs" pb="md" wrap="nowrap">
        <OrbCanvas size={48} running read={IDLE} />
        <Box miw={0}>
          <Title order={5}>Parley</Title>
          <Text size="xs" c={needsSetup ? 'yellow' : 'teal'}>
            {needsSetup ? 'Setup needed' : 'Ready'}
          </Text>
        </Box>
      </Group>
      <Tabs.Tab
        value="setup"
        leftSection={<ShieldCheck size={16} />}
        className={classes.tab}
        classNames={{ tabLabel: classes.tabLabel, tabSection: classes.tabLabel }}
        px="sm"
        py={8}
      >
        Setup
      </Tabs.Tab>
      <Tabs.Tab
        value="gesture"
        leftSection={<Keyboard size={16} />}
        className={classes.tab}
        classNames={{ tabLabel: classes.tabLabel, tabSection: classes.tabLabel }}
        px="sm"
        py={8}
      >
        Gesture
      </Tabs.Tab>
      <Tabs.Tab
        value="general"
        leftSection={<SlidersHorizontal size={16} />}
        className={classes.tab}
        classNames={{ tabLabel: classes.tabLabel, tabSection: classes.tabLabel }}
        px="sm"
        py={8}
      >
        General
      </Tabs.Tab>
    </Tabs.List>
  );
}
