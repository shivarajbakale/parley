import { useEffect, useState } from 'react';
import { Loader, Stack } from '@mantine/core';

import { toast } from '@/lib/notify';
import type {
  AgentSummary,
  SessionBlockedReason,
  TranscriptionProvider,
} from '../../electron/types';

import { MiniMaxOffer } from './MiniMaxOffer';
import { PROVIDER_COPY, providerOf } from './providers';
import { SettingsShell } from './SettingsShell';
import type { TabId } from './tabs';
import { Tour } from './tour/Tour';
import { usePermissions, useSettings, useUpdateSettings } from './use-parley';
import { stageFor } from './wizard/stage';
import { WizardShell } from './wizard/WizardShell';

type ToastReason = Exclude<SessionBlockedReason, 'rewriteKey'>;

function blockedMessage(
  reason: ToastReason,
  provider: TranscriptionProvider,
  agent?: AgentSummary
): string {
  switch (reason) {
    case 'microphone':
      return 'Grant microphone access before trying the gesture.';
    case 'accessibility':
      return 'Grant Accessibility access before trying the gesture.';
    case 'apiKey':
      return `Add a ${PROVIDER_COPY[provider].keyLabel} before trying the gesture.`;
    case 'agent':
      return agent?.online
        ? 'Connect an MCP server before trying the gesture.'
        : 'Start the agent before trying the gesture.';
  }
}

export function SettingsApp() {
  const settings = useSettings();
  const permissions = usePermissions();
  const update = useUpdateSettings();

  const [offerOpen, setOfferOpen] = useState(false);
  // A refusal waits here until settings have loaded, so its message names the
  // selected provider's key. A new object per refusal, so a repeat shows again.
  const [blocked, setBlocked] = useState<{ reason: ToastReason } | null>(null);
  const [tabRequest, setTabRequest] = useState<{ tab: TabId; n: number } | null>(null);

  // Session refuses a gesture silently when this window is already in
  // front — openSettings() is a no-op then, so this is the only signal. A
  // missing MiniMax key is the one refusal with a form to fix it in place,
  // and a missing agent opens the tab that fixes it. When the refusal is
  // what opened this window, the push had no listener yet, so the reason is
  // also taken once on mount.
  useEffect(() => {
    const onBlocked = (reason: SessionBlockedReason) => {
      if (reason === 'rewriteKey') setOfferOpen(true);
      else {
        if (reason === 'agent') {
          setTabRequest(current => ({ tab: 'agent', n: (current?.n ?? 0) + 1 }));
        }
        setBlocked({ reason });
      }
    };
    const off = window.parley.onSessionBlocked(onBlocked);
    void window.parley.takeBlockedReason().then(reason => reason && onBlocked(reason));
    return off;
  }, []);

  useEffect(() => {
    if (!blocked || !settings.data) return;
    toast.error(blockedMessage(blocked.reason, providerOf(settings.data), settings.data.agent));
    setBlocked(null);
  }, [blocked, settings.data]);

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
          tabRequest={tabRequest}
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
