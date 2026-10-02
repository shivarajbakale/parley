import { zodResolver } from '@hookform/resolvers/zod';
import { Alert, Badge, Box, Button, Group, Stack, Switch, Text, TextInput, Title } from '@mantine/core';
import { useEffect, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';

import type { Settings, SettingsView } from '../../electron/types';

import { Pressable, StaggerGroup, StaggerItem } from './motion';
import { SettingRow } from './SettingRow';
import { SettingsGroup } from './SettingsGroup';
import classes from './settings.module.css';
import { useRefetchSettingsOnFocus, useSignInSync, useSignOutSync, useSyncNow } from './use-parley';

/**
 * Sync: this Mac signed in to a parley-api server, so the dictionary and
 * settings follow the user. Four states from the view: signed out, signing in
 * (the mutation), synced, and a standing error from the last run.
 */

const emailSchema = z.object({
  email: z.string().trim().email('Enter a valid email'),
});
type EmailForm = z.infer<typeof emailSchema>;

function isHttpUrl(value: string): boolean {
  try {
    const protocol = new URL(value).protocol;
    return protocol === 'http:' || protocol === 'https:';
  } catch {
    return false;
  }
}

const RELATIVE = new Intl.RelativeTimeFormat('en', { numeric: 'auto' });

/** "Never" for 0, "Just now" under a minute, then minutes, hours, days ago. */
function lastSyncLabel(at: number, now: number): string {
  if (!at) return 'Never';
  const seconds = Math.max(0, Math.round((now - at) / 1000));
  if (seconds < 60) return 'Just now';
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return RELATIVE.format(-minutes, 'minute');
  const hours = Math.round(minutes / 60);
  if (hours < 24) return RELATIVE.format(-hours, 'hour');
  return RELATIVE.format(-Math.round(hours / 24), 'day');
}

/** A clock that ticks every half minute, so "Just now" does not go stale on screen. */
function useNow(intervalMs = 30_000): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), intervalMs);
    return () => window.clearInterval(id);
  }, [intervalMs]);
  return now;
}

function SyncUrlField({
  currentUrl,
  onChange,
}: {
  currentUrl: string;
  onChange: (patch: Partial<Settings>) => void;
}) {
  const [error, setError] = useState<string | null>(null);
  // Saves on blur, like the vocabulary field: a mutation per keystroke would
  // rebuild the sync engine for every character.
  return (
    <TextInput
      label="Sync URL"
      description="The Parley server this Mac syncs with."
      placeholder="http://localhost:3100"
      defaultValue={currentUrl}
      error={error}
      onBlur={event => {
        const value = event.currentTarget.value.trim();
        if (!isHttpUrl(value)) {
          setError('Use an http(s) URL');
          return;
        }
        setError(null);
        if (value !== currentUrl) onChange({ syncUrl: value });
      }}
    />
  );
}

function SignInForm() {
  const signIn = useSignInSync();
  const form = useForm<EmailForm>({
    resolver: zodResolver(emailSchema),
    defaultValues: { email: '' },
  });
  const refused = signIn.data && !signIn.data.ok ? signIn.data.message : null;

  return (
    <form noValidate onSubmit={form.handleSubmit(({ email }) => signIn.mutate(email))}>
      <Stack gap="xs" className={classes.blockRow}>
        <TextInput
          label="Email"
          description="Use the same address on every device."
          placeholder="you@example.com"
          type="email"
          autoComplete="email"
          disabled={signIn.isPending}
          error={form.formState.errors.email?.message}
          {...form.register('email')}
        />
        <Group gap="sm">
          <Pressable>
            <Button type="submit" size="xs" className={classes.primary} loading={signIn.isPending}>
              Sign in
            </Button>
          </Pressable>
        </Group>
        {(refused || signIn.isError) && (
          <Alert color="red" variant="light">
            {refused ?? 'Could not reach the sync server'}
          </Alert>
        )}
      </Stack>
    </form>
  );
}

export function SyncTab({
  settings,
  onChange,
}: {
  settings: SettingsView;
  onChange: (patch: Partial<Settings>) => void;
}) {
  useRefetchSettingsOnFocus();
  const signOut = useSignOutSync();
  const syncNow = useSyncNow();
  const now = useNow();
  const signedIn = settings.hasSyncToken;
  const failed = signedIn && settings.syncLastError;

  return (
    <StaggerGroup>
      <Stack gap="lg">
        <StaggerItem>
          <Box>
            <Title order={4}>Sync</Title>
            <Text size="sm" c="dimmed" mt={4}>
              Your dictionary and settings follow you between devices. API keys stay on this Mac.
            </Text>
          </Box>
        </StaggerItem>

        {failed && (
          <StaggerItem>
            <Alert color="red" variant="light" role="alert" title="Last sync failed">
              <Stack gap={4}>
                <Text size="sm">{settings.syncLastError}</Text>
                <Text size="sm" c="dimmed">
                  Dictation keeps working; sync retries every five minutes.
                </Text>
              </Stack>
            </Alert>
          </StaggerItem>
        )}

        <StaggerItem>
          <SettingsGroup label="Account">
            {signedIn ? (
              <>
                <SettingRow label="Account">
                  <Group gap="xs" wrap="nowrap">
                    <Badge variant="light" color="teal" tt="none" maw={240} title={settings.syncEmail}>
                      {settings.syncEmail}
                    </Badge>
                    <Button
                      size="xs"
                      variant="subtle"
                      loading={signOut.isPending}
                      onClick={() => signOut.mutate()}
                    >
                      Sign out
                    </Button>
                  </Group>
                </SettingRow>
                <SettingRow label="Sync" description="Off pauses sync without signing out.">
                  <Switch
                    aria-label="Sync this Mac"
                    checked={settings.syncEnabled}
                    onChange={event => onChange({ syncEnabled: event.currentTarget.checked })}
                  />
                </SettingRow>
                <SettingRow label="Last sync" description={lastSyncLabel(settings.syncLastAt, now)}>
                  <Pressable>
                    <Button
                      size="xs"
                      variant="light"
                      loading={syncNow.isPending}
                      onClick={() => syncNow.mutate()}
                    >
                      Sync now
                    </Button>
                  </Pressable>
                </SettingRow>
              </>
            ) : (
              <SignInForm />
            )}
          </SettingsGroup>
          {signedIn && syncNow.data && (
            <Text size="sm" c="dimmed" mt="sm" px={14}>
              {syncNow.data.message}
            </Text>
          )}
          {signedIn && syncNow.isError && (
            <Alert color="red" variant="light" mt="sm">
              Could not run a sync
            </Alert>
          )}
          {signOut.isError && (
            <Alert color="red" variant="light" mt="sm">
              Could not sign out
            </Alert>
          )}
        </StaggerItem>

        <StaggerItem>
          <SettingsGroup label="Server">
            <Box className={classes.blockRow}>
              <SyncUrlField currentUrl={settings.syncUrl} onChange={onChange} />
            </Box>
          </SettingsGroup>
        </StaggerItem>
      </Stack>
    </StaggerGroup>
  );
}
