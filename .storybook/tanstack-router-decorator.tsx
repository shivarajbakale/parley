import React from 'react';
import { Box, Code, Text } from '@mantine/core';
import {
  createMemoryHistory,
  createRootRoute,
  createRoute,
  createRouter,
  Outlet,
  RouterProvider,
} from '@tanstack/react-router';
import { http, HttpResponse } from 'msw';

/**
 * Story decorator for components that touch TanStack Router and/or the auth
 * session (P4). Creates an in-memory router per render so `useNavigate`,
 * `useRouterState` and `Link` work without the real route tree.
 *
 * The fake session is served by MSW at better-auth's `/api/auth/get-session`.
 */
const sessionFixture = {
  user: { id: 'u1', name: 'Shiv Bakale', email: 'shiv@rocketship.dev' },
  session: { id: 's1', userId: 'u1', activeOrganizationId: null },
};

export const authSessionHandler = http.get(
  '/api/auth/get-session',
  () => HttpResponse.json(sessionFixture)
);

// Paths the app shell links to. We stub each one by default so navigation
// warnings don't fire. If a story needs a real component on one of these
// paths, it supplies `routeMounts` — the only way to override the stub.
//
// `/` is in the list because pages like LoginPage call
// `router.navigate({ to: '/' })` in their effect when one already has a
// session in localStorage (the dev auto-login path). Without registering
// `/` the navigate lands on TanStack Router's 404 page.
// Mirrors src/router/router.tsx. Stubbing a path the app does not route to
// would advertise a screen that does not exist; keep this list in step with the
// real route tree.
const DEFAULT_STUB_PATHS = [
  '/',
  '/login',
  '/signup',
  '/projects',
  '/projects/$projectId',
  '/settings',
] as const;

function stubPage(path: string) {
  return function StubPage() {
    return (
      <Text p="xl" size="sm" c="dimmed">
        Stubbed page: <Code>{path}</Code>
      </Text>
    );
  };
}

interface RouteMounts {
  /** Path → Component to render on that path. */
  [path: string]: React.ComponentType;
}

/**
 * Build a storybook decorator that mounts the story on `initialPath` inside
 * an in-memory TanStack Router.
 *
 * - The story component is mounted on `initialPath` (e.g.
 *   `withMemoryRouter('/login')` puts the story at `/login`). This is the
 *   fix vs. the previous version, which always mounted the story on `/`
 *   and stubbed every other path — meaning Settings/ProjectsPage/LoginPage
 *   all rendered the "Stubbed page" placeholder instead of the real
 *   component.
 * - `routeMounts` lets a story put specific components on additional paths
 *   (useful for future stories that mount a whole multi-page tree). Anything
 *   not in `routeMounts` falls through to the default stub.
 * - The other paths the shell might navigate to are stubbed with a
 *   placeholder so `router.navigate` doesn't warn about an unknown path.
 */
export function withMemoryRouter(
  initialPath = '/',
  routeMounts: RouteMounts = {},
): (Story: React.ComponentType) => React.ReactElement {
  return function RouterDecorator(Story) {
    const rootRoute = createRootRoute({ component: () => <Outlet /> });

    // Build the set of paths the router knows about.
    const allPaths = new Set<string>([
      initialPath,
      ...Object.keys(routeMounts),
      ...DEFAULT_STUB_PATHS,
    ]);

    const children = [...allPaths].map((path) => {
      // The story gets its own route — exactly one of these per call.
      if (path === initialPath) {
        return createRoute({
          getParentRoute: () => rootRoute,
          path,
          component: () => <Story />,
        });
      }
      // Caller supplied a custom component for this path.
      if (routeMounts[path]) {
        const Comp = routeMounts[path];
        return createRoute({
          getParentRoute: () => rootRoute,
          path,
          component: () => <Comp />,
        });
      }
      // Default: stub.
      return createRoute({
        getParentRoute: () => rootRoute,
        path,
        component: stubPage(path),
      });
    });

    const router = createRouter({
      routeTree: rootRoute.addChildren(children),
      history: createMemoryHistory({ initialEntries: [initialPath] }),
      defaultPreload: 'intent',
    });

    // A `Box` with its own border, not a `Paper`, and that is the whole reason.
    // `theme.components.Paper` sets `data-panel="card"` as a default prop so the
    // probe sees every surface without each screen opting in — but this frame is
    // a story fixture, not a surface. As a Paper it became a full-viewport panel
    // wrapping the page, `topLevelPanels` found only it, and B1/B2/B4 failed on
    // twelve stories reporting zero panes, zero tiles and zero cards.
    return (
      <Box
        h={420}
        style={{
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
          border: '1px solid var(--mantine-color-default-border)',
          borderRadius: 'var(--mantine-radius-lg)',
        }}
      >
        <RouterProvider router={router} />
      </Box>
    );
  };
}

export const mswSession = {
  // msw-storybook-addon v3 registers handlers through the story context.
  beforeEach: ({ msw }: any) => {
    msw.use(authSessionHandler);
  },
};