import { zodResolver } from '@hookform/resolvers/zod';
import {
  Alert,
  Badge,
  Box,
  Button,
  Divider,
  Group,
  Loader,
  PasswordInput,
  SegmentedControl,
  Select,
  Stack,
  Switch,
  Tabs,
  Text,
  Textarea,
  ThemeIcon,
  Title,
} from '@mantine/core';
import type { ReactNode } from 'react';
import { Keyboard, Mic, ShieldCheck, SlidersHorizontal } from 'lucide-react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';

import { Panel } from '@/components/panel';

import { GESTURE_KEYS, type GestureKey, type PermissionKind, type TapCount } from '../../electron/types';

import {
  usePermissions,
  useRequestPermission,
  useSetApiKey,
  useSettings,
  useUpdateSettings,
} from './use-parley';

const KEY_LABELS: Record<GestureKey, string> = {
  AltRight: 'Right Option',
  Alt: 'Left Option',
  CtrlRight: 'Right Control',
  Ctrl: 'Left Control',
  ShiftRight: 'Right Shift',
  Shift: 'Left Shift',
  MetaRight: 'Right Command',
  Meta: 'Left Command',
};

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
          <Button type="submit" size="xs" loading={setApiKey.isPending}>
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

function SettingRow({
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

export function SettingsApp() {
  const settings = useSettings();
  const permissions = usePermissions();
  const update = useUpdateSettings();

  if (!settings.data || !permissions.data) {
    return (
      <Stack h="100vh" align="center" justify="center">
        <Loader />
      </Stack>
    );
  }

  const s = settings.data;
  const p = permissions.data;
  const needsSetup = !p.microphone || !p.accessibility || !s.hasApiKey;

  return (
    <Tabs
      orientation="vertical"
      variant="pills"
      radius="md"
      h="100vh"
      style={{ overflow: 'hidden' }}
      defaultValue={needsSetup ? 'setup' : 'gesture'}
    >
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

      <Box flex={1} miw={0} p="xl" style={{ overflowY: 'auto' }}>
        {update.isError && (
          <Alert color="red" variant="light" mb="md">
            Could not save settings
          </Alert>
        )}

        <Tabs.Panel value="setup">
          <Stack gap="lg">
            <Box>
              <Title order={4}>{needsSetup ? 'Finish setup' : 'Setup'}</Title>
              <Text size="sm" c="dimmed" mt={4}>
                Microphone to hear you, Accessibility to see the key and paste, a Groq key to
                transcribe.
              </Text>
            </Box>
            <Panel contentProps={{ p: 'md' }}>
              <Stack gap="sm">
                <PermissionRow kind="microphone" label="Microphone" granted={p.microphone} />
                <Divider />
                <PermissionRow
                  kind="accessibility"
                  label="Accessibility"
                  granted={p.accessibility}
                />
              </Stack>
            </Panel>
            <Panel contentProps={{ p: 'md' }}>
              <ApiKeySection hasApiKey={s.hasApiKey} />
            </Panel>
          </Stack>
        </Tabs.Panel>

        <Tabs.Panel value="gesture">
          <Stack gap="lg">
            <Box>
              <Title order={4}>Gesture</Title>
              <Text size="sm" c="dimmed" mt={4}>
                Tap the key, then hold the last press to talk. Release to paste. Esc cancels.
              </Text>
            </Box>
            <Panel contentProps={{ p: 'md' }}>
              <Stack gap="md">
                <SettingRow label="Gesture key" description="Modifier keys only.">
                  <Select
                    aria-label="Gesture key"
                    w={180}
                    allowDeselect={false}
                    data={GESTURE_KEYS.map((key) => ({ value: key, label: KEY_LABELS[key] }))}
                    value={s.gestureKey}
                    onChange={(value) => value && update.mutate({ gestureKey: value as GestureKey })}
                  />
                </SettingRow>
                <Divider />
                <SettingRow label="Presses" description="The last one is held.">
                  <SegmentedControl
                    w={180}
                    data={['2', '3', '4']}
                    value={String(s.tapCount)}
                    onChange={(value) => update.mutate({ tapCount: Number(value) as TapCount })}
                  />
                </SettingRow>
              </Stack>
            </Panel>
          </Stack>
        </Tabs.Panel>

        <Tabs.Panel value="general">
          <Stack gap="lg">
            <Title order={4}>General</Title>
            <Panel contentProps={{ p: 'md' }}>
              <Stack gap="md">
                <Switch
                  labelPosition="left"
                  label="Play a tick when recording stops"
                  checked={s.tickSound}
                  onChange={(event) => update.mutate({ tickSound: event.currentTarget.checked })}
                  styles={{ body: { justifyContent: 'space-between' } }}
                />
                <Divider />
                <Switch
                  labelPosition="left"
                  label="Launch at login"
                  checked={s.launchAtLogin}
                  onChange={(event) => update.mutate({ launchAtLogin: event.currentTarget.checked })}
                  styles={{ body: { justifyContent: 'space-between' } }}
                />
              </Stack>
            </Panel>
            {/* Saves on blur, not on change: it's free text typed keystroke by keystroke, so firing
                a mutation per character (like the toggles/select, where each change is a single
                discrete choice) would spam IPC and thrash the settings store. */}
            <Textarea
              label="Custom vocabulary"
              description="Names and jargon Whisper should recognise, separated by commas."
              rows={3}
              defaultValue={s.vocabulary}
              onBlur={(event) => {
                if (event.currentTarget.value !== s.vocabulary) {
                  update.mutate({ vocabulary: event.currentTarget.value });
                }
              }}
            />
          </Stack>
        </Tabs.Panel>
      </Box>
    </Tabs>
  );
}
