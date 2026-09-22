import { Alert, Box, Tabs } from '@mantine/core';
import { useState, type CSSProperties } from 'react';

import type { PermissionStatus, Settings, SettingsView } from '../../electron/types';

import { GeneralTab } from './GeneralTab';
import { GestureTab } from './GestureTab';
import { PANEL_SHIFT_PX, tabDirection } from './motion-variants';
import classes from './settings.module.css';
import { SetupTab } from './SetupTab';
import { type TabId } from './tabs';
import { TabRail } from './TabRail';

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
  const [direction, setDirection] = useState<1 | -1>(1);

  const select = (next: TabId) => {
    setDirection(tabDirection(active, next));
    setActive(next);
  };

  // Panels stay mounted so a half-typed key survives a tab switch, which is why
  // the entrance is a CSS animation: it restarts by itself each time a hidden
  // panel is shown, where a spring started from `display: none` never ran.
  const panelStyle = { '--panel-shift': `${PANEL_SHIFT_PX * direction}px` } as CSSProperties;

  return (
    <Tabs
      orientation="vertical"
      variant={'unstyled' as 'default'}
      radius="md"
      className={classes.shell}
      value={active}
      onChange={(value) => value && select(value as TabId)}
    >
      <div className={classes.drag} aria-hidden="true" />
      <TabRail needsSetup={needsSetup} active={active} />
      <Box flex={1} miw={0} p="xl" style={{ overflowY: 'auto' }}>
        {saveFailed && (
          <Alert color="red" variant="light" mb="md">
            Could not save settings
          </Alert>
        )}
        <Tabs.Panel value="setup">
          <Box className={classes.panel} style={panelStyle}>
            <SetupTab
              needsSetup={needsSetup}
              permissions={permissions}
              hasApiKey={settings.hasApiKey}
              hasRewriteKey={settings.hasRewriteKey}
            />
          </Box>
        </Tabs.Panel>
        <Tabs.Panel value="gesture">
          <Box className={classes.panel} style={panelStyle}>
            <GestureTab settings={settings} onChange={onChange} />
          </Box>
        </Tabs.Panel>
        <Tabs.Panel value="general">
          <Box className={classes.panel} style={panelStyle}>
            <GeneralTab settings={settings} onChange={onChange} />
          </Box>
        </Tabs.Panel>
      </Box>
    </Tabs>
  );
}
