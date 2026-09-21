import { Box, Divider, Stack, Switch, Textarea, Title } from '@mantine/core';

import type { Settings, SettingsView } from '../../electron/types';

import classes from './settings.module.css';

export function GeneralTab({
  settings,
  onChange,
}: {
  settings: SettingsView;
  onChange: (patch: Partial<Settings>) => void;
}) {
  return (
    <Stack gap="lg">
      <Title order={4}>General</Title>
      <Box className={classes.glass} p="md">
        <Stack gap="md">
          <Switch
            labelPosition="left"
            label="Play a tick when recording stops"
            checked={settings.tickSound}
            onChange={(event) => onChange({ tickSound: event.currentTarget.checked })}
            styles={{ body: { justifyContent: 'space-between' } }}
          />
          <Divider />
          <Switch
            labelPosition="left"
            label="Launch at login"
            checked={settings.launchAtLogin}
            onChange={(event) => onChange({ launchAtLogin: event.currentTarget.checked })}
            styles={{ body: { justifyContent: 'space-between' } }}
          />
        </Stack>
      </Box>
      {/* Saves on blur, not on change: it's free text typed keystroke by keystroke, so firing
          a mutation per character (like the toggles/select, where each change is a single
          discrete choice) would spam IPC and thrash the settings store. */}
      <Textarea
        label="Custom vocabulary"
        description="Names and jargon Whisper should recognise, separated by commas."
        rows={3}
        defaultValue={settings.vocabulary}
        onBlur={(event) => {
          if (event.currentTarget.value !== settings.vocabulary) {
            onChange({ vocabulary: event.currentTarget.value });
          }
        }}
      />
    </Stack>
  );
}
