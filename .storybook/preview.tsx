import React from 'react';
import type { Preview } from '@storybook/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

import { ThemeProvider } from '../src/components/theme-provider';
import { mswLoader } from 'msw-storybook-addon/csf3';
// The app's one stylesheet: the Mantine layer order, the desktop body defaults,
// this app's two painted backgrounds and the frameless-window drag region. Every
// story renders inside it so components look exactly as they do in the app.
import '../src/App.css';

// Global MSW handlers — the same fixtures the dev server uses (see
// `src/mocks/handlers/`). Registering them at the preview level means
// Dashboard / ProjectsPage / Settings / Team / Billing / Notifications all
// see real data without each story having to opt in via `parameters.msw`.
// Stories that want to override (e.g. the `NoProjects` variant of
// Dashboard, the `Empty` variant of ProjectsPage) extend this set in their
// own `beforeEach` via `msw.use(...)` — the addon re-applies the global
// handlers on every story render, so per-story overrides don't leak.
import { handlers as appHandlers } from '../src/mocks/handlers';

// Enable MSW at the Storybook level (P6) so stories can mock /api/* per story.
const makeQueryClient = () =>
  new QueryClient({
    defaultOptions: { queries: { retry: false, staleTime: Infinity } },
  });

/**
 * Global provider stack (pattern P4):
 *   Theme -> QueryClient
 * Components that need more (SidebarProvider, Router) declare a local
 * per-story decorator — see docs/STORYBOOK_PLAN.md §3.
 */
const preview: Preview = {
  // MSW at Storybook level (P6): the loader starts the worker; the global
  // handlers below provide fixtures so every story has the same data as
  // `npm run dev` with mocking on. Per-story handlers (via
  // `beforeEach: ({ msw }) => msw.use(...)`) layer on top.
  loaders: [mswLoader()],
  parameters: {
    msw: appHandlers,
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
    layout: 'padded',
    // Sidebar order is otherwise alphabetical accident. Roots follow the
    // reading order a newcomer needs (what the tokens are -> what the
    // primitives are -> what the chrome is -> what the screens are), and
    // inside every section the generated Overview/Architecture docs sort
    // ahead of the components they describe.
    options: {
      storySort: {
        method: 'alphabetical',
        order: [
          'Overview',
          ['Introduction', 'Tokens', 'Typography'],
          'UI',
          [
            'Actions',
            'Forms',
            'Feedback',
            'Navigation',
            'Overlays',
            'Data display',
            'Layout',
            'Utilities',
          ],
          'Shell',
          ['Composition', 'Layout', 'Overlays', 'Content', 'Auth', 'Theme'],
          'Pages',
          '*',
        ],
        includeNames: true,
      },
    },
    // Design-token-backed backgrounds so every story can be previewed on the
    // three surfaces the app actually ships (page / surface / control). The
    // values resolve to the current theme via CSS variables — flipping the
    // Theme toolbar repaints them in lockstep.
    //
    // They were `--background` / `--card` / `--muted` / `--accent`, which
    // `src/theme.ts` replaced and `src/App.css` stopped declaring — four
    // backgrounds resolving to nothing, with no error anywhere. That is what
    // `src/test/css-tokens.test.ts` exists to catch, and it did.
    backgrounds: {
      default: 'Page',
      values: [
        { name: 'Page', value: 'var(--mantine-color-body)' },
        { name: 'Surface', value: 'var(--app-surface)' },
        { name: 'Control', value: 'var(--app-control)' },
      ],
    },
  },

  globalTypes: {
    theme: {
      description: 'Design-system theme (P5: one toolbar toggle, never dark variants)',
      toolbar: {
        title: 'Theme',
        icon: 'mirror',
        items: [
          { value: 'dark', title: 'Dark', icon: 'circle' },
          { value: 'light', title: 'Light', icon: 'circlehollow' },
          { value: 'system', title: 'System', icon: 'sync' },
        ],
        dynamicTitle: true,
      },
    },
  },

  initialGlobals: { theme: 'dark' },

  decorators: [
    (Story, context) => {
      const theme = (context.globals.theme as 'dark' | 'light' | 'system') ?? 'dark';
      // Fresh query cache per story render so data stories stay isolated.
      const [queryClient] = React.useState(makeQueryClient);
      return (
        <QueryClientProvider client={queryClient}>
          {/* key forces ThemeProvider to re-read defaultTheme when the toolbar flips */}
          <ThemeProvider key={theme} defaultTheme={theme} storageKey="storybook-theme">
              <Story />
          </ThemeProvider>
        </QueryClientProvider>
      );
    },
  ],
};

export default preview;
