import type React from 'react';
import { AppShell, Box, Flex } from '@mantine/core';

import { AppSidebar } from '../src/components/app-sidebar';
import { Topbar } from '../src/components/topbar';
import { CommandPalette } from '../src/components/command-palette';
import { Titlebar } from '../src/components/titlebar';
import { NAVBAR_WIDTH } from '../src/hooks/use-shell-nav';

/**
 * Wraps a story in a navbar-shaped column.
 *
 * The shell's navigation state is a module-level store now
 * (`src/hooks/use-shell-nav.ts`) rather than a React context, so nothing here
 * has to be a descendant of a provider — this decorator exists only to give a
 * navbar piece the width it is drawn at. Pair with `withMemoryRouter`.
 */
export const withSidebar =
  (Story: React.ComponentType) =>
  (
    <Box h="100svh" w={NAVBAR_WIDTH}>
      <Story />
    </Box>
  );

/**
 * Bundles the entire authenticated chrome — Titlebar + AppShell + AppSidebar +
 * Topbar + CommandPalette — around the Story. The Titlebar is the desktop-only
 * frameless drag region; it renders null outside Electron, so a story in a
 * browser tab shows the same chrome the packaged app has minus that strip. For
 * composition stories only (the per-piece stories still use withSidebar /
 * withMemoryRouter). The Story renders inside <main> with an `lg` gutter,
 * intended to be a PageShell child or a fixture dashboard layout.
 *
 * Each piece can be turned off independently (showSidebar / showTopbar /
 * showCommandPalette) so a story can isolate one chrome piece.
 */
export const withAppShell =
  (
    opts: {
      initialPath?: string;
      showSidebar?: boolean;
      showTopbar?: boolean;
      showCommandPalette?: boolean;
      showTitlebar?: boolean;
    } = {}
  ) =>
  (Story: React.ComponentType): React.ReactElement => (
    <Flex direction="column" h="100svh" style={{ overflow: 'hidden' }}>
      {opts.showTitlebar !== false && <Titlebar />}
      <AppShell
        header={{ height: 56 }}
        navbar={{ width: NAVBAR_WIDTH, breakpoint: 'sm', collapsed: { mobile: true } }}
        padding={0}
        style={{ flex: 1, minHeight: 0, overflow: 'hidden' }}
      >
        {opts.showTopbar !== false && (
          <AppShell.Header withBorder={false} pos="absolute">
            <Topbar />
          </AppShell.Header>
        )}
        {opts.showSidebar !== false && (
          <AppShell.Navbar pos="absolute">
            <AppSidebar />
          </AppShell.Navbar>
        )}
        <AppShell.Main h="100%" style={{ overflow: 'hidden' }}>
          <Box component="main" h="100%" p="lg" style={{ minHeight: 0, overflow: 'hidden' }}>
            <Story />
          </Box>
        </AppShell.Main>
      </AppShell>
      {opts.showCommandPalette !== false && <CommandPalette />}
    </Flex>
  );
