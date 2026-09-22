import { Box, Group, Text } from '@mantine/core';
import type { ReactNode } from 'react';

import classes from './settings.module.css';

/** One row of a `SettingsGroup`: label and reason on the left, the control on the right. */
export function SettingRow({
  label,
  description,
  children,
}: {
  label: string;
  description?: ReactNode;
  children: ReactNode;
}) {
  return (
    <Group className={classes.row} justify="space-between" wrap="nowrap" gap="xl">
      <Box miw={0}>
        <Text size="sm" fw={500}>
          {label}
        </Text>
        {description && (
          <Text size="xs" c="dimmed" mt={2}>
            {description}
          </Text>
        )}
      </Box>
      <Box flex="none">{children}</Box>
    </Group>
  );
}
