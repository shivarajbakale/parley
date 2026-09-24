import { Box, Button, Stack, Switch, Text, Textarea, Title } from '@mantine/core';

import type { Settings, SettingsView } from '../../electron/types';

import { Pressable, StaggerGroup, StaggerItem } from './motion';
import { PROVIDER_COPY, providerOf } from './providers';
import classes from './settings.module.css';
import { SettingRow } from './SettingRow';
import { SettingsGroup } from './SettingsGroup';
import { useUpdateSettings } from './use-parley';

export function GeneralTab({
  settings,
  onChange,
}: {
  settings: SettingsView;
  onChange: (patch: Partial<Settings>) => void;
}) {
  const replay = useUpdateSettings();
  return (
    <StaggerGroup>
      <Stack gap="lg">
        <StaggerItem>
          <Box>
            <Title order={4}>General</Title>
            <Text size="sm" c="dimmed" mt={4}>
              How Parley behaves on this Mac.
            </Text>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <SettingsGroup label="Behaviour">
            <SettingRow label="Sounds" description="A soft tick when recording starts and stops.">
              <Switch
                aria-label="Play sounds when recording starts and stops"
                checked={settings.tickSound}
                onChange={event => onChange({ tickSound: event.currentTarget.checked })}
              />
            </SettingRow>
            <SettingRow label="Launch at login" description="Parley starts in the menu bar.">
              <Switch
                aria-label="Launch at login"
                checked={settings.launchAtLogin}
                onChange={event => onChange({ launchAtLogin: event.currentTarget.checked })}
              />
            </SettingRow>
          </SettingsGroup>
        </StaggerItem>
        {/* Saves on blur, not on change: it's free text typed keystroke by keystroke, so firing
            a mutation per character (like the toggles/select, where each change is a single
            discrete choice) would spam IPC and thrash the settings store. */}
        <StaggerItem>
          <SettingsGroup label="Dictation">
            <Box className={classes.blockRow}>
              <Textarea
                label="Custom vocabulary"
                description={`Names and jargon ${PROVIDER_COPY[providerOf(settings)].listener} should recognise, separated by commas.`}
                placeholder="Parley, MiniMax, Groq"
                rows={3}
                defaultValue={settings.vocabulary}
                onBlur={event => {
                  if (event.currentTarget.value !== settings.vocabulary) {
                    onChange({ vocabulary: event.currentTarget.value });
                  }
                }}
              />
            </Box>
          </SettingsGroup>
        </StaggerItem>
        <StaggerItem>
          <SettingsGroup label="Help">
            <SettingRow label="Product tour" description="Watch the four-slide intro again.">
              <Pressable>
                <Button
                  size="xs"
                  variant="light"
                  loading={replay.isPending}
                  onClick={() => replay.mutate({ tourSeen: false })}
                >
                  Replay tour
                </Button>
              </Pressable>
            </SettingRow>
          </SettingsGroup>
        </StaggerItem>
      </Stack>
    </StaggerGroup>
  );
}
