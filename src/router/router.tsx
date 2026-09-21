import { createRootRoute, createRoute, createRouter } from '@tanstack/react-router';
import App from '@/App';
import { Dashboard } from '@/pages/Dashboard';
import { Settings } from '@/pages/Settings';
import { LoginPage } from '@/pages/Auth/LoginPage';
import { SignupPage } from '@/pages/Auth/SignupPage';
import { ProjectsPage } from '@/pages/Projects/ProjectsPage';

const rootRoute = createRootRoute({ component: App });

// Public (no auth) — the AuthGuard in App.tsx lets these through.
const loginRoute = createRoute({ path: '/login', component: LoginPage, getParentRoute: () => rootRoute });
const signupRoute = createRoute({ path: '/signup', component: SignupPage, getParentRoute: () => rootRoute });

// Protected
const indexRoute = createRoute({ path: '/', component: Dashboard, getParentRoute: () => rootRoute });

// Projects is a master-detail view: both routes render the same component, and
// the `$projectId` param decides whether the detail pane is filled. The list
// never unmounts, so selecting a row keeps the user's scroll position.
const projectsRoute = createRoute({
  path: '/projects',
  component: ProjectsPage,
  getParentRoute: () => rootRoute,
});
const projectDetailRoute = createRoute({
  path: '/projects/$projectId',
  component: ProjectsPage,
  getParentRoute: () => rootRoute,
});

const settingsRoute = createRoute({ path: '/settings', component: Settings, getParentRoute: () => rootRoute });

const routeTree = rootRoute.addChildren([
  loginRoute,
  signupRoute,
  indexRoute,
  projectsRoute,
  projectDetailRoute,
  settingsRoute,
]);

const router = createRouter({ routeTree });

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router;
  }
}

export default router;
