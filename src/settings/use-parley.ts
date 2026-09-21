import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import type { PermissionKind, Settings } from '../../electron/types';

/**
 * Query hooks over `window.parley`. IPC is this window's "server", so it gets
 * the same treatment as server data: no bridge calls from a component.
 */

const SETTINGS = ['parley', 'settings'] as const;
const PERMISSIONS = ['parley', 'permissions'] as const;

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

export function useSetRewriteKey() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (key: string) => window.parley.setRewriteKey(key),
    onSuccess: () => client.invalidateQueries({ queryKey: SETTINGS }),
  });
}
