import type { Rule, Snapshot, SnapshotNode, Violation } from '../types';
import { ancestors, descendants, hint, visible } from '../tree';

/**
 * Module T — text bounds.
 *
 * Every text-bearing element must stay inside its enclosing card's bounding
 * box. This catches the bug where a page wraps an atom in a sibling div
 * and parks the secondary text there with a `-mt-2` to overlap the card
 * border — the rendered output looks fine in screenshots but the text's
 * measured box extends past the card's box (with no card chrome around
 * the hanging pixels).
 *
 * Skipped cases (the rule is conservative on purpose):
 *  - Decorative non-text elements (icons, separators, spacers).
 *  - Descendants of a `data-slot="scroll-area-viewport"` — those are
 *    allowed to overflow their scroll parent because the scroll parent
 *    clips them. The Cards that hold a ScrollArea are still bounded, so
 *    the user-visible overflow check still fires if the *Card* is the
 *    thing bleeding.
 *  - Elements with `data-probe-ignore="T1"` (or `"all"`) up the tree.
 *
 * Tolerance: 1px, to absorb sub-pixel rendering.
 */

const TOLERANCE = 1;

/** Node carries text the user can read. Empty / whitespace-only counts as no. */
function hasText(n: SnapshotNode): boolean {
  return n.text.trim().length > 0;
}

/** True if any ancestor is a scroll-area viewport (content is scrollable, allowed to overflow). */
function insideScrollableViewport(s: Snapshot, n: SnapshotNode): boolean {
  return ancestors(s, n).some((a) => a.data.slot === 'scroll-area-viewport');
}

function violation(
  rule: string,
  node: SnapshotNode,
  _card: SnapshotNode,
  detail: Violation['detail']
): Violation {
  return {
    rule,
    message: `text bleeds outside its enclosing card (${detail.direction} by ${detail.overflow}px)`,
    nodeId: node.id,
    selectorHint: hint(node),
    detail,
  };
}

export const T1: Rule = {
  id: 'T1',
  title: 'Text stays inside its enclosing card',
  check(s) {
    const out: Violation[] = [];
    for (const card of s.nodes) {
      if (card.data.slot !== 'card' || !visible(card)) continue;
      const cardBox = card.box;
      for (const desc of descendants(s, card)) {
        if (!visible(desc) || !hasText(desc)) continue;
        if (insideScrollableViewport(s, desc)) continue;
        if (ancestors(s, desc).some((a) => a.data.probeIgnore === 'all' || (a.data.probeIgnore ?? '').split(/\s+/).includes('T1'))) continue;

        const db = desc.box;
        // 1px tolerance on each side for sub-pixel rendering.
        const right = db.x + db.width - (cardBox.x + cardBox.width);
        const bottom = db.y + db.height - (cardBox.y + cardBox.height);
        const left = cardBox.x - db.x;
        const top = cardBox.y - db.y;

        if (right > TOLERANCE) {
          out.push(violation('T1', desc, card, {
            direction: 'right',
            overflow: Math.round(right),
            cardWidth: Math.round(cardBox.width),
            cardHeight: Math.round(cardBox.height),
          }));
        } else if (bottom > TOLERANCE) {
          out.push(violation('T1', desc, card, {
            direction: 'bottom',
            overflow: Math.round(bottom),
            cardWidth: Math.round(cardBox.width),
            cardHeight: Math.round(cardBox.height),
          }));
        } else if (left > TOLERANCE) {
          out.push(violation('T1', desc, card, {
            direction: 'left',
            overflow: Math.round(left),
            cardWidth: Math.round(cardBox.width),
            cardHeight: Math.round(cardBox.height),
          }));
        } else if (top > TOLERANCE) {
          out.push(violation('T1', desc, card, {
            direction: 'top',
            overflow: Math.round(top),
            cardWidth: Math.round(cardBox.width),
            cardHeight: Math.round(cardBox.height),
          }));
        }
      }
    }
    return out;
  },
};
