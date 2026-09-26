import { zodResolver } from '@hookform/resolvers/zod';
import {
  Alert,
  Badge,
  Box,
  Button,
  Code,
  Collapse,
  Group,
  Stack,
  Switch,
  Text,
  TextInput,
  Title,
} from '@mantine/core';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';

import type { Settings, SettingsView } from '../../electron/types';

import { Pressable, StaggerGroup, StaggerItem } from './motion';
import { SettingRow } from './SettingRow';
import { SettingsGroup } from './SettingsGroup';
import classes from './settings.module.css';
import {
  useAgentStatus,
  useDecideApproval,
  useRestartAgent,
  useSetAgentUrl,
  useTestAgent,
} from './use-parley';

/**
 * The agent behind act mode: is it up, what can a voice command reach, and
 * what is it doing right now. Capability and the safety contract lead;
 * server machinery waits under Advanced.
 */

const urlSchema = z.object({
  url: z
    .string()
    .trim()
    .min(1, 'Enter a URL')
    .refine(
      value => {
        try {
          const protocol = new URL(value).protocol;
          return protocol === 'http:' || protocol === 'https:';
        } catch {
          return false;
        }
      },
      { message: 'Use an http(s) URL' }
    ),
});
type UrlForm = z.infer<typeof urlSchema>;

function AgentUrlSection({ currentUrl }: { currentUrl: string }) {
  const save = useSetAgentUrl();
  const form = useForm<UrlForm>({
    resolver: zodResolver(urlSchema),
    defaultValues: { url: currentUrl },
  });
  const result = save.data;

  return (
    <form onSubmit={form.handleSubmit(({ url }) => save.mutate(url))}>
      <Stack gap="xs">
        <TextInput
          label="Agent URL"
          description="Local addresses start their own server; remote ones attach."
          placeholder="http://localhost:4111"
          error={form.formState.errors.url?.message}
          {...form.register('url')}
        />
        <Group gap="sm">
          <Pressable>
            <Button type="submit" size="xs" className={classes.primary} loading={save.isPending}>
              Save address
            </Button>
          </Pressable>
          {result && (
            <Text size="sm" c={result.ok ? 'teal' : 'red'}>
              {result.message}
            </Text>
          )}
        </Group>
        {save.isError && (
          <Alert color="red" variant="light">
            Could not save the address
          </Alert>
        )}
      </Stack>
    </form>
  );
}

export function AgentTab({
  settings,
  onChange,
}: {
  settings: SettingsView;
  onChange: (patch: Partial<Settings>) => void;
}) {
  // The polled status is the truth; the view is what the tab shows first.
  const status = useAgentStatus();
  const agent = status.data ?? settings.agent;
  const test = useTestAgent();
  const restart = useRestartAgent();
  const decide = useDecideApproval();
  const [advanced, setAdvanced] = useState(false);

  const tools = agent.mcpServers.reduce((total, server) => total + server.tools, 0);
  const capability =
    agent.mcpServers.length === 0
      ? 'No servers connected.'
      : `${agent.mcpServers.map(server => server.name).join(' · ')} · ${tools} tools`;
  const waiting = agent.currentRun?.status === 'awaiting_approval' ? agent.currentRun : null;
  const working = agent.currentRun?.status === 'working' ? agent.currentRun : null;

  return (
    <StaggerGroup>
      <Stack gap="lg">
        <StaggerItem>
          <Box>
            <Title order={4}>Agent</Title>
            <Text size="sm" c="dimmed" mt={4}>
              Voice commands run here.
            </Text>
          </Box>
        </StaggerItem>

        <StaggerItem>
          <SettingsGroup label="Status">
            <SettingRow
              label="Status"
              description={
                agent.serverState === 'online'
                  ? agent.managed
                    ? capability
                    : `Attached · ${capability}`
                  : agent.serverState === 'starting'
                    ? 'Warming up — voice commands wait.'
                    : 'Voice commands need it; dictation does not.'
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
                <Pressable>
                  <Button size="xs" variant="light" loading={test.isPending} onClick={() => test.mutate()}>
                    Test connection
                  </Button>
                </Pressable>
                {test.data && (
                  <Text size="sm" c={test.data.ok ? 'teal' : 'red'}>
                    {test.data.message}
                  </Text>
                )}
              </Group>
            </SettingRow>
            {working && (
              <SettingRow label="Working now" description={working.summary}>
                <Badge color="gray" variant="light">
                  Running
                </Badge>
              </SettingRow>
            )}
            {waiting && waiting.callId && (
              <SettingRow label="Waiting approval" description={waiting.summary}>
                <Group gap="xs" wrap="nowrap">
                  <Pressable>
                    <Button
                      size="xs"
                      className={classes.primary}
                      loading={decide.isPending && decide.variables?.approved === true}
                      onClick={() => waiting.callId && decide.mutate({ callId: waiting.callId, approved: true })}
                    >
                      Approve
                    </Button>
                  </Pressable>
                  <Button
                    size="xs"
                    variant="subtle"
                    loading={decide.isPending && decide.variables?.approved === false}
                    onClick={() => waiting.callId && decide.mutate({ callId: waiting.callId, approved: false })}
                  >
                    Decline
                  </Button>
                </Group>
              </SettingRow>
            )}
          </SettingsGroup>
          {decide.data === false && (
            <Text size="sm" c="dimmed" mt="sm">
              Already answered on the pill.
            </Text>
          )}
          {test.isError && (
            <Alert color="red" variant="light" mt="sm">
              Could not test the connection
            </Alert>
          )}
        </StaggerItem>

        <StaggerItem>
          <Stack gap={4}>
            <Text size="sm">Parley always asks before changing anything.</Text>
            <Text size="sm" c="dimmed">
              Try: <Code>book dentist Tuesday 9am</Code>
            </Text>
          </Stack>
        </StaggerItem>

        {agent.message && (
          <StaggerItem>
            <Alert color="red" variant="light">
              <Stack gap="xs" align="flex-start">
                <Text size="sm">{agent.message}</Text>
                <Button size="xs" variant="subtle" onClick={() => setAdvanced(true)}>
                  Open Advanced
                </Button>
              </Stack>
            </Alert>
          </StaggerItem>
        )}

        <StaggerItem>
          <SettingsGroup label="Server">
            <Box>
              <SettingRow
                label="Advanced"
                description="Server address, restart, auto-start."
              >
                <Button
                  size="xs"
                  variant="subtle"
                  aria-expanded={advanced}
                  onClick={() => setAdvanced(open => !open)}
                >
                  {advanced ? 'Hide Advanced' : 'Show Advanced'}
                </Button>
              </SettingRow>
              <Collapse expanded={advanced}>
                <Stack gap="md" px={14} pb="md">
                  <AgentUrlSection currentUrl={settings.agentUrl} />
                  <SettingRow
                    label="Restart"
                    description={
                      agent.managed
                        ? 'Stops and starts the server Parley runs.'
                        : 'Only the server Parley started can restart here.'
                    }
                  >
                    <Pressable>
                      <Button
                        size="xs"
                        variant="light"
                        disabled={!agent.managed}
                        loading={restart.isPending}
                        onClick={() => restart.mutate()}
                      >
                        Restart
                      </Button>
                    </Pressable>
                  </SettingRow>
                  <SettingRow
                    label="Start with Parley"
                    description="Off means attach-only, for debugging."
                  >
                    <Switch
                      aria-label="Start agent with Parley"
                      checked={settings.agentAutoStart}
                      onChange={event => onChange({ agentAutoStart: event.currentTarget.checked })}
                    />
                  </SettingRow>
                  {agent.mcpServers.map(server => (
                    <SettingRow key={server.name} label={server.name}>
                      <Badge color="teal" variant="light">
                        {server.tools} tools
                      </Badge>
                    </SettingRow>
                  ))}
                  {restart.isError && (
                    <Alert color="red" variant="light">
                      Could not restart the server
                    </Alert>
                  )}
                </Stack>
              </Collapse>
            </Box>
          </SettingsGroup>
        </StaggerItem>
      </Stack>
    </StaggerGroup>
  );
}
