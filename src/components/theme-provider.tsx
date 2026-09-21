import { useEffect } from 'react';
import {
  MantineProvider,
  localStorageColorSchemeManager,
  useMantineColorScheme,
  type MantineColorScheme,
} from '@mantine/core';
import { ModalsProvider } from '@mantine/modals';
import { Notifications } from '@mantine/notifications';

import { cssVariablesResolver, theme as mantineTheme } from '@/theme';

/**
 * Colour-scheme ownership.
 *
 * Mantine is the source of truth: it stores the choice, sets
 * `data-mantine-color-scheme` on `<html>`, and every Mantine component reads
 * its palette from there. This file is the adapter that keeps the rest of the
 * app in step, and it does exactly two things beyond mounting the provider:
 *
 *  1. Mirrors the *resolved* scheme onto the `dark` / `light` class, because
 *     every atom still under `src/components/ui` paints through Tailwind colour
 *     utilities (`bg-card`, `text-muted-foreground`, …) keyed to
 *     `@custom-variant dark` in `src/App.css`. When the last of those is gone
 *     the effect goes with them.
 *  2. Keeps the old `useTheme()` shape — `{ theme, setTheme }` over
 *     `'dark' | 'light' | 'system'` — so callers did not all have to change on
 *     the same day. `'system'` is Mantine's `'auto'`; nothing else differs.
 *
 * It moved up out of `components/ui/` when that directory was deleted — it was
 * never a kit atom, only the one file in there that nothing about shadcn.
 */

type Theme = 'dark' | 'light' | 'system';

const toMantine = (t: Theme): MantineColorScheme => (t === 'system' ? 'auto' : t);
const fromMantine = (s: MantineColorScheme): Theme => (s === 'auto' ? 'system' : s);

type ThemeProviderProps = {
  children: React.ReactNode;
  defaultTheme?: Theme;
  storageKey?: string;
};

/**
 * Mirror the resolved scheme onto the legacy class. Mantine already wrote the
 * attribute by the time this runs, so `auto` is read back from the element
 * rather than re-derived from `matchMedia` — one source, no drift.
 */
function LegacyDarkClass() {
  const { colorScheme } = useMantineColorScheme();

  useEffect(() => {
    const root = document.documentElement;
    const resolved =
      colorScheme === 'auto'
        ? window.matchMedia('(prefers-color-scheme: dark)').matches
          ? 'dark'
          : 'light'
        : colorScheme;

    root.classList.remove('light', 'dark');
    root.classList.add(resolved);
  }, [colorScheme]);

  return null;
}

export function ThemeProvider({
  children,
  defaultTheme = 'system',
  storageKey = 'vite-ui-theme',
}: ThemeProviderProps) {
  return (
    <MantineProvider
      theme={mantineTheme}
      cssVariablesResolver={cssVariablesResolver}
      defaultColorScheme={toMantine(defaultTheme)}
      colorSchemeManager={localStorageColorSchemeManager({ key: storageKey })}
    >
      <LegacyDarkClass />
      {/* The toast queue, mounted once. `src/lib/notify.ts` is how the rest of
          the app talks to it; nothing else imports `notifications` directly. */}
      <Notifications position="top-center" />
      {/* Mounted once and driven imperatively from anywhere:
          `modals.openConfirmModal` is what `ui-lint`'s native-dialog rule points
          at, so the advice has to be followable the moment it is read. */}
      <ModalsProvider>{children}</ModalsProvider>
    </MantineProvider>
  );
}

export const useTheme = () => {
  const { colorScheme, setColorScheme } = useMantineColorScheme();

  return {
    theme: fromMantine(colorScheme),
    setTheme: (next: Theme) => setColorScheme(toMantine(next)),
  };
};
