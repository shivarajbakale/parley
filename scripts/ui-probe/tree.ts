import type { Snapshot, SnapshotNode } from './types';

/**
 * Snapshot walking, shared by every rule.
 *
 * `paints` is the one to read carefully. Dead space is measured to the bottom of
 * the last element that puts *ink* on screen — text, a fill, a border, or a
 * replaced element. An earlier attempt measured to the lowest element that fit
 * inside the panel, which made every full-height flex container report 100%
 * fill and returned a false negative on every page in the app.
 */

const TRANSPARENT = /^(transparent|rgba?\(\s*0[\s,]+0[\s,]+0[\s,/]+0\s*\))$/i;
const SELF_PAINTING = new Set(['img', 'svg', 'canvas', 'video', 'input', 'select', 'textarea', 'hr']);

export function childrenOf(s: Snapshot, n: SnapshotNode): SnapshotNode[] {
  return n.children.map((id) => s.nodes[id]);
}

export function descendants(s: Snapshot, n: SnapshotNode): SnapshotNode[] {
  const out: SnapshotNode[] = [];
  const stack = [...n.children];
  while (stack.length) {
    const node = s.nodes[stack.pop() as number];
    out.push(node);
    stack.push(...node.children);
  }
  return out;
}

export function ancestors(s: Snapshot, n: SnapshotNode): SnapshotNode[] {
  const out: SnapshotNode[] = [];
  let cursor = n.parent;
  while (cursor !== null) {
    const node = s.nodes[cursor];
    out.push(node);
    cursor = node.parent;
  }
  return out;
}

export function visible(n: SnapshotNode): boolean {
  return (
    n.style.display !== 'none' &&
    n.style.visibility !== 'hidden' &&
    n.style.opacity > 0 &&
    n.box.width > 0 &&
    n.box.height > 0
  );
}

export function paints(n: SnapshotNode): boolean {
  if (!visible(n)) return false;
  if (n.text.length > 0) return true;
  if (SELF_PAINTING.has(n.tag)) return true;
  if (!TRANSPARENT.test(n.style.backgroundColor)) return true;
  const s = n.style;
  return s.borderTopWidth + s.borderRightWidth + s.borderBottomWidth + s.borderLeftWidth > 0;
}

/** `data-probe-ignore="A1 C6"` or `data-probe-ignore="all"`, inherited down the tree. */
export function ignoredBy(s: Snapshot, n: SnapshotNode, ruleId: string): boolean {
  const opted = (node: SnapshotNode) => {
    const raw = node.data.probeIgnore;
    if (raw === undefined) return false;
    const list = raw.trim().split(/\s+/);
    return list.includes('all') || list.includes(ruleId);
  };
  return opted(n) || ancestors(s, n).some(opted);
}

/**
 * Nearest non-transparent background up the tree.
 *
 * The snapshot root is the app's element, not the document, and the wrappers
 * above it are transparent — so the walk falls through to the page itself
 * rather than to black. Returning black here made every ground comparison
 * trivially pass.
 */
export function effectiveBackground(s: Snapshot, n: SnapshotNode): string {
  for (const node of [n, ...ancestors(s, n)]) {
    if (!TRANSPARENT.test(node.style.backgroundColor)) return node.style.backgroundColor;
  }
  if (s.bodyBackground && !TRANSPARENT.test(s.bodyBackground)) return s.bodyBackground;
  return 'rgb(0, 0, 0)';
}

function kebab(key: string): string {
  return key.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`);
}

/** A short, greppable pointer to the element — reports have to be actionable. */
export function hint(n: SnapshotNode): string {
  const attrs = Object.entries(n.data).map(([k, v]) =>
    v === '' ? `data-${kebab(k)}` : `data-${kebab(k)}="${v}"`
  );
  const open = [n.tag, ...attrs].join(' ');
  return `<${open}> @${Math.round(n.box.x)},${Math.round(n.box.y)}`;
}

/**
 * The `data-variant` Mantine paints as the primary action.
 *
 * `filled`, not `default` — and the difference is a migration trap worth
 * naming once, here, rather than in each rule that reads it. Under the kit this
 * app used to ship, `variant="default"` *was* the primary button and everything
 * else was a secondary. Under Mantine the words swap: `filled` is the accented
 * call to action and `default` is the neutral one beside it.
 *
 * Left on the old string, C5 flagged pairs of *secondary* buttons — fifteen of
 * them across four pages — while it could never see two real primaries, and B3
 * could not find a form's submit at all.
 */
export const PRIMARY_VARIANT = 'filled';
