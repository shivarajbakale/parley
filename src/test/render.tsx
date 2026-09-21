import * as React from 'react';
import { render } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

import { ThemeProvider } from '@/components/theme-provider';
import {
  RouterProvider,
  createMemoryHistory,
  createRootRoute,
  createRoute,
  createRouter,
  Outlet,
} from '@tanstack/react-router';

/**
 * Test harness for routed components.
 *
 * Mounts a component under a real TanStack Router with memory history and a
 * fresh QueryClient, so tests exercise navigation and data fetching the way the
 * app does. Retries are off — a failing request should fail the test now rather
 * than three seconds from now.
 *
 * `paths` are declared by the caller because a master-detail component serves
 * more than one route (`/projects` and `/projects/$projectId` are the same
 * component).
 */
export function renderRoutes(
  Component: React.FunctionComponent,
  { paths, initialEntries }: { paths: string[]; initialEntries: string[] }
) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });

  const rootRoute = createRootRoute({ component: () => <Outlet /> });
  const routes = paths.map((path) =>
    createRoute({ path, component: Component, getParentRoute: () => rootRoute })
  );

  const router = createRouter({
    routeTree: rootRoute.addChildren(routes),
    history: createMemoryHistory({ initialEntries }),
  });

  const result = render(
    <QueryClientProvider client={queryClient}>
      {/* ThemeProvider is MantineProvider now, and `useTheme()` — plus every
          Mantine component a page mounts — throws outside it. Same position as
          `src/main.tsx`, so a test measures the tree the app actually renders. */}
      <ThemeProvider defaultTheme="dark" storageKey="test-color-scheme">
        {/* The test tree registers its own routes, which the app's global route
            register does not know about — the cast keeps that local to here. */}
        {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
        <RouterProvider router={router as any} />
      </ThemeProvider>
    </QueryClientProvider>
  );

  return { ...result, router, queryClient };
}

/** The Projects master-detail view, mounted on both of its routes. */
export function renderProjects(Component: React.FunctionComponent, initialEntry = '/projects') {
  return renderRoutes(Component, {
    paths: ['/projects', '/projects/$projectId'],
    initialEntries: [initialEntry],
  });
}
