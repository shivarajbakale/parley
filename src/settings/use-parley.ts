import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect } from 'react';

import type { PermissionKind, Settings, TranscriptionProvider } from '../../electron/types';

/**
 * Query hooks over `window.parley`. IPC is this window's "server", so it gets
 * the same treatment as server data: no bridge calls from a component.
 */

const SETTINGS = ['parley', 'settings'] as const;
const PERMISSIONS = ['parley', 'permissions'] as const;
const AGENT_STATUS = ['parley', 'agent', 'status'] as const;

export function useSettings() {
  return useQuery({ queryKey: SETTINGS, queryFn: () => window.parley.getSettings() });
}

export function useUpdateSettings() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (patch: Partial<Settings>) => window.parley.updateSettings(patch),
    onSuccess: (view) => client.setQueryData(SETTINGS, view),
  });
}

/** Polled, because permissions are granted in System Settings, outside the app. */
export function usePermissions() {
  return useQuery({
    queryKey: PERMISSIONS,
    queryFn: () => window.parley.getPermissions(),
    refetchInterval: 2000,
  });
}

export function useRequestPermission() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (kind: PermissionKind) => window.parley.requestPermission(kind),
    onSuccess: (status) => client.setQueryData(PERMISSIONS, status),
  });
}

export function useSetApiKey() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (key: string) => window.parley.setApiKey(key),
    onSuccess: () => client.invalidateQueries({ queryKey: SETTINGS }),
  });
}

export function useSetDeepgramKey() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (key: string) => window.parley.setDeepgramKey(key),
    onSuccess: () => client.invalidateQueries({ queryKey: SETTINGS }),
  });
}

/** Readiness follows the provider, so the new view replaces the cached one. */
export function useSetTranscriptionProvider() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (provider: TranscriptionProvider) =>
      window.parley.setTranscriptionProvider(provider),
    onSuccess: view => client.setQueryData(SETTINGS, view),
  });
}

export function useSetRewriteKey() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (key: string) => window.parley.setRewriteKey(key),
    onSuccess: () => client.invalidateQueries({ queryKey: SETTINGS }),
  });
}

/** Polled, because the supervisor starts, crashes and restarts on its own. */
export function useAgentStatus() {
  return useQuery({
    queryKey: AGENT_STATUS,
    queryFn: () => window.parley.agentStatus(),
    refetchInterval: 2000,
  });
}

export function useSetAgentUrl() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (url: string) => window.parley.setAgentUrl(url),
    onSuccess: () => {
      client.invalidateQueries({ queryKey: SETTINGS });
      client.invalidateQueries({ queryKey: AGENT_STATUS });
    },
  });
}

export function useTestAgent() {
  return useMutation({ mutationFn: () => window.parley.testAgent() });
}

export function useRestartAgent() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: () => window.parley.restartAgent(),
    onSuccess: () => client.invalidateQueries({ queryKey: AGENT_STATUS }),
  });
}

export function useDecideApproval() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ callId, approved }: { callId: string; approved: boolean }) =>
      window.parley.decideApproval(callId, approved),
    onSuccess: () => client.invalidateQueries({ queryKey: AGENT_STATUS }),
  });
}

export function useSignInSync() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (email: string) => window.parley.signInSync(email),
    onSuccess: () => client.invalidateQueries({ queryKey: SETTINGS }),
  });
}

export function useSignOutSync() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: () => window.parley.signOutSync(),
    onSuccess: view => client.setQueryData(SETTINGS, view),
  });
}

/** Settled either way: a failed run still stamps syncLastError in main. */
export function useSyncNow() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: () => window.parley.syncNow(),
    onSettled: () => client.invalidateQueries({ queryKey: SETTINGS }),
  });
}

/**
 * Main never pushes a scheduled sync's result to this window, so the view is
 * re-read whenever the window comes back to the front. TanStack's own focus
 * refetch listens to visibilitychange, which a window raised from behind
 * another app does not fire.
 */
export function useRefetchSettingsOnFocus() {
  const client = useQueryClient();
  useEffect(() => {
    const onFocus = () => void client.invalidateQueries({ queryKey: SETTINGS });
    window.addEventListener('focus', onFocus);
    return () => window.removeEventListener('focus', onFocus);
  }, [client]);
}
