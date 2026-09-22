import { useEffect, useState } from 'react';
import { Loader, Stack } from '@mantine/core';

import { toast } from '@/lib/notify';
import type { SessionBlockedReason } from '../../electron/types';

import { MiniMaxOffer } from './MiniMaxOffer';
import { SettingsShell } from './SettingsShell';
import { Tour } from './tour/Tour';
import { usePermissions, useSettings, useUpdateSettings } from './use-parley';
import { stageFor } from './wizard/stage';
import { WizardShell } from './wizard/WizardShell';

const BLOCKED_MESSAGES: Record<Exclude<SessionBlockedReason, 'rewriteKey'>, string> = {
  microphone: 'Grant microphone access before trying the gesture.',
  accessibility: 'Grant Accessibility access before trying the gesture.',
  apiKey: 'Add a Groq API key before trying the gesture.',
};

export function SettingsApp() {
  const settings = useSettings();
  const permissions = usePermissions();
  const update = useUpdateSettings();

  const [offerOpen, setOfferOpen] = useState(false);

  // Session refuses a gesture silently when this window is already in
  // front — openSettings() is a no-op then, so this is the only signal. A
  // missing MiniMax key is the one refusal with a form to fix it in place.
  // When the refusal is what opened this window, the push had no listener
  // yet, so the reason is also taken once on mount.
  useEffect(() => {
    const onBlocked = (reason: SessionBlockedReason) => {
      if (reason === 'rewriteKey') setOfferOpen(true);
      else toast.error(BLOCKED_MESSAGES[reason]);
    };
    const off = window.parley.onSessionBlocked(onBlocked);
    void window.parley.takeBlockedReason().then(reason => reason && onBlocked(reason));
    return off;
  }, []);

  if (!settings.data || !permissions.data) {
    return (
      <Stack h="100vh" align="center" justify="center">
        <Loader />
      </Stack>
    );
  }

  // First run is a stage, not a tab: the flow, then the tabbed shell once
  // onboarding completes, with the tour only as a replay. Each stage
  // persists, so a quit resumes in place.
  const stage = stageFor(settings.data);

  return (
    <>
      {stage === 'tour' && <Tour onDone={() => update.mutate({ tourSeen: true })} />}
      {stage === 'wizard' && <WizardShell />}
      {stage === 'settings' && (
        <SettingsShell
          settings={settings.data}
          permissions={permissions.data}
          saveFailed={update.isError}
          onChange={patch => update.mutate(patch)}
        />
      )}
      <MiniMaxOffer
        opened={offerOpen}
        hasRewriteKey={settings.data.hasRewriteKey}
        onClose={() => setOfferOpen(false)}
      />
    </>
  );
}
