import { Monitor, Moon, Sun } from 'lucide-react';
import { Controller, useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { toast } from '@/lib/notify';
import { Button, Group, SegmentedControl, Stack, Tabs, Text, TextInput } from '@mantine/core';

import { useSession } from '@/lib/auth';
import { useTheme } from '@/components/theme-provider';
import { PageShell } from '@/components/page-shell';
import { Panel } from '@/components/panel';

/**
 * Settings — tabbed rather than stacked.
 *
 * Three long sections on one page meant scrolling past what you didn't want.
 * Tabs keep every panel inside the viewport, which is the layout contract the
 * whole shell follows.
 *
 * The section chrome is the shared `Panel`. This page used to carry a private
 * copy of it at the bottom of the file — same header band, same divider, its
 * own idea of the danger tint — which is the drift `Panel` exists to prevent.
 */
const themes = [
  { value: 'light', label: 'Light', icon: Sun },
  { value: 'dark', label: 'Dark', icon: Moon },
  { value: 'system', label: 'System', icon: Monitor },
] as const;

const profileSchema = z.object({
  name: z.string().min(1, 'Name can’t be empty'),
  email: z.string().email('Enter a valid email'),
});

type ProfileValues = z.infer<typeof profileSchema>;

export function Settings() {
  const { data: session } = useSession();
  const { theme, setTheme } = useTheme();

  const { control, handleSubmit } = useForm<ProfileValues>({
    resolver: zodResolver(profileSchema),
    values: {
      name: session?.user?.name ?? '',
      email: session?.user?.email ?? '',
    },
  });

  return (
    <PageShell
      title="Settings"
      description="Manage your account and workspace preferences."
      archetype="form"
    >
      <Tabs defaultValue="profile">
        <Tabs.List mb="md">
          <Tabs.Tab value="profile">Profile</Tabs.Tab>
          <Tabs.Tab value="appearance">Appearance</Tabs.Tab>
          <Tabs.Tab value="danger">Danger zone</Tabs.Tab>
        </Tabs.List>

        <Tabs.Panel value="profile">
          <Panel title="Profile" description="Your personal information.">
            {/* Mantine's inputs own label, description and error, so each field
                is one component — and `Controller` is what hands them
                react-hook-form's value, since they are controlled rather than
                registerable refs. */}
            {/* The width lives on the <form>, not on the Stack inside it: the
                archetype rule measures the form element, and a 420px stack in a
                1196px form is a form the reader still has to track across. */}
            <form
              onSubmit={handleSubmit(() => toast.success('Profile saved'))}
              style={{ maxWidth: 420 }}
            >
              <Stack gap="md">
                <Controller
                  control={control}
                  name="name"
                  render={({ field, fieldState }) => (
                    <TextInput
                      label="Name"
                      placeholder="Your name"
                      error={fieldState.error?.message}
                      {...field}
                    />
                  )}
                />
                <Controller
                  control={control}
                  name="email"
                  render={({ field, fieldState }) => (
                    <TextInput
                      label="Email"
                      type="email"
                      placeholder="you@example.com"
                      description="Used for sign-in and notifications."
                      error={fieldState.error?.message}
                      {...field}
                    />
                  )}
                />
                <Group>
                  <Button type="submit" size="sm">
                    Save changes
                  </Button>
                </Group>
              </Stack>
            </form>
          </Panel>
        </Tabs.Panel>

        <Tabs.Panel value="appearance">
          <Panel title="Appearance" description="Customize how the console looks.">
            {/* Plain string labels. A `SegmentedControl` label neither wraps nor
                widens its control, so anything composed inside one — an icon, a
                count, a badge — is the thing that gets clipped. The icon lives
                beside the control instead. */}
            <Group gap="sm">
              <SegmentedControl
                value={theme}
                onChange={(value) => setTheme(value as (typeof themes)[number]['value'])}
                aria-label="Theme"
                data={themes.map((t) => ({ value: t.value, label: t.label }))}
              />
              <Text c="dimmed">
                {themes.map((t) =>
                  t.value === theme ? <t.icon key={t.value} size={16} /> : null
                )}
              </Text>
            </Group>
          </Panel>
        </Tabs.Panel>

        <Tabs.Panel value="danger">
          <Panel title="Danger zone" description="Irreversible actions." tone="danger">
            <Group justify="space-between" align="center" wrap="wrap">
              <div>
                <Text size="sm" fw={500}>
                  Delete workspace
                </Text>
                <Text size="sm" c="dimmed">
                  Permanently remove this workspace and its data.
                </Text>
              </div>
              <Button
                color="red"
                size="sm"
                onClick={() => toast.error('This is a demo — nothing was deleted.')}
              >
                Delete workspace
              </Button>
            </Group>
          </Panel>
        </Tabs.Panel>
      </Tabs>
    </PageShell>
  );
}
