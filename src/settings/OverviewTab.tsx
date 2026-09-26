import {
  Alert,
  Badge,
  Box,
  Button,
  Collapse,
  Group,
  SegmentedControl,
  Stack,
  Text,
  Title,
} from '@mantine/core';
import { useEffect, useRef, useState } from 'react';

import type {
  PermissionKind,
  PermissionStatus,
  SettingsView,
  TranscriptionProvider,
} from '../../electron/types';
import { SILENT_BANDS } from '../orb/bands';
import { OrbCanvas } from '../orb/OrbCanvas';

import { KEY_LABELS } from './gesture-keys';
import { Pressable, StaggerGroup, StaggerItem } from './motion';
import { PROVIDER_COPY, PROVIDER_OPTIONS, providerOf } from './providers';
import { SettingRow } from './SettingRow';
import { SettingsGroup } from './SettingsGroup';
import { ApiKeySection } from './SetupTab';
import type { TabId } from './tabs';
import { formatSaved, minutesSaved, TYPING_WPM } from './usage';
import {
  useRequestPermission,
  useSetApiKey,
  useSetDeepgramKey,
  useSetRewriteKey,
  useSetTranscriptionProvider,
} from './use-parley';

/**
 * The settings window's first tab: is Parley working, what has it saved you,
 * and a one-click fix on whichever row is not green. Key forms open inline
 * only when asked, and stay mounted so a half-typed key survives a tab switch.
 */

const ORB_BOX = 56;
const ORB = 80;
const readIdle = () => ({ bands: SILENT_BANDS, phase: 'listening' as const });

type KeyRow = 'transcription' | 'minimax';

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

function KeyFix({
  stored,
  optional,
  name,
  open,
  onToggle,
}: {
  stored: boolean;
  optional?: boolean;
  /** Spoken in the button's name, since two rows share its visible text. */
  name: string;
  open: boolean;
  onToggle(): void;
}) {
  return (
    <Group gap="xs" wrap="nowrap">
      <Badge color={stored ? 'teal' : optional ? 'gray' : 'red'} variant="light">
        {stored ? 'Stored' : optional ? 'Optional' : 'Missing'}
      </Badge>
      <Button
        size="xs"
        variant="subtle"
        aria-expanded={open}
        aria-label={`${stored ? 'Replace' : 'Add'} ${name}`}
        onClick={onToggle}
      >
        {open ? 'Hide' : stored ? 'Replace' : 'Add'}
      </Button>
    </Group>
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
  const setGroqKey = useSetApiKey();
  const setDeepgramKey = useSetDeepgramKey();
  const setRewriteKey = useSetRewriteKey();
  const setProvider = useSetTranscriptionProvider();
  const provider = providerOf(settings);
  const copy = PROVIDER_COPY[provider];
  // With no transcription key, its form is the fix, so it starts open.
  const [openKey, setOpenKey] = useState<KeyRow | null>(
    settings.hasApiKey ? null : 'transcription'
  );
  const toggle = (row: KeyRow) => setOpenKey(current => (current === row ? null : row));

  // A key that has just become stored closes its form; the row now says Stored.
  // Switching to a provider that already has a key is not "just stored": the
  // form stays open so the choice the user just made stays in view.
  const stored = useRef({
    transcription: settings.hasApiKey,
    minimax: settings.hasRewriteKey,
    provider,
  });
  useEffect(() => {
    const now = { transcription: settings.hasApiKey, minimax: settings.hasRewriteKey };
    const sameProvider = stored.current.provider === provider;
    for (const row of ['transcription', 'minimax'] as const) {
      if (row === 'transcription' && !sameProvider) continue;
      if (now[row] && !stored.current[row])
        setOpenKey(current => (current === row ? null : current));
    }
    stored.current = { ...now, provider };
  }, [settings.hasApiKey, settings.hasRewriteKey, provider]);

  const missing =
    Number(!permissions.microphone) + Number(!permissions.accessibility) + Number(!settings.hasApiKey);
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
            <Box>
              <SettingRow
                label="Transcription key"
                description={`${copy.service} turns speech into text.`}
              >
                <KeyFix
                  stored={settings.hasApiKey}
                  name="transcription key"
                  open={openKey === 'transcription'}
                  onToggle={() => toggle('transcription')}
                />
              </SettingRow>
              <Collapse expanded={openKey === 'transcription'}>
                <Stack gap="sm" px={14} pb="md">
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
                  {/* One form per provider: a half-typed Groq key must not be
                      submitted as a Deepgram key after a switch. */}
                  <ApiKeySection
                    key={provider}
                    label={copy.keyLabel}
                    placeholder={copy.placeholder}
                    purpose="Transcribes what you say."
                    submitLabel="Test and save"
                    hasApiKey={settings.hasApiKey}
                    setApiKey={provider === 'deepgram' ? setDeepgramKey : setGroqKey}
                  />
                </Stack>
              </Collapse>
            </Box>
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
            <Box>
              <SettingRow label="MiniMax key" description="Only for voice edit and Explain.">
                <KeyFix
                  stored={settings.hasRewriteKey}
                  optional
                  name="MiniMax key"
                  open={openKey === 'minimax'}
                  onToggle={() => toggle('minimax')}
                />
              </SettingRow>
              <Collapse expanded={openKey === 'minimax'}>
                <Box px={14} pb="md">
                  <ApiKeySection
                    label="MiniMax API key"
                    placeholder="Paste your key"
                    purpose="Used only for voice edit and Explain."
                    submitLabel="Test and save MiniMax key"
                    hasApiKey={settings.hasRewriteKey}
                    setApiKey={setRewriteKey}
                  />
                </Box>
              </Collapse>
            </Box>
          </SettingsGroup>
          {request.isError && (
            <Alert color="red" variant="light" mt="sm">
              Could not open System Settings
            </Alert>
          )}
        </StaggerItem>
      </Stack>
    </StaggerGroup>
  );
}
