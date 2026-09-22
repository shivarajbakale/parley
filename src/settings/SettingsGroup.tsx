import { Box, Text } from '@mantine/core';
import { useId, type ReactNode } from 'react';

import classes from './settings.module.css';

/**
 * A labelled group of setting rows, as in macOS System Settings: a small
 * uppercase label over one card, the rows split by hairlines. Children are
 * rows — `SettingRow`, or a Box wrapping one with its inline extras.
 */
export function SettingsGroup({ label, children }: { label: string; children: ReactNode }) {
  const id = useId();
  return (
    <Box component="section" aria-labelledby={id}>
      <Text
        id={id}
        size="xs"
        fw={600}
        tt="uppercase"
        c="dimmed"
        px={14}
        mb={6}
        style={{ letterSpacing: '0.06em' }}
      >
        {label}
      </Text>
      <Box className={`${classes.glass} ${classes.group}`}>{children}</Box>
    </Box>
  );
}
