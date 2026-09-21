import { Link, useRouterState } from '@tanstack/react-router';
import { Box, Group, ScrollArea, Stack, Text, ThemeIcon, UnstyledButton } from '@mantine/core';

import { NavMain, type NavMainItem } from '@/components/nav-main';
import { NavUser } from '@/components/nav-user';
import { useShellNav } from '@/hooks/use-shell-nav';
import { navItems } from '@/config/nav';

/**
 * Everything inside the shell's navbar: workspace badge, primary navigation,
 * account block.
 *
 * It is a plain column now rather than a family of nine kit components. The
 * navbar's width, its position and its mobile behaviour belong to Mantine's
 * `AppShell` in `App.tsx`; what belongs here is the content and the one thing
 * the content has to know — whether it is being drawn in the rail.
 *
 * Items come from `src/config/nav.ts`, the single source of truth shared with
 * the ⌘K palette.
 */
export function AppSidebar() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { railed } = useShellNav();

  const navMain: NavMainItem[] = navItems.map((item) => ({
    title: item.title,
    url: item.to,
    icon: item.icon,
    isActive:
      item.to === '/'
        ? pathname === '/'
        : pathname === item.to || pathname.startsWith(`${item.to}/`),
  }));

  return (
    <Stack gap={0} h="100%" style={{ minHeight: 0, overflow: 'hidden' }}>
      <Box p="xs" style={{ borderBottom: '1px solid var(--mantine-color-default-border)' }}>
        <UnstyledButton
          component={Link}
          to="/"
          aria-label="Console home"
          p={6}
          style={{ borderRadius: 'var(--mantine-radius-md)', display: 'block' }}
        >
          <Group gap="sm" wrap="nowrap" justify={railed ? 'center' : undefined}>
            <ThemeIcon size={32} radius="md">
              <svg viewBox="0 0 32 32" width={16} height={16} fill="none">
                <path
                  d="M10 11.5L14.5 16L10 20.5"
                  stroke="currentColor"
                  strokeWidth="2.4"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <path d="M16.5 21H22" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
              </svg>
            </ThemeIcon>
            {!railed && (
              <Stack gap={0} style={{ minWidth: 0 }}>
                <Text size="sm" fw={600} truncate>
                  Console
                </Text>
                <Text size="xs" c="dimmed" truncate>
                  Pro workspace
                </Text>
              </Stack>
            )}
          </Group>
        </UnstyledButton>
      </Box>

      <ScrollArea style={{ flex: 1, minHeight: 0 }}>
        <NavMain items={navMain} railed={railed} />
      </ScrollArea>

      <Box p="xs" style={{ borderTop: '1px solid var(--mantine-color-default-border)' }}>
        <NavUser railed={railed} />
      </Box>
    </Stack>
  );
}
