import { zodResolver } from '@hookform/resolvers/zod';
import {
  Alert,
  Badge,
  Button,
  Divider,
  Group,
  Loader,
  PasswordInput,
  ScrollArea,
  SegmentedControl,
  Select,
  Stack,
  Switch,
  Text,
  Textarea,
  Title,
} from '@mantine/core';
import { useForm } from 'react-hook-form';
import { z } from 'zod';

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
      </Stack>
    </form>
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
    <ScrollArea h="100vh">
      <Stack p="lg" gap="md">
        <Title order={3}>Parley</Title>

        {needsSetup && (
          <Alert color="yellow" title="Finish setup">
            Parley needs the microphone to hear you, Accessibility to see the gesture key and paste
            for you, and a Groq API key to transcribe.
          </Alert>
        )}

        <Divider label="Permissions" labelPosition="left" />
        <PermissionRow kind="microphone" label="Microphone" granted={p.microphone} />
        <PermissionRow kind="accessibility" label="Accessibility" granted={p.accessibility} />

        <Divider label="Transcription" labelPosition="left" />
        <ApiKeySection hasApiKey={s.hasApiKey} />
        <Textarea
          label="Custom vocabulary"
          description="Names and jargon Whisper should recognise, separated by commas."
          autosize
          minRows={2}
          maxRows={4}
          defaultValue={s.vocabulary}
          onBlur={(event) => {
            if (event.currentTarget.value !== s.vocabulary) {
              update.mutate({ vocabulary: event.currentTarget.value });
            }
          }}
        />

        <Divider label="Gesture" labelPosition="left" />
        <Text size="sm" c="dimmed">
          Tap the key, then hold the last press to talk. Release to paste. Esc cancels.
        </Text>
        <Select
          label="Gesture key"
          allowDeselect={false}
          data={GESTURE_KEYS.map((key) => ({ value: key, label: KEY_LABELS[key] }))}
          value={s.gestureKey}
          onChange={(value) => value && update.mutate({ gestureKey: value as GestureKey })}
        />
        <Stack gap={4}>
          <Text size="sm" fw={500}>
            Presses (the last one is held)
          </Text>
          <SegmentedControl
            data={['2', '3', '4']}
            value={String(s.tapCount)}
            onChange={(value) => update.mutate({ tapCount: Number(value) as TapCount })}
          />
        </Stack>

        <Divider label="General" labelPosition="left" />
        <Switch
          label="Play a tick when recording stops"
          checked={s.tickSound}
          onChange={(event) => update.mutate({ tickSound: event.currentTarget.checked })}
        />
        <Switch
          label="Launch at login"
          checked={s.launchAtLogin}
          onChange={(event) => update.mutate({ launchAtLogin: event.currentTarget.checked })}
        />
      </Stack>
    </ScrollArea>
  );
}
