/* eslint-disable react-refresh/only-export-components -- this module also exports
   TAB_ORDER, a constant array (not a primitive), so `allowConstantExport` doesn't
   cover it; it never changes on edit, so the fast-refresh warning doesn't apply. */
import { Alert, Box, Tabs } from '@mantine/core';
import { useState } from 'react';

import type { PermissionStatus, Settings, SettingsView } from '../../electron/types';

import { GeneralTab } from './GeneralTab';
import { GestureTab } from './GestureTab';
import { SetupTab } from './SetupTab';
import { TabRail } from './TabRail';

export type TabId = 'setup' | 'gesture' | 'general';
export const TAB_ORDER: TabId[] = ['setup', 'gesture', 'general'];

export function SettingsShell({
  settings,
  permissions,
  saveFailed,
  onChange,
}: {
  settings: SettingsView;
  permissions: PermissionStatus;
  saveFailed: boolean;
  onChange: (patch: Partial<Settings>) => void;
}) {
  const needsSetup = !permissions.microphone || !permissions.accessibility || !settings.hasApiKey;
  const [active, setActive] = useState<TabId>(needsSetup ? 'setup' : 'gesture');

  return (
    <Tabs
      orientation="vertical"
      variant="pills"
      radius="md"
      h="100vh"
      style={{ overflow: 'hidden' }}
      value={active}
      onChange={(value) => value && setActive(value as TabId)}
    >
      <TabRail needsSetup={needsSetup} />
      <Box flex={1} miw={0} p="xl" style={{ overflowY: 'auto' }}>
        {saveFailed && (
          <Alert color="red" variant="light" mb="md">
            Could not save settings
          </Alert>
        )}
        <Tabs.Panel value="setup">
          <SetupTab
            needsSetup={needsSetup}
            permissions={permissions}
            hasApiKey={settings.hasApiKey}
          />
        </Tabs.Panel>
        <Tabs.Panel value="gesture">
          <GestureTab settings={settings} onChange={onChange} />
        </Tabs.Panel>
        <Tabs.Panel value="general">
          <GeneralTab settings={settings} onChange={onChange} />
        </Tabs.Panel>
      </Box>
    </Tabs>
  );
}
