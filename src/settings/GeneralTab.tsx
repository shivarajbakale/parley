import { Box, Button, Divider, Stack, Switch, Textarea, Title } from '@mantine/core';

import type { Settings, SettingsView } from '../../electron/types';

import { Pressable, StaggerGroup, StaggerItem } from './motion';
import classes from './settings.module.css';
import { SettingRow } from './SettingRow';
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
          <Title order={4}>General</Title>
        </StaggerItem>
        <StaggerItem>
          <Box className={classes.glass} p="md">
            <Stack gap="md">
              <Switch
                labelPosition="left"
                label="Play sounds when recording starts and stops"
                checked={settings.tickSound}
                onChange={event => onChange({ tickSound: event.currentTarget.checked })}
                styles={{ body: { justifyContent: 'space-between' } }}
              />
              <Divider />
              <Switch
                labelPosition="left"
                label="Launch at login"
                checked={settings.launchAtLogin}
                onChange={event => onChange({ launchAtLogin: event.currentTarget.checked })}
                styles={{ body: { justifyContent: 'space-between' } }}
              />
            </Stack>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <Box className={classes.glass} p="md">
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
          </Box>
        </StaggerItem>
        {/* Saves on blur, not on change: it's free text typed keystroke by keystroke, so firing
            a mutation per character (like the toggles/select, where each change is a single
            discrete choice) would spam IPC and thrash the settings store. */}
        <StaggerItem>
          <Textarea
            label="Custom vocabulary"
            description="Names and jargon Whisper should recognise, separated by commas."
            rows={3}
            defaultValue={settings.vocabulary}
            onBlur={event => {
              if (event.currentTarget.value !== settings.vocabulary) {
                onChange({ vocabulary: event.currentTarget.value });
              }
            }}
          />
        </StaggerItem>
      </Stack>
    </StaggerGroup>
  );
}
