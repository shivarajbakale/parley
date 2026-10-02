import { Alert, Badge, Button, Group, Stack, Text } from '@mantine/core';
import { useEffect, useRef, useState } from 'react';

import type { PermissionKind } from '../../electron/types';

import { Pressable } from './motion';
import classes from './settings.module.css';
import { useRequestPermission } from './use-parley';

/* The permission row shared by the first-run flow and the Overview. */

export function PermissionRow({
  kind,
  label,
  granted,
}: {
  kind: PermissionKind;
  label: string;
  granted: boolean;
}) {
  const request = useRequestPermission();
  const wasGranted = useRef(granted);
  const [justGranted, setJustGranted] = useState(false);

  useEffect(() => {
    if (granted && !wasGranted.current) {
      setJustGranted(true);
      const timer = setTimeout(() => setJustGranted(false), 1200);
      wasGranted.current = granted;
      return () => clearTimeout(timer);
    }
    wasGranted.current = granted;
  }, [granted]);

  return (
    <Stack gap={4} className={justGranted ? classes.glow : undefined}>
      <Group justify="space-between">
        <Group gap="xs">
          <Text size="sm">{label}</Text>
          <Badge color={granted ? 'teal' : 'red'} variant="light">
            {granted ? 'Granted' : 'Missing'}
          </Badge>
        </Group>
        {!granted && (
          <Pressable>
            <Button
              size="xs"
              variant="light"
              loading={request.isPending}
              onClick={() => request.mutate(kind)}
            >
              Grant {label}
            </Button>
          </Pressable>
        )}
      </Group>
      {request.isError && (
        <Alert color="red" variant="light">
          Could not open System Settings
        </Alert>
      )}
    </Stack>
  );
}
