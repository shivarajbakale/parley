# Evaluator Rubric

Use after implementation and before acceptance. Score each row 0 (fails),
1 (partial), or 2 (meets bar). Separate the checker from the worker — the agent
that wrote the change should not be the sole judge of it.

| Category          | Question                                                                        | Score (0-2) | Notes |
| ----------------- | ------------------------------------------------------------------------------- | ----------- | ----- |
| Correctness       | Does the behavior match the `user_visible_behavior` in `feature_list.json`?     |             |       |
| Verification      | Did the `verification` commands actually run, with evidence captured?           |             |       |
| Scope discipline  | Did the session stay inside the one chosen feature?                             |             |       |
| Reliability       | Does `make check` still pass after the change?                               |             |       |
| Maintainability   | Is the code self-explanatory; do non-obvious choices have a `DECISIONS.md` entry? |           |       |
| Handoff readiness | Can a fresh session continue from repo artifacts alone (no chat needed)?         |             |       |

## Verdict

- [ ] Accept
- [ ] Revise
- [ ] Block

## Required Follow-Up

- Missing evidence:
- Required fixes:
- Next review trigger:
