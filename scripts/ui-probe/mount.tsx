import * as React from 'react';
import { cleanup, render } from '@testing-library/react';
import { page } from '@vitest/browser/context';

import { snapshot } from './snapshot';
import type { Snapshot } from './types';

/** Set VITE_UI_PROBE_SHOTS=1 to write a PNG per measured view for the evaluator. */
const SHOTS = Boolean(import.meta.env.VITE_UI_PROBE_SHOTS);

/** The three widths every rule must hold at. Rule A5 compares across them. */
export const VIEWPORTS = [
  { width: 1280, height: 800 },
  { width: 1440, height: 900 },
  { width: 1920, height: 1080 },
] as const;

/** Two animation frames plus a macrotask: layout, fonts, and a React commit. */
export async function settle(): Promise<void> {
  if (document.fonts) await document.fonts.ready;
  await new Promise<void>((resolve) =>
    requestAnimationFrame(() => requestAnimationFrame(() => resolve()))
  );
  await new Promise<void>((resolve) => setTimeout(resolve, 0));
}

/** Poll until `predicate` holds. Used to wait out MSW-backed queries. */
export async function waitUntil(predicate: () => boolean, timeoutMs = 5000): Promise<void> {
  const start = performance.now();
  while (!predicate()) {
    if (performance.now() - start > timeoutMs) {
      throw new Error(`waitUntil: predicate never became true within ${timeoutMs}ms`);
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  await settle();
}

/**
 * Mount `ui` into a viewport-filling host, let it settle, and snapshot it.
 *
 * The host is `100vh` and `overflow: hidden` because that is the app's own
 * shell contract (`App.tsx` is `h-svh overflow-hidden`). Measuring in a taller
 * host would hide exactly the overflow the probe is looking for.
 */
export async function measure(
  ui: React.ReactElement,
  label: string,
  viewport: { width: number; height: number },
  until?: () => boolean
): Promise<Snapshot> {
  await page.viewport(viewport.width, viewport.height);

  const host = document.createElement('div');
  host.style.width = '100%';
  host.style.height = '100vh';
  host.style.overflow = 'hidden';
  document.body.appendChild(host);

  try {
    render(ui, { container: host });
    await settle();
    if (until) await waitUntil(until);
    const result = snapshot(host, label);
    if (SHOTS) {
      await page.screenshot({ path: `../../.ui-probe/shots/${label.replace(/[^\w@-]+/g, '_')}.png` });
    }
    return result;
  } finally {
    cleanup();
    host.remove();
  }
}
