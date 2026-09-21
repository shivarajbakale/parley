import { shell, systemPreferences } from 'electron';

import type { PermissionKind, PermissionStatus } from './types';

const PANES: Record<PermissionKind, string> = {
  microphone: 'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone',
  accessibility: 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility',
};

export function getPermissions(): PermissionStatus {
  return {
    microphone: systemPreferences.getMediaAccessStatus('microphone') === 'granted',
    accessibility: systemPreferences.isTrustedAccessibilityClient(false),
  };
}

/**
 * Ask macOS for the permission. The microphone has a real prompt the first
 * time. Accessibility has no grant API, and a denied microphone never prompts
 * again, so in both cases the right System Settings pane is opened instead.
 */
export async function requestPermission(kind: PermissionKind): Promise<PermissionStatus> {
  if (kind === 'microphone') {
    const status = systemPreferences.getMediaAccessStatus('microphone');
    if (status === 'not-determined') await systemPreferences.askForMediaAccess('microphone');
    else if (status !== 'granted') await shell.openExternal(PANES.microphone);
  } else if (!systemPreferences.isTrustedAccessibilityClient(true)) {
    await shell.openExternal(PANES.accessibility);
  }
  return getPermissions();
}
