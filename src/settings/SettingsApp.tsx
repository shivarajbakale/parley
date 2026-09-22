import { useEffect } from 'react';
import { Loader, Stack } from '@mantine/core';

import { toast } from '@/lib/notify';
import type { SessionBlockedReason } from '../../electron/types';

import { SettingsShell } from './SettingsShell';
import { Tour } from './tour/Tour';
import { usePermissions, useSettings, useUpdateSettings } from './use-parley';
import { stageFor } from './wizard/stage';
import { WizardShell } from './wizard/WizardShell';

const BLOCKED_MESSAGES: Record<SessionBlockedReason, string> = {
  microphone: 'Grant microphone access before trying the gesture.',
  accessibility: 'Grant Accessibility access before trying the gesture.',
  apiKey: 'Add a Groq API key before trying the gesture.',
  rewriteKey: 'Add a rewrite API key before trying voice edit.',
};

export function SettingsApp() {
  const settings = useSettings();
  const permissions = usePermissions();
  const update = useUpdateSettings();

  // Session refuses a gesture silently when this window is already in
  // front — openSettings() is a no-op then, so this is the only signal.
  useEffect(() => window.parley.onSessionBlocked((reason) => toast.error(BLOCKED_MESSAGES[reason])), []);

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
