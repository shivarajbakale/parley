import { Box, SegmentedControl, Select, Stack, Text, Title } from '@mantine/core';

import {
  GESTURE_KEYS,
  type GestureKey,
  type Settings,
  type SettingsView,
  type TapCount,
} from '../../electron/types';

import { KEY_LABELS } from './gesture-keys';
import { StaggerGroup, StaggerItem } from './motion';
import { SettingRow } from './SettingRow';
import { SettingsGroup } from './SettingsGroup';

/** The off copy names the key it collides with, like the voice edit row. */
function actDescription(settings: SettingsView): string {
  if (settings.actGestureKey === settings.gestureKey) return 'Off while it matches the dictate key.';
  if (settings.actGestureKey === settings.editGestureKey)
    return 'Off while it matches the voice edit key.';
  if (settings.actGestureKey === settings.explainGestureKey)
    return 'Off while it matches the Explain key.';
  return 'Speak a command for the agent instead of dictating.';
}

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
          <SettingsGroup label="Keys">
            <SettingRow label="Dictate" description="Modifier keys only.">
              <Select
                aria-label="Gesture key"
                w={180}
                allowDeselect={false}
                data={GESTURE_KEYS.map(key => ({ value: key, label: KEY_LABELS[key] }))}
                value={settings.gestureKey}
                onChange={value => value && onChange({ gestureKey: value as GestureKey })}
              />
            </SettingRow>
            <SettingRow
              label="Voice edit"
              description={
                settings.editGestureKey === settings.gestureKey
                  ? 'Off while it matches the dictate key.'
                  : 'Say how to change the text in the field.'
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
            <SettingRow
              label="Explain"
              description={
                settings.explainGestureKey === settings.gestureKey ||
                settings.explainGestureKey === settings.editGestureKey
                  ? 'Off while it matches another key.'
                  : 'Select text anywhere and get a short explanation beside it.'
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
            <SettingRow label="Act" description={actDescription(settings)}>
              <Select
                aria-label="Act key"
                w={180}
                allowDeselect={false}
                data={GESTURE_KEYS.map(key => ({ value: key, label: KEY_LABELS[key] }))}
                value={settings.actGestureKey}
                onChange={value => value && onChange({ actGestureKey: value as GestureKey })}
              />
            </SettingRow>
          </SettingsGroup>
        </StaggerItem>
        <StaggerItem>
          <SettingsGroup label="Timing">
            <SettingRow label="Presses" description="Every key uses the same count; the last press is held.">
              <SegmentedControl
                w={180}
                data={['2', '3', '4']}
                value={String(settings.tapCount)}
                onChange={value => onChange({ tapCount: Number(value) as TapCount })}
              />
            </SettingRow>
          </SettingsGroup>
        </StaggerItem>
      </Stack>
    </StaggerGroup>
  );
}
