import { ChevronsUpDown, LogOut, Settings, Sparkles } from 'lucide-react';
import { useNavigate } from '@tanstack/react-router';
import { Avatar, Group, Menu, Stack, Text, UnstyledButton } from '@mantine/core';

import { useSession, signOut } from '@/lib/auth';

/**
 * Account menu pinned to the sidebar footer.
 *
 * Reads the current user from `@/lib/auth` (`useSession`). The shipped template
 * swaps that module for a local demo-session shim, so this component works
 * identically with or without a real backend.
 *
 * `railed` is the icon-only navbar. There is no room for a name and an email
 * there, so the trigger collapses to the avatar alone and the identity block
 * moves into the dropdown, which is where it was going to be read anyway.
 */
function Identity({ initials, name, email }: { initials: string; name: string; email: string }) {
  return (
    <Group gap="xs" wrap="nowrap" style={{ flex: 1, minWidth: 0 }}>
      <Avatar size={32} radius="md" color="brand" variant="light">
        <Text size="xs" fw={500}>
          {initials}
        </Text>
      </Avatar>
      <Stack gap={0} style={{ flex: 1, minWidth: 0, textAlign: 'left' }}>
        <Text size="sm" fw={500} truncate>
          {name}
        </Text>
        <Text size="xs" c="dimmed" truncate>
          {email}
        </Text>
      </Stack>
    </Group>
  );
}

export function NavUser({ railed = false }: { railed?: boolean }) {
  const { data: session } = useSession();
  const navigate = useNavigate();

  const name = session?.user?.name ?? 'User';
  const email = session?.user?.email ?? '';
  const initials =
    name
      .split(' ')
      .map((n) => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2) ||
    email[0]?.toUpperCase() ||
    '?';

  const handleSignOut = async () => {
    await signOut();
    navigate({ to: '/login' });
  };

  return (
    <Menu position="right-end" offset={8} width={224} withinPortal>
      <Menu.Target>
        <UnstyledButton
          p={6}
          w="100%"
          aria-label="Account menu"
          style={{ borderRadius: 'var(--mantine-radius-md)' }}
        >
          <Group gap="sm" wrap="nowrap" justify={railed ? 'center' : undefined}>
            {railed ? (
              <Avatar size={32} radius="md" color="brand" variant="light">
                <Text size="xs" fw={500}>
                  {initials}
                </Text>
              </Avatar>
            ) : (
              <>
                <Identity initials={initials} name={name} email={email} />
                <ChevronsUpDown size={16} style={{ flexShrink: 0 }} />
              </>
            )}
          </Group>
        </UnstyledButton>
      </Menu.Target>

      <Menu.Dropdown>
        <Menu.Label>
          <Group p={4}>
            <Identity initials={initials} name={name} email={email} />
          </Group>
        </Menu.Label>
        <Menu.Divider />
        <Menu.Item leftSection={<Sparkles size={16} />}>Upgrade plan</Menu.Item>
        <Menu.Divider />
        <Menu.Item
          leftSection={<Settings size={16} />}
          onClick={() => navigate({ to: '/settings' })}
        >
          Settings
        </Menu.Item>
        <Menu.Divider />
        <Menu.Item leftSection={<LogOut size={16} />} onClick={handleSignOut}>
          Log out
        </Menu.Item>
      </Menu.Dropdown>
    </Menu>
  );
}
