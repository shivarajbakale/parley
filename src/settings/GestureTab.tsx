import { Box, Divider, SegmentedControl, Select, Stack, Text, Title } from '@mantine/core';

import { GESTURE_KEYS, type GestureKey, type Settings, type SettingsView, type TapCount } from '../../electron/types';

import classes from './settings.module.css';
import { SettingRow } from './SettingRow';

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

export function GestureTab({
  settings,
  onChange,
}: {
  settings: SettingsView;
  onChange: (patch: Partial<Settings>) => void;
}) {
  return (
    <Stack gap="lg">
      <Box>
        <Title order={4}>Gesture</Title>
        <Text size="sm" c="dimmed" mt={4}>
          Tap the key, then hold the last press to talk. Release to paste. Esc cancels.
        </Text>
      </Box>
      <Box className={classes.glass} p="md">
        <Stack gap="md">
          <SettingRow label="Gesture key" description="Modifier keys only.">
            <Select
              aria-label="Gesture key"
              w={180}
              allowDeselect={false}
              data={GESTURE_KEYS.map((key) => ({ value: key, label: KEY_LABELS[key] }))}
              value={settings.gestureKey}
              onChange={(value) => value && onChange({ gestureKey: value as GestureKey })}
            />
          </SettingRow>
          <Divider />
          <SettingRow label="Presses" description="The last one is held.">
            <SegmentedControl
              w={180}
              data={['2', '3', '4']}
              value={String(settings.tapCount)}
              onChange={(value) => onChange({ tapCount: Number(value) as TapCount })}
            />
          </SettingRow>
        </Stack>
      </Box>
    </Stack>
  );
}
