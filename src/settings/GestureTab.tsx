import { Box, Divider, SegmentedControl, Select, Stack, Text, Title } from '@mantine/core';

import {
  GESTURE_KEYS,
  type GestureKey,
  type Settings,
  type SettingsView,
  type TapCount,
} from '../../electron/types';

import { KEY_LABELS } from './gesture-keys';
import { StaggerGroup, StaggerItem } from './motion';
import classes from './settings.module.css';
import { SettingRow } from './SettingRow';

export function GestureTab({
  settings,
  onChange,
  bare = false,
}: {
  settings: SettingsView;
  onChange: (patch: Partial<Settings>) => void;
  /** Embedded in the wizard: skip the header the step already provides. */
  bare?: boolean;
}) {
  return (
    <StaggerGroup>
      <Stack gap="lg">
        {!bare && (
          <StaggerItem>
            <Box>
              <Title order={4}>Gesture</Title>
              <Text size="sm" c="dimmed" mt={4}>
                Tap the key, then hold the last press to talk. Release to paste. Esc cancels.
              </Text>
            </Box>
          </StaggerItem>
        )}
        <StaggerItem>
          <Box className={classes.glass} p="md">
            <Stack gap="md">
              <SettingRow label="Gesture key" description="Modifier keys only.">
                <Select
                  aria-label="Gesture key"
                  w={180}
                  allowDeselect={false}
                  data={GESTURE_KEYS.map(key => ({ value: key, label: KEY_LABELS[key] }))}
                  value={settings.gestureKey}
                  onChange={value => value && onChange({ gestureKey: value as GestureKey })}
                />
              </SettingRow>
              <Divider />
              <SettingRow
                label="Voice edit key"
                description={
                  settings.editGestureKey === settings.gestureKey
                    ? 'Off while it matches the gesture key.'
                    : 'Same presses. Say how to change the text in the field.'
                }
              >
                <Select
                  aria-label="Voice edit key"
                  w={180}
                  allowDeselect={false}
                  data={GESTURE_KEYS.map(key => ({ value: key, label: KEY_LABELS[key] }))}
                  value={settings.editGestureKey}
                  onChange={value => value && onChange({ editGestureKey: value as GestureKey })}
                />
              </SettingRow>
              <Divider />
              <SettingRow
                label="Explain key"
                description={
                  settings.explainGestureKey === settings.gestureKey ||
                  settings.explainGestureKey === settings.editGestureKey
                    ? 'Off while it matches another key.'
                    : 'Same presses. Select text anywhere and get a short explanation beside it.'
                }
              >
                <Select
                  aria-label="Explain key"
                  w={180}
                  allowDeselect={false}
                  data={GESTURE_KEYS.map(key => ({ value: key, label: KEY_LABELS[key] }))}
                  value={settings.explainGestureKey}
                  onChange={value => value && onChange({ explainGestureKey: value as GestureKey })}
                />
              </SettingRow>
              <Divider />
              <SettingRow label="Presses" description="The last one is held.">
                <SegmentedControl
                  w={180}
                  data={['2', '3', '4']}
                  value={String(settings.tapCount)}
                  onChange={value => onChange({ tapCount: Number(value) as TapCount })}
                />
              </SettingRow>
            </Stack>
          </Box>
        </StaggerItem>
      </Stack>
    </StaggerGroup>
  );
}
