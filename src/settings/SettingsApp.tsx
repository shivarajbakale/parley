import { Loader, Stack } from '@mantine/core';

import { SettingsShell } from './SettingsShell';
import { Tour } from './tour/Tour';
import { usePermissions, useSettings, useUpdateSettings } from './use-parley';
import { stageFor } from './wizard/stage';
import { WizardShell } from './wizard/WizardShell';

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

  // First run is a stage, not a tab: tour, then wizard, then the tabbed shell
  // once onboarding completes. Each stage persists, so a quit resumes in place.
  const stage = stageFor(settings.data);
  if (stage === 'tour') {
    return <Tour onDone={() => update.mutate({ tourSeen: true, wizardStep: 0 })} />;
  }
  if (stage === 'wizard') {
    return <WizardShell />;
  }

  return (
    <SettingsShell
      settings={settings.data}
      permissions={permissions.data}
      saveFailed={update.isError}
      onChange={patch => update.mutate(patch)}
    />
  );
}
