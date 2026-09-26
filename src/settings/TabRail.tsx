import { Box, Group, Tabs, Text, Title } from '@mantine/core';
import { Bot, Gauge, Keyboard, SlidersHorizontal } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';

import { DURATION, EASE, SPRING } from '@/lib/motion';
import { TRAFFIC_LIGHT_INSET } from '@/lib/platform';

import { SILENT_BANDS } from '../orb/bands';
import { OrbCanvas } from '../orb/OrbCanvas';

import classes from './settings.module.css';
import type { TabId } from './tabs';

const IDLE = () => ({ bands: SILENT_BANDS, phase: 'listening' as const });
const RAIL_ORB_BOX = 32;
const RAIL_ORB = 64;

export function TabRail({ needsSetup, active }: { needsSetup: boolean; active: TabId }) {
  return (
    <Tabs.List className={classes.rail} pt={TRAFFIC_LIGHT_INSET ? 40 : undefined}>
      <Group gap="xs" px="xs" pb="md" wrap="nowrap">
        {/* The badge orb's body is half its canvas; the canvas overhangs the
            box so the glow has room without pushing the title aside. */}
        <Box pos="relative" w={RAIL_ORB_BOX} h={RAIL_ORB_BOX} flex="none" aria-hidden="true">
          <Box
            pos="absolute"
            top={(RAIL_ORB_BOX - RAIL_ORB) / 2}
            left={(RAIL_ORB_BOX - RAIL_ORB) / 2}
          >
            <OrbCanvas size={RAIL_ORB} framing="badge" running read={IDLE} />
          </Box>
        </Box>
        <Box miw={0}>
          <Title order={5}>Parley</Title>
          <AnimatePresence mode="wait" initial={false}>
            <motion.div
              key={needsSetup ? 'setup' : 'ready'}
              initial={{ opacity: 0, y: 4 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -4 }}
              transition={{ duration: DURATION.fast, ease: EASE }}
            >
              <Group gap={4} wrap="nowrap" c={needsSetup ? 'yellow' : 'teal'}>
                {!needsSetup && (
                  <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true">
                    <motion.path
                      d="M2 6.5 5 9.5 10 3"
                      stroke="currentColor"
                      strokeWidth="1.6"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      initial={{ pathLength: 0 }}
                      animate={{ pathLength: 1 }}
                      transition={{ duration: DURATION.slow, ease: EASE }}
                    />
                  </svg>
                )}
                <Text size="xs" c={needsSetup ? 'yellow' : 'teal'}>
                  {needsSetup ? 'Setup needed' : 'Ready'}
                </Text>
              </Group>
            </motion.div>
          </AnimatePresence>
        </Box>
      </Group>
      <Tabs.Tab
        value="overview"
        leftSection={<Gauge size={16} />}
        className={classes.tab}
        px="sm"
        py={8}
      >
        {active === 'overview' && (
          <motion.span layoutId="tab-pill" className={classes.pill} transition={SPRING} />
        )}
        Overview
      </Tabs.Tab>
      <Tabs.Tab
        value="gesture"
        leftSection={<Keyboard size={16} />}
        className={classes.tab}
        px="sm"
        py={8}
      >
        {active === 'gesture' && (
          <motion.span layoutId="tab-pill" className={classes.pill} transition={SPRING} />
        )}
        Gesture
      </Tabs.Tab>
      <Tabs.Tab
        value="general"
        leftSection={<SlidersHorizontal size={16} />}
        className={classes.tab}
        px="sm"
        py={8}
      >
        {active === 'general' && (
          <motion.span layoutId="tab-pill" className={classes.pill} transition={SPRING} />
        )}
        General
      </Tabs.Tab>
      <Tabs.Tab
        value="agent"
        leftSection={<Bot size={16} />}
        className={classes.tab}
        px="sm"
        py={8}
      >
        {active === 'agent' && (
          <motion.span layoutId="tab-pill" className={classes.pill} transition={SPRING} />
        )}
        Agent
      </Tabs.Tab>
    </Tabs.List>
  );
}
