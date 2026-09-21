import { Alert, Box, Tabs } from '@mantine/core';
import { AnimatePresence, motion } from 'motion/react';
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
        <Tabs.Panel value={active}>
          <AnimatePresence mode="wait" custom={direction} initial={false}>
            <motion.div
              key={active}
              custom={direction}
              variants={panelVariants}
              initial="enter"
              animate="center"
              exit="exit"
            >
              {active === 'setup' && (
                <SetupTab
                  needsSetup={needsSetup}
                  permissions={permissions}
                  hasApiKey={settings.hasApiKey}
                />
              )}
              {active === 'gesture' && <GestureTab settings={settings} onChange={onChange} />}
              {active === 'general' && <GeneralTab settings={settings} onChange={onChange} />}
            </motion.div>
          </AnimatePresence>
        </Tabs.Panel>
      </Box>
    </Tabs>
  );
}
