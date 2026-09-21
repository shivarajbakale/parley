import { Loader, Stack } from '@mantine/core';

import { SettingsShell } from './SettingsShell';
import { usePermissions, useSettings, useUpdateSettings } from './use-parley';

export function SettingsApp() {
  const settings = useSettings();
  const permissions = usePermissions();
  const update = useUpdateSettings();

  if (!settings.data || !permissions.data) {
    return (
      <Stack h="100vh" align="center" justify="center">
        <Loader />
      </Stack>
    );
  }

  return (
    <SettingsShell
      settings={settings.data}
      permissions={permissions.data}
      saveFailed={update.isError}
      onChange={(patch) => update.mutate(patch)}
    />
  );
}
