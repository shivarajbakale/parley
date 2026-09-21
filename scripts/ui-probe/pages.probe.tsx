import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { signIn, signOut } from '@/lib/auth';
import { worker } from '@/mocks/browser';
import { AppAt, PAGES, pageReady, sessionHandler } from './app';
import { measure, VIEWPORTS } from './mount';
import { report } from './report';
import { runRules } from './rules';
import { compareAcrossViewports } from './rules/stability';
import type { Violation } from './types';

/**
 * Modules A, B and C against the real shell at three viewports.
 *
 * Every defect in the design spec's measurement table was measured on this
 * composition — shell plus page — not on a page in isolation, which is why the
 * story sweep in stories.probe.tsx does not replace this.
 */
describe('page sweep', () => {
  beforeAll(async () => {
    await worker.start({ onUnhandledRequest: 'bypass', quiet: true });
    worker.use(sessionHandler);
  });

  afterAll(() => worker.stop());

  it.each(PAGES)('$name holds at every viewport', async ({ name, path, heading }) => {
    // Auth gate for the probe, through the shim's own API rather than its
    // storage key. `src/lib/auth.ts` reads localStorage **once, at module
    // load**, and caches the result so `useSyncExternalStore` gets a stable
    // snapshot — so a test that wrote the key was writing it long after the
    // only read, and every protected page here rendered the login form
    // instead. `signIn` writes the cache and notifies, which is what the app
    // does. This is the one place the probe declares its auth intent; pages do
    // not need to know they are being probed.
    if (path === '/login') {
      await signOut();
    } else {
      await signIn.email({ email: 'probe@rocketship.dev', password: 'probe' });
    }

    const runs: Array<{ label: string; violations: Violation[] }> = [];
    const fatal: Violation[] = [];

    for (const viewport of VIEWPORTS) {
      const label = `${name} @${viewport.width}`;
      const s = await measure(<AppAt path={path} />, label, viewport, pageReady(heading));
      const violations = runRules(s);
      runs.push({ label, violations });
      fatal.push(...report(label, violations).enforced);
    }

    const unstable = compareAcrossViewports(runs);
    fatal.push(...report(`${name} across viewports`, unstable).enforced);

    expect(fatal, fatal.map((v) => `${v.rule} ${v.message}`).join('\n')).toEqual([]);
  });
});
