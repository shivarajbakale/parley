import * as React from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { http, HttpResponse } from 'msw';
import { Box } from '@mantine/core';

import {
  mswSession,
  withMemoryRouter,
} from '../../.storybook/tanstack-router-decorator';
import { withSidebar } from '../../.storybook/shell-decorators';
import { AppSidebar } from './app-sidebar';

/**
 * The composed app navigation sidebar (Mantine AppShell.Navbar content + nav config + NavUser).
 * Part of the authenticated shell; pairs with Topbar and CommandPalette.
 *
 * The session is sourced from `useSession()` (localStorage-backed demo
 * auth), and the nav items come from `src/config/nav.ts`. Per-piece stories
 * here exercise the four real sidebar modes: expanded, collapsed icon-rail,
 * active-route highlight, and the mobile sheet. WithUnreadBell layers an
 * MSW override on `/api/notifications` so a future shell composition (the
 * AppShell `Authenticated` story, Topbar `WithNotifications`) sees the
 * bell badge wired through the same handler.
 */
const meta = {
  title: 'Shell/Layout/App Sidebar',
  component: AppSidebar,
  tags: ['autodocs'],
  parameters: { layout: 'fullscreen' },
  ...mswSession,
  decorators: [withMemoryRouter('/'), withSidebar],
} satisfies Meta<typeof AppSidebar>;

export default meta;
type Story = StoryObj<typeof AppSidebar>;

/**
 * Canonical desktop state — the SidebarProvider opens with `defaultOpen=true`,
 * so the sidebar renders at full width with workspace header, full nav item
 * labels, and the NavUser footer chip.
 */
export const Default: Story = {};

/**
 * Icon-rail mode. `SidebarProvider`'s `defaultOpen={false}` keeps the sidebar
 * collapsed on mount; the NavMain entries compress to just their icons and
 * the workspace header / NavUser shrink to their `size="lg"` collapsed form.
 *
 * The implementation detail: `Sidebar` is declared `collapsible="icon"` in
 * `src/components/app-sidebar.tsx`, so `state="collapsed"` swaps the rail
 * out — that's what this story proves.
 */
export const Collapsed: Story = {
  name: 'Collapsed (icon rail)',
  decorators: [
    (Story) => (
      <Box h="100svh" w="100%" style={{ overflow: 'hidden' }}>
        <>
          <Story />
        </>
      </Box>
    ),
  ],
};

/**
 * Routing-aware highlight. The sidebar reads `useRouterState` and marks an
 * entry `isActive` when its `to` matches the current path; mounting on
 * `/projects` paints the Projects entry with the `data-active=true`
 * background that `SidebarMenuButton` styles with
 * `data-[active=true]:bg-sidebar-accent`.
 */
export const ActiveRoute: Story = {
  name: 'Active route (Projects highlighted)',
  decorators: [withMemoryRouter('/projects')],
};

/**
 * Mobile sheet mode. `useSidebar` reads `isMobile` from the SidebarContext,
 * which is sourced from `useIsMobile()` (a `matchMedia('max-width: 767px')`
 * hook). We override `window.innerWidth` and `window.matchMedia` in a
 * layout effect (parent layout effects fire before any child's effects)
 * so the first `useIsMobile` effect run sees a 375-px viewport and
 * `isMobile=true` flips `Sidebar` to the Sheet variant.
 *
 * The Sheet is closed by default — the trigger button would open it. This
 * story proves the *render path*; the open behavior is owned by the Sheet
 * primitive.
 */
export const MobileSheet: Story = {
  name: 'Mobile sheet (viewport)',
  decorators: [
    (Story) => (
      <Box w={375} h="100svh" style={{ overflow: 'hidden' }}>
        <MobileViewportMock>
          <Story />
        </MobileViewportMock>
      </Box>
    ),
  ],
};

/**
 * Notifications pipeline — overrides the MSW handler on
 * `/api/notifications` with five notifications (two unread). The badge
 * itself lives in `NotificationsDropdown` (rendered by the Topbar); this
 * story documents the same handler shape so the AppShell composition story
 * can verify the badge end-to-end.
 */
export const WithUnreadBell: Story = {
  name: 'Notifications handler wired (2 unread)',
  beforeEach: ({ msw }) => {
    msw.use(
      http.get('/api/notifications', () =>
        HttpResponse.json([
          {
            id: 'n1',
            kind: 'mention',
            title: 'Priya mentioned you',
            body: '@you can you take a look at the Q3 plan?',
            read: false,
            createdAt: '2025-01-15T10:00:00Z',
          },
          {
            id: 'n2',
            kind: 'comment',
            title: 'New comment on "Billing v2"',
            body: '"Looks great — let’s ship it Friday."',
            read: false,
            createdAt: '2025-01-15T09:00:00Z',
          },
          {
            id: 'n3',
            kind: 'deploy',
            title: 'Deploy succeeded',
            body: 'Production build "v2.18.3" went live.',
            read: true,
            createdAt: '2025-01-15T08:00:00Z',
          },
          {
            id: 'n4',
            kind: 'invite',
            title: 'Jordan accepted your invite',
            body: 'They joined the workspace as a Member.',
            read: true,
            createdAt: '2025-01-15T07:00:00Z',
          },
          {
            id: 'n5',
            kind: 'payment',
            title: 'Invoice INV-2026-0042 paid',
            body: 'Pro plan — monthly ($29.00).',
            read: true,
            createdAt: '2025-01-15T06:00:00Z',
          },
        ]),
      ),
    );
  },
};

/**
 * Layout-effect wrapper that pins `window.innerWidth` to 375 and stubs
 * `window.matchMedia` so the very first `useIsMobile` effect run resolves
 * to `isMobile=true`. Restores both on unmount so the next story on the
 * canvas is unaffected.
 */
function MobileViewportMock({ children }: { children: React.ReactNode }) {
  React.useLayoutEffect(() => {
    const originalInnerWidthDescriptor = Object.getOwnPropertyDescriptor(
      window,
      'innerWidth',
    );
    const originalMatchMedia = window.matchMedia;

    Object.defineProperty(window, 'innerWidth', {
      configurable: true,
      writable: true,
      value: 375,
    });
    window.matchMedia = ((query: string) => ({
      matches: /max-width:\s*767/.test(query),
      media: query,
      onchange: null,
      addListener: () => {},
      removeListener: () => {},
      addEventListener: () => {},
      removeEventListener: () => {},
      dispatchEvent: () => false,
    })) as typeof window.matchMedia;

    return () => {
      if (originalInnerWidthDescriptor) {
        Object.defineProperty(window, 'innerWidth', originalInnerWidthDescriptor);
      }
      window.matchMedia = originalMatchMedia;
    };
  }, []);

  return <>{children}</>;
}
