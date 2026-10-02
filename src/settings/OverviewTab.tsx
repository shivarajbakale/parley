import { Alert, Badge, Box, Button, Group, Stack, Text, Title } from '@mantine/core';

import type { PermissionKind, PermissionStatus, SettingsView } from '../../electron/types';
import { SILENT_BANDS } from '../orb/bands';
import { OrbCanvas } from '../orb/OrbCanvas';

import { KEY_LABELS } from './gesture-keys';
import { Pressable, StaggerGroup, StaggerItem } from './motion';
import { providerOf } from './providers';
import { transcriptionReady } from './server-readiness';
import { ServerSection } from './ServerStatus';
import { SettingRow } from './SettingRow';
import { SettingsGroup } from './SettingsGroup';
import type { TabId } from './tabs';
import { formatSaved, minutesSaved, TYPING_WPM } from './usage';
import { useRequestPermission, useServerStatus } from './use-parley';

/**
 * The settings window's first tab: is Parley working, what has it saved you,
 * and a one-click fix on whichever row is not green. Keys are not asked for:
 * they live in parley-api, and the Parley server group says what it holds.
 */

const ORB_BOX = 56;
const ORB = 80;
const readIdle = () => ({ bands: SILENT_BANDS, phase: 'listening' as const });

function PermissionFix({
  kind,
  label,
  granted,
  onGrant,
  pending,
}: {
  kind: PermissionKind;
  label: string;
  granted: boolean;
  onGrant(kind: PermissionKind): void;
  pending: boolean;
}) {
  if (granted) {
    return (
      <Badge color="teal" variant="light">
        Granted
      </Badge>
    );
  }
  return (
    <Pressable>
      <Button size="xs" variant="light" loading={pending} onClick={() => onGrant(kind)}>
        Grant {label}
      </Button>
    </Pressable>
  );
}

export function OverviewTab({
  settings,
  permissions,
  onSelectTab,
}: {
  settings: SettingsView;
  permissions: PermissionStatus;
  onSelectTab: (tab: TabId) => void;
}) {
  const request = useRequestPermission();
  const server = useServerStatus();
  const provider = providerOf(settings);

  // Unknown until the first check answers: not counted, so the title does not flicker.
  const serverMissing = server.data ? !transcriptionReady(server.data, provider) : false;
  const missing =
    Number(!permissions.microphone) + Number(!permissions.accessibility) + Number(serverMissing);
  const ready = missing === 0;
  const words = settings.wordsDictated ?? 0;
  // The agent answers readiness for voice commands only: dictation stays
  // ready while it is down, so its badge is never red.
  const agent = settings.agent;
  const agentTools = agent.mcpServers.reduce((total, server) => total + server.tools, 0);

  return (
    <StaggerGroup>
      <Stack gap="lg">
        <StaggerItem>
          <Group gap="md" wrap="nowrap">
            <Box pos="relative" w={ORB_BOX} h={ORB_BOX} flex="none" aria-hidden="true">
              <Box pos="absolute" top={(ORB_BOX - ORB) / 2} left={(ORB_BOX - ORB) / 2}>
                <OrbCanvas size={ORB} framing="badge" running read={readIdle} />
              </Box>
            </Box>
            <Box miw={0}>
              <Title order={3}>{ready ? 'Parley is ready' : 'Finish setup'}</Title>
              <Text size="sm" c="dimmed" mt={2}>
                {ready
                  ? `Tap ${KEY_LABELS[settings.gestureKey]} ${settings.tapCount - 1}× and hold in any app to talk.`
                  : `${missing === 1 ? 'One thing needs' : `${missing} things need`} you before the gesture works.`}
              </Text>
            </Box>
          </Group>
        </StaggerItem>

        <StaggerItem>
          <SettingsGroup label="Usage">
            <SettingRow
              label="Time saved"
              description={
                words > 0
                  ? `${words.toLocaleString()} words dictated, against typing at ${TYPING_WPM} words a minute.`
                  : 'Your first dictation starts the count.'
              }
            >
              {words > 0 && (
                <Text size="xl" fw={700}>
                  {formatSaved(minutesSaved(words))}
                </Text>
              )}
            </SettingRow>
          </SettingsGroup>
        </StaggerItem>

        <StaggerItem>
          <SettingsGroup label="Status">
            <SettingRow
              label="Microphone"
              description={
                permissions.microphone ? 'Live only while you hold the key.' : 'Parley cannot hear you yet.'
              }
            >
              <PermissionFix
                kind="microphone"
                label="Microphone"
                granted={permissions.microphone}
                onGrant={kind => request.mutate(kind)}
                pending={request.isPending && request.variables === 'microphone'}
              />
            </SettingRow>
            <SettingRow
              label="Accessibility"
              description={
                permissions.accessibility
                  ? 'Sees your key and pastes where the cursor is.'
                  : 'Needed to see your key and paste.'
              }
            >
              <PermissionFix
                kind="accessibility"
                label="Accessibility"
                granted={permissions.accessibility}
                onGrant={kind => request.mutate(kind)}
                pending={request.isPending && request.variables === 'accessibility'}
              />
            </SettingRow>
            <SettingRow
              label="Agent"
              description={
                agent.serverState === 'online'
                  ? agent.mcpServers.length === 0
                    ? 'Up, but no servers connected.'
                    : `${agent.mcpServers.map(server => server.name).join(' · ')} · ${agentTools} tools`
                  : agent.serverState === 'starting'
                    ? 'Warming up…'
                    : 'Needed for voice commands only.'
              }
            >
              <Group gap="xs" wrap="nowrap">
                <Badge
                  color={agent.serverState === 'online' ? 'teal' : agent.serverState === 'starting' ? 'yellow' : 'gray'}
                  variant="light"
                >
                  {agent.serverState === 'online'
                    ? 'Online'
                    : agent.serverState === 'starting'
                      ? 'Starting…'
                      : 'Offline'}
                </Badge>
                <Button size="xs" variant="subtle" onClick={() => onSelectTab('agent')}>
                  Open
                </Button>
              </Group>
            </SettingRow>
          </SettingsGroup>
          {request.isError && (
            <Alert color="red" variant="light" mt="sm">
              Could not open System Settings
            </Alert>
          )}
        </StaggerItem>

        <StaggerItem>
          <ServerSection provider={provider} />
        </StaggerItem>
      </Stack>
    </StaggerGroup>
  );
}
