import { useRouterState } from '@tanstack/react-router';
import { ActionIcon, Box, Burger, Button, Divider, Group, Kbd, Text } from '@mantine/core';
import { Bell, PanelLeft, Search } from 'lucide-react';

import { useShellNav } from '@/hooks/use-shell-nav';
import { ThemeToggle } from '@/components/theme-toggle';
import { AccountMenu } from '@/components/account-menu';
import { openCommandPalette } from '@/components/command-palette';
import { pageTitleFor } from '@/config/nav';

/**
 * Sticky application header: sidebar toggle, page title, ⌘K, notifications,
 * theme.
 *
 * The one toggle became two, because the two states it used to switch between
 * are not the same state. On a narrow window the navbar is an overlay that is
 * open or closed, and a `Burger` is the control every user already reads as
 * that; wide, it is a column that is full-width or a rail, and it never
 * disappears. The kit's single `SidebarTrigger` hid the distinction behind a
 * media query.
 *
 * The `<header>` element is `AppShell.Header`'s, not this component's: two
 * nested banner landmarks is one more than the page has headers.
 */
export function Topbar() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const title = pageTitleFor(pathname);
  const { railed, mobileOpen, toggleRail, toggleMobile } = useShellNav();

  return (
    <Box
      px="md"
      h="100%"
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 'var(--mantine-spacing-xs)',
        flexShrink: 0,
        backdropFilter: 'blur(12px)',
        borderBottom: '1px solid var(--mantine-color-default-border)',
        // Mantine has no token for a translucent page, and the blur behind this
        // bar is the point — so the body colour is mixed with transparency
        // rather than replaced by a second surface token.
        background: 'color-mix(in oklab, var(--mantine-color-body) 80%, transparent)',
      }}
    >
      <Burger
        opened={mobileOpen}
        onClick={toggleMobile}
        size="sm"
        hiddenFrom="sm"
        aria-label="Toggle navigation"
      />
      <ActionIcon
        onClick={toggleRail}
        variant="subtle"
        color="gray"
        visibleFrom="sm"
        aria-label={railed ? 'Expand sidebar' : 'Collapse sidebar'}
        aria-expanded={!railed}
      >
        <PanelLeft size={16} />
      </ActionIcon>
      <Divider orientation="vertical" my={10} mr={4} />
      <Text component="h1" size="sm" fw={500}>
        {title}
      </Text>

      <Group gap={6} ml="auto" wrap="nowrap">
        {/* The search affordance is a Button, not an Input: it opens the
            spotlight rather than accepting text, and a box that looks like a
            field but cannot be typed into is the more expensive lie. */}
        <Button
          variant="default"
          size="xs"
          onClick={openCommandPalette}
          leftSection={<Search size={14} />}
          rightSection={<Kbd size="xs">⌘K</Kbd>}
          c="dimmed"
          visibleFrom="sm"
        >
          Search…
        </Button>
        <ActionIcon variant="subtle" color="gray" aria-label="Notifications">
          <Bell size={16} />
        </ActionIcon>
        <ThemeToggle />
        <Divider orientation="vertical" my={8} mx={4} />
        <AccountMenu />
      </Group>
    </Box>
  );
}
