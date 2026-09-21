import * as React from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import {
  createMemoryHistory,
  createRootRoute,
  createRoute,
  createRouter,
  RouterProvider,
} from '@tanstack/react-router';
import { http, HttpResponse } from 'msw';

import App from '@/App';
import { ThemeProvider } from '@/components/theme-provider';
import { LoginPage } from '@/pages/Auth/LoginPage';
import { SignupPage } from '@/pages/Auth/SignupPage';
import { Dashboard } from '@/pages/Dashboard';
import { ProjectsPage } from '@/pages/Projects/ProjectsPage';
import { Settings } from '@/pages/Settings';

/**
 * The real shell, on a memory router.
 *
 * Mirrors `src/router/router.tsx` exactly — same components, same paths — but
 * builds a fresh router per mount so the probe can start at any path without a
 * singleton's history leaking between runs.
 */
export const PAGES = [
  { name: 'Dashboard', path: '/', heading: 'Dashboard' },
  { name: 'Projects', path: '/projects', heading: 'Projects' },
  { name: 'Login', path: '/login', heading: 'Welcome back' },
  { name: 'Settings', path: '/settings', heading: 'Settings' },
] as const;

/** AuthGuard blocks every protected route until a session resolves. */
export const sessionHandler = http.get('*/api/auth/get-session', () =>
  HttpResponse.json({
    user: { id: 'u1', name: 'Probe User', email: 'probe@rocketship.dev' },
    session: { id: 's1', userId: 'u1', activeOrganizationId: null },
  })
);

export function AppAt({ path }: { path: string }) {
  const queryClient = React.useMemo(
    () => new QueryClient({ defaultOptions: { queries: { retry: false } } }),
    []
  );

  const router = React.useMemo(() => {
    const rootRoute = createRootRoute({ component: App });
    const routeTree = rootRoute.addChildren([
      createRoute({ path: '/login', component: LoginPage, getParentRoute: () => rootRoute }),
      createRoute({ path: '/signup', component: SignupPage, getParentRoute: () => rootRoute }),
      createRoute({ path: '/', component: Dashboard, getParentRoute: () => rootRoute }),
      createRoute({ path: '/projects', component: ProjectsPage, getParentRoute: () => rootRoute }),
      createRoute({
        path: '/projects/$projectId',
        component: ProjectsPage,
        getParentRoute: () => rootRoute,
      }),
      createRoute({ path: '/settings', component: Settings, getParentRoute: () => rootRoute }),
    ]);
    return createRouter({ routeTree, history: createMemoryHistory({ initialEntries: [path] }) });
  }, [path]);

  return (
    <QueryClientProvider client={queryClient}>
      {/* Same position as `src/main.tsx`: inside the query client, around the
          router. ThemeProvider is MantineProvider now, and every Mantine
          component — plus `useTheme()` in App itself — throws without it, so
          leaving it out here measures a crashed tree rather than the shell. */}
      <ThemeProvider defaultTheme="dark" storageKey="ui-probe-color-scheme">
        {/* The probe registers its own route tree, which the app's global Register
            interface does not know about. The cast keeps that local to this file. */}
        {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
        <RouterProvider router={router as any} />
      </ThemeProvider>
    </QueryClientProvider>
  );
}

/**
 * Settled means: *this page's* heading is on screen and nothing is still
 * loading.
 *
 * The heading has to be named. `AuthGuard` bounces an unauthenticated route to
 * `/login`, and `LoginPage` has an `<h1>` too — so a predicate that only asked
 * for "an h1" was satisfied by the login screen, and every protected page in
 * this sweep was measured on the same form. Four pages, three viewports, zero
 * failures, one page actually rendered.
 */
export function pageReady(heading: string): () => boolean {
  return () =>
    document.querySelector('h1')?.textContent?.trim() === heading &&
    document.querySelectorAll('.mantine-Skeleton-root').length === 0;
}
