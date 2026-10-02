import {
  Alert,
  Badge,
  Box,
  Button,
  Code,
  Group,
  Loader,
  SegmentedControl,
  Stack,
  Text,
} from '@mantine/core';

import type { ServerStatus, TranscriptionProvider } from '../../electron/types';

import { PROVIDER_COPY, PROVIDER_OPTIONS } from './providers';
import { SettingRow } from './SettingRow';
import { SettingsGroup } from './SettingsGroup';
import { useServerStatus, useSetTranscriptionProvider } from './use-parley';

/*
 * The provider keys live in parley-api's .env, so the settings window never
 * asks for one. It shows whether the Parley server answers and which keys it
 * holds, and says where a missing one goes.
 */

/** Badge for one key: unknown while the server is down, never the key itself. */
function KeyBadge({ status, has }: { status: ServerStatus | undefined; has: boolean | undefined }) {
  if (!status) return <Loader size="xs" aria-label="Checking" />;
  if (!status.reachable) {
    return (
      <Badge color="gray" variant="light">
        Unknown
      </Badge>
    );
  }
  return (
    <Badge color={has ? 'teal' : 'red'} variant="light">
      {has ? 'On the server' : 'Not set'}
    </Badge>
  );
}

function MissingKey({ envVar }: { envVar: string }) {
  return (
    <Text size="xs" c="dimmed">
      Add <Code>{envVar}</Code> to parley-api/.env and restart the server.
    </Text>
  );
}

function ServerBadge({ status }: { status: ServerStatus | undefined }) {
  if (!status) return <Loader size="xs" aria-label="Checking the Parley server" />;
  return (
    <Badge color={status.reachable ? 'teal' : 'red'} variant="light">
      {status.reachable ? 'Running' : 'Not running'}
    </Badge>
  );
}

function NotRunning() {
  return (
    <Alert color="red" variant="light" title="Parley server not running">
      Start it with <Code>make api</Code> in the parley folder. Dictation, voice edit and Explain
      need it.
    </Alert>
  );
}

/** The Overview's Parley server group: the server, each key, and the provider switch. */
export function ServerSection({ provider }: { provider: TranscriptionProvider }) {
  const server = useServerStatus();
  const setProvider = useSetTranscriptionProvider();
  const status = server.data;
  const copy = PROVIDER_COPY[provider];
  const missing = (has: boolean | undefined) => Boolean(status?.reachable && !has);

  return (
    <Stack gap="sm">
      <SettingsGroup label="Parley server">
        <SettingRow label="Server" description={status?.url ?? 'Checking…'}>
          <Group gap="xs" wrap="nowrap">
            <ServerBadge status={status} />
            <Button
              size="xs"
              variant="subtle"
              loading={server.isFetching && Boolean(status)}
              onClick={() => void server.refetch()}
            >
              Check again
            </Button>
          </Group>
        </SettingRow>
        <Box>
          <SettingRow label="Transcription" description={`${copy.service} turns speech into text.`}>
            <KeyBadge status={status} has={status?.keys?.[provider]} />
          </SettingRow>
          <Stack gap="xs" px={14} pb="md">
            <SegmentedControl
              aria-label="Transcription provider"
              fullWidth
              data={PROVIDER_OPTIONS}
              value={provider}
              disabled={setProvider.isPending}
              onChange={value => setProvider.mutate(value as TranscriptionProvider)}
            />
            {setProvider.isError && (
              <Alert color="red" variant="light">
                Could not switch the transcription provider
              </Alert>
            )}
            {missing(status?.keys?.[provider]) && <MissingKey envVar={copy.envVar} />}
          </Stack>
        </Box>
        <Box>
          <SettingRow label="Voice edit and Act" description="MiniMax rewrites text and runs voice commands.">
            <KeyBadge status={status} has={status?.keys?.minimax} />
          </SettingRow>
          {missing(status?.keys?.minimax) && (
            <Box px={14} pb="md">
              <MissingKey envVar="MINIMAX_API_KEY" />
            </Box>
          )}
        </Box>
      </SettingsGroup>
      {status && !status.reachable && <NotRunning />}
    </Stack>
  );
}

/** The setup wizard's check: is the server up, and does it have the Groq key. */
export function ServerCheck({ provider }: { provider: TranscriptionProvider }) {
  const server = useServerStatus();
  const status = server.data;
  const copy = PROVIDER_COPY[provider];

  return (
    <Stack gap="sm">
      <Group justify="space-between" wrap="nowrap">
        <Text size="sm">Server</Text>
        <ServerBadge status={status} />
      </Group>
      <Group justify="space-between" wrap="nowrap">
        <Text size="sm">{copy.label} key</Text>
        <KeyBadge status={status} has={status?.keys?.[provider]} />
      </Group>
      {status && !status.reachable && <NotRunning />}
      {status?.reachable && !status.keys?.[provider] && <MissingKey envVar={copy.envVar} />}
      <Group>
        <Button
          size="xs"
          variant="light"
          loading={server.isFetching && Boolean(status)}
          onClick={() => void server.refetch()}
        >
          Check again
        </Button>
      </Group>
    </Stack>
  );
}
