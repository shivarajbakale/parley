/**
 * Which rules FAIL the probe.
 *
 * Every other rule still runs and still prints, as WARN, and the run exits 0.
 * This is deliberate: Stage 0 ships the measuring instrument before Stages 1-5
 * fix what it measures, and a gate that goes red the day it lands gets disabled
 * rather than obeyed. A rule graduates into this list in the same commit that
 * makes the app satisfy it — the flip *is* that feature's evidence.
 *
 * This list is measured, not chosen: it is exactly the set of rules that
 * reported zero violations across the 2026-08-26 baseline, so every one of them
 * is fatal today at no cost and can never regress silently. B1-B4 report nothing
 * yet only because no page declares `data-archetype`; enforcing them now means
 * the first page to declare one is held to it immediately.
 *
 * Still report-only, with their baseline counts: C6 (32), D4 (26), C1 (12),
 * C2 (9), A3 (9), D3 (6), C3 (3), A1 (3), A5 (1).
 *
 * T1 is enforced: text must stay inside its enclosing card. Added in the
 * session that fixed the StatCardWithSub bleed (commit 4efaf54) — after
 * that fix the rule reports zero violations across every page, so
 * enforcing is free.
 */
export const ENFORCED: readonly string[] = [
  'A2',
  'A4',
  'B1',
  'B2',
  'B3',
  'B4',
  'C4',
  'C5',
  'D1',
  'D2',
  'T1',
];
