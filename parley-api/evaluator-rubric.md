# Evaluator Rubric

Use this rubric after implementation and before final acceptance. Each row is
scored 0 (fails), 1 (partial), or 2 (meets bar).

| Category           | Question                                                                              | Score (0-2) | Notes |
| ------------------ | ------------------------------------------------------------------------------------- | ----------- | ----- |
| Correctness        | Does the implemented behavior match the `user_visible_behavior` field?                |             |       |
| Verification       | Did the `verification` commands actually run, with evidence captured?                 |             |       |
| Runtime (Level 3)  | (endpoint) Was the server booted and the route exercised with a captured request/response? |        |       |
| API contract       | Consistent `{ data, meta }` envelope, correct status codes, Zod validation on every input, no leaked internal fields, errors via `AppError`? |   |       |
| Data integrity     | Schema change pushed + client regenerated; no orphaned data; unique/constraints honored? |          |       |
| Scope discipline   | Did the session stay inside the chosen feature scope?                                  |             |       |
| Reliability        | Does `./init.sh` still pass after the change?                                          |             |       |
| Maintainability    | Is the code self-explanatory; do non-obvious choices have a `DECISIONS.md` entry?     |             |       |
| Handoff readiness  | Can a fresh session continue from repo artifacts alone (no chat needed)?               |             |       |

## Verdict

- [ ] Accept
- [ ] Revise
- [ ] Block

## Required Follow-Up

- Missing evidence:
- Required fixes:
- Next review trigger:
