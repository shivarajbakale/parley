import { zodResolver } from '@hookform/resolvers/zod';
import {
  Alert,
  Badge,
  Box,
  Button,
  Divider,
  Group,
  PasswordInput,
  Stack,
  Text,
  Title,
} from '@mantine/core';
import { useForm } from 'react-hook-form';
import { z } from 'zod';

import type { PermissionKind, PermissionStatus } from '../../electron/types';

import classes from './settings.module.css';
import { useRequestPermission, useSetApiKey } from './use-parley';

const keySchema = z.object({ apiKey: z.string().trim().min(1, 'Enter your Groq API key') });
type KeyForm = z.infer<typeof keySchema>;

function PermissionRow({
  kind,
  label,
  granted,
}: {
  kind: PermissionKind;
  label: string;
  granted: boolean;
}) {
  const request = useRequestPermission();
  return (
    <Stack gap={4}>
      <Group justify="space-between">
        <Group gap="xs">
          <Text size="sm">{label}</Text>
          <Badge color={granted ? 'teal' : 'red'} variant="light">
            {granted ? 'Granted' : 'Missing'}
          </Badge>
        </Group>
        {!granted && (
          <Button
            size="xs"
            variant="light"
            loading={request.isPending}
            onClick={() => request.mutate(kind)}
          >
            Grant {label}
          </Button>
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

function ApiKeySection({ hasApiKey }: { hasApiKey: boolean }) {
  const setApiKey = useSetApiKey();
  const form = useForm<KeyForm>({ resolver: zodResolver(keySchema), defaultValues: { apiKey: '' } });
  const result = setApiKey.data;

  return (
    <form
      onSubmit={form.handleSubmit(({ apiKey }) =>
        setApiKey.mutate(apiKey, { onSuccess: (r) => r.ok && form.reset() })
      )}
    >
      <Stack gap="xs">
        <PasswordInput
          label="Groq API key"
          description={
            hasApiKey
              ? 'A key is stored in your Keychain. Enter a new one to replace it.'
              : 'Stored encrypted in your Keychain.'
          }
          placeholder="gsk_…"
          error={form.formState.errors.apiKey?.message}
          {...form.register('apiKey')}
        />
        <Group gap="sm">
          <Button type="submit" size="xs" className={classes.primary} loading={setApiKey.isPending}>
            Test and save
          </Button>
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

export function SetupTab({
  needsSetup,
  permissions,
  hasApiKey,
}: {
  needsSetup: boolean;
  permissions: PermissionStatus;
  hasApiKey: boolean;
}) {
  return (
    <Stack gap="lg">
      <Box>
        <Title order={4}>{needsSetup ? 'Finish setup' : 'Setup'}</Title>
        <Text size="sm" c="dimmed" mt={4}>
          Microphone to hear you, Accessibility to see the key and paste, a Groq key to
          transcribe.
        </Text>
      </Box>
      <Box className={classes.glass} p="md">
        <Stack gap="sm">
          <PermissionRow kind="microphone" label="Microphone" granted={permissions.microphone} />
          <Divider />
          <PermissionRow
            kind="accessibility"
            label="Accessibility"
            granted={permissions.accessibility}
          />
        </Stack>
      </Box>
      <Box className={classes.glass} p="md">
        <ApiKeySection hasApiKey={hasApiKey} />
      </Box>
    </Stack>
  );
}
