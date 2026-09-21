import { SegmentedControl } from '@mantine/core';
import { describe, expect, it } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';
import { measure, VIEWPORTS } from './mount';
import type { Snapshot } from './types';

/**
 * A filter row sizes to its labels, and shows all of every label.
 *
 * This file replaces `toggle-group.probe.tsx`, which pinned a shadcn-specific
 * regression: `flex-1` on the item and `w-fit` on the root hit the
 * intrinsic-sizing rule for flexible items, so every chip rendered as wide as
 * the longest one and the group ate the row. That component is gone, so the
 * old measurement has no subject — but the question it was asking does, and
 * `SegmentedControl` answers it differently and can fail differently.
 *
 * Its failure mode is the opposite one. The control sizes to its content, but
 * a label neither wraps nor pushes the control wider: it **clips**. The last
 * thing in a label is the thing that disappears, and in a filter row the last
 * thing is always the count. `theme.components.SegmentedControl` sets
 * `whiteSpace: nowrap` for that reason, and this is what notices when the
 * guard is removed.
 *
 * Only a real layout engine can see either of these; jsdom reports zero boxes.
 */

const LABELS = ['All 8', 'Unread 3', 'Mentions 2', 'Comments 2', 'Deploys 1', 'System 1'];

/**
 * The chips, by Mantine part rather than by tag.
 *
 * `SegmentedControl-label` is the `<label>` that carries the box; the words sit
 * one level down in `SegmentedControl-innerLabel`, so a filter that asked for a
 * `<label>` with text matched nothing and left all three assertions here
 * looping over an empty array. Every one of them checks the count first for
 * that reason.
 */
function labels(s: Snapshot) {
  return s.nodes.filter((n) => n.mantine === 'SegmentedControl-label');
}

async function measureControl(label: string) {
  return measure(
    // The provider is not scenery: `theme.components.SegmentedControl` is what
    // sets `whiteSpace: nowrap`, so measuring one outside it would measure a
    // control this app never renders — and Mantine throws rather than falling
    // back, which is the honest failure.
    <ThemeProvider defaultTheme="dark" storageKey="ui-probe-segmented-control">
      <SegmentedControl
        size="xs"
        defaultValue="all 8"
        aria-label="Filter"
        data={LABELS.map((l) => ({ value: l.toLowerCase(), label: l }))}
      />
    </ThemeProvider>,
    label,
    VIEWPORTS[VIEWPORTS.length - 1]
  );
}

describe('SegmentedControl layout', () => {
  it('gives each label its own content width, not the widest label’s', async () => {
    const chips = labels(await measureControl('segmented-control content width'));
    expect(chips).toHaveLength(LABELS.length);

    const widths = chips.map((c) => c.box.width);
    // "All 8" against "Comments 2": five characters against ten. Equal widths
    // here mean something has forced the items to a shared track.
    expect(Math.max(...widths) - Math.min(...widths)).toBeGreaterThan(20);
  });

  it('cuts off none of its own text', async () => {
    // The saas-005 defect, in the component it shipped in: labels clipped to
    // slivers while every other gate stayed green.
    const chips = labels(await measureControl('segmented-control clipping'));
    expect(chips).toHaveLength(LABELS.length);
    for (const chip of chips) {
      expect(chip.scrollWidth - chip.clientWidth, `"${chip.text}" is clipped`).toBeLessThanOrEqual(2);
    }
  });

  it('stays as wide as its labels, not count x widest', async () => {
    const s = await measureControl('segmented-control group width');
    const chips = labels(s);
    expect(chips).toHaveLength(LABELS.length);
    const widest = Math.max(...chips.map((c) => c.box.width));
    const root = s.nodes.find((n) => n.mantine === 'SegmentedControl-root');

    expect(root).toBeDefined();
    expect(root!.box.width).toBeLessThan(chips.length * widest);
  });
});
