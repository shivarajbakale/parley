import { useEffect } from 'react';
import { Outlet, useRouterState } from '@tanstack/react-router';
import { AppShell, Box, Flex } from '@mantine/core';
import { useHotkey } from '@tanstack/react-hotkeys';
import './App.css';
import { AppSidebar } from '@/components/app-sidebar';
import { Titlebar } from '@/components/titlebar';
import { Topbar } from '@/components/topbar';
import { CommandPalette } from '@/components/command-palette';
import { AuthGuard } from '@/components/auth/AuthGuard';
import { NAVBAR_RAIL_WIDTH, NAVBAR_WIDTH, useShellNav } from '@/hooks/use-shell-nav';
import { pageTitleFor } from '@/config/nav';

/**
 * Application shell.
 *
 * Public routes (auth) render bare. Everything else renders inside the
 * authenticated chrome: custom titlebar + Mantine `AppShell` with a collapsible
 * navbar, a sticky header and the ⌘K palette.
 *
 * The shell is a **fixed viewport** — `100svh` with `overflow: hidden` all the
 * way down. Nothing here scrolls; pages scroll internally through `PageShell`,
 * which keeps headers and toolbars pinned. This matters more in a desktop app
 * than on the web: a window that scrolls as a whole reads as a web page in a
 * box. Adding `overflowY: 'auto'` here or in a page fails
 * `scripts/ui-lint.mjs`.
 *
 * The titlebar sits *above* the AppShell rather than inside it, because it is
 * window chrome: it must span the full width, and on macOS it reserves the
 * traffic-light inset. `AppShell` is given the remaining height, which is why
 * the layout is a flex column here and a grid inside.
 *
 * The navbar has three widths, not two: full, rail, and gone. `railed` swaps
 * the first two on desktop (⌘B, or the topbar control); `mobileOpen` is the
 * third, where Mantine draws the navbar as an overlay over the page and the
 * route change closes it, because navigating is the point of opening it.
 */
const PUBLIC_ROUTES = ['/login', '/signup'];

function App() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const isPublic = PUBLIC_ROUTES.includes(pathname);
  const { railed, mobileOpen, toggleRail, closeMobile } = useShellNav();

  // `ignoreInputs` is explicit because the default would change behaviour: it
  // is off for Command/Control chords, and Mantine's `useHotkeys` — which owned
  // this binding before — ignored input, textarea and select unconditionally.
  // A rail that collapses under someone mid-sentence is not an improvement, and
  // ⌘B is bold inside anything editable.
  useHotkey('Mod+B', toggleRail, {
    ignoreInputs: true,
    meta: { name: 'Toggle the sidebar', description: 'Collapse the navigation to a rail' },
  });

  useEffect(() => {
    closeMobile();
  }, [pathname, closeMobile]);

  if (isPublic) {
    return (
      <Flex direction="column" h="100svh" style={{ overflow: 'hidden' }}>
        <Titlebar />
        <Box style={{ flex: 1, minHeight: 0 }}>
          <Outlet />
        </Box>
      </Flex>
    );
  }

  return (
    <AuthGuard>
      <Flex direction="column" h="100svh" style={{ overflow: 'hidden' }}>
        <Titlebar title={pageTitleFor(pathname)} />
        <AppShell
          header={{ height: 56 }}
          navbar={{
            width: railed ? NAVBAR_RAIL_WIDTH : NAVBAR_WIDTH,
            breakpoint: 'sm',
            collapsed: { mobile: !mobileOpen },
          }}
          padding={0}
          style={{ flex: 1, minHeight: 0, overflow: 'hidden' }}
        >
          <AppShell.Header withBorder={false} pos="absolute">
            <Topbar />
          </AppShell.Header>
          <AppShell.Navbar pos="absolute">
            <AppSidebar />
          </AppShell.Navbar>
          <AppShell.Main h="100%" style={{ overflow: 'hidden' }}>
            <Box component="main" h="100%" style={{ minHeight: 0, overflow: 'hidden' }}>
              <Outlet />
            </Box>
          </AppShell.Main>
        </AppShell>
        <CommandPalette />
      </Flex>
    </AuthGuard>
  );
}

export default App;
