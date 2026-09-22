import { zodResolver } from '@hookform/resolvers/zod';
import { Alert, Badge, Button, Group, PasswordInput, Stack, Text } from '@mantine/core';
import { useEffect, useRef, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';

import type { PermissionKind } from '../../electron/types';

import { Pressable } from './motion';
import classes from './settings.module.css';
import { useRequestPermission, useSetApiKey } from './use-parley';

/*
 * The permission row and key form shared by the first-run flow, the Overview
 * and the MiniMax offer.
 */

const keySchema = (label: string) =>
  z.object({ apiKey: z.string().trim().min(1, `Enter your ${label}`) });
type KeyForm = z.infer<ReturnType<typeof keySchema>>;

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

export function ApiKeySection({
  label,
  placeholder,
  purpose,
  submitLabel,
  hasApiKey,
  setApiKey,
}: {
  label: string;
  placeholder: string;
  /** What the key is for, shown until one is stored. */
  purpose: string;
  /** Two key forms share the tab, so each button names itself. */
  submitLabel: string;
  hasApiKey: boolean;
  setApiKey: ReturnType<typeof useSetApiKey>;
}) {
  const form = useForm<KeyForm>({
    resolver: zodResolver(keySchema(label)),
    defaultValues: { apiKey: '' },
  });
  const result = setApiKey.data;

  return (
    <form
      onSubmit={form.handleSubmit(({ apiKey }) =>
        setApiKey.mutate(apiKey, { onSuccess: r => r.ok && form.reset() })
      )}
    >
      <Stack gap="xs">
        <PasswordInput
          label={label}
          description={
            hasApiKey
              ? 'A key is stored in your Keychain. Enter a new one to replace it.'
              : `${purpose} Stored encrypted in your Keychain.`
          }
          placeholder={placeholder}
          error={form.formState.errors.apiKey?.message}
          {...form.register('apiKey')}
        />
        <Group gap="sm">
          <Pressable>
            <Button
              type="submit"
              size="xs"
              className={classes.primary}
              loading={setApiKey.isPending}
            >
              {submitLabel}
            </Button>
          </Pressable>
          {result && (
            <Text size="sm" c={result.ok ? 'teal' : 'red'}>
              {result.message}
            </Text>
          )}
        </Group>
        {setApiKey.isError && (
          <Alert color="red" variant="light">
            Could not test the key
          </Alert>
        )}
      </Stack>
    </form>
  );
}
