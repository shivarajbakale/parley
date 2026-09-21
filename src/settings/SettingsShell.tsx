import { Alert, Box, Tabs } from '@mantine/core';
import { motion } from 'motion/react';
import { useState } from 'react';

import type { PermissionStatus, Settings, SettingsView } from '../../electron/types';

import { GeneralTab } from './GeneralTab';
import { GestureTab } from './GestureTab';
import { panelVariants, tabDirection } from './motion-variants';
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

  return (
    <Tabs
      orientation="vertical"
      variant={'unstyled' as 'default'}
      radius="md"
      className={classes.shell}
      value={active}
      onChange={(value) => value && select(value as TabId)}
    >
      <TabRail needsSetup={needsSetup} active={active} />
      <Box flex={1} miw={0} p="xl" style={{ overflowY: 'auto' }}>
        {saveFailed && (
          <Alert color="red" variant="light" mb="md">
            Could not save settings
          </Alert>
        )}
        <Tabs.Panel value="setup">
          <motion.div
            custom={direction}
            variants={panelVariants}
            initial={false}
            animate={active === 'setup' ? 'center' : 'enter'}
          >
            <SetupTab
              needsSetup={needsSetup}
              permissions={permissions}
              hasApiKey={settings.hasApiKey}
            />
          </motion.div>
        </Tabs.Panel>
        <Tabs.Panel value="gesture">
          <motion.div
            custom={direction}
            variants={panelVariants}
            initial={false}
            animate={active === 'gesture' ? 'center' : 'enter'}
          >
            <GestureTab settings={settings} onChange={onChange} />
          </motion.div>
        </Tabs.Panel>
        <Tabs.Panel value="general">
          <motion.div
            custom={direction}
            variants={panelVariants}
            initial={false}
            animate={active === 'general' ? 'center' : 'enter'}
          >
            <GeneralTab settings={settings} onChange={onChange} />
          </motion.div>
        </Tabs.Panel>
      </Box>
    </Tabs>
  );
}
