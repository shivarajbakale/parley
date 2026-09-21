# Design Decisions

Append-only. New entries go at the top. Each entry answers **What / Why /
Rejected alternatives / Constraint** so future agents know what they must not
silently undo.

---

## 2026-07-01: Project scaffolded with a harness-first baseline

- **What:** Generated this Electron desktop app (Vite + React + TypeScript) with a complete agent harness from
  rocketship's `harness-core`.
- **Why:** Long-running agent work needs continuity, explicit verification, and a
  repository that is its own system of record — not a bare prompt.
- **Rejected alternatives:** A README-only scaffold — rejected because it leaves
  the agent to re-infer conventions and definition-of-done every session.
- **Constraint:** `make check` is the definition of done. Do not mark features
  `passing` without running their verification and recording evidence.
