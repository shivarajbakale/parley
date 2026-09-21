import { Box, Group, Text } from '@mantine/core';
import type { ReactNode } from 'react';

export function SettingRow({
  label,
  description,
  children,
}: {
  label: string;
  description?: string;
  children: ReactNode;
}) {
  return (
    <Group justify="space-between" wrap="nowrap" gap="xl">
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
