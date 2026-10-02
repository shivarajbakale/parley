# Evaluator Rubric

Use this rubric after implementation and before final acceptance. Each row
is scored 0 (fails), 1 (partial), or 2 (meets bar).

| Category          | Question                                                                       | Score (0-2) | Notes |
| ----------------- | ------------------------------------------------------------------------------ | ----------- | ----- |
| Correctness       | Does the implemented behavior match the `user_visible_behavior` field?         |             |       |
| Verification      | Did the `verification` commands actually run, with evidence captured?          |             |       |
| Runtime (Level 3) | (UI) Was the app run on a sim and the flow reached, with a screenshot?         |             |       |
| Visual quality    | (UI) Full-width/aligned, no doubled padding, light+dark, no overflow, 4 states, tap targets? |   |       |
| Scope discipline  | Did the session stay inside the chosen feature scope?                          |             |       |
| Reliability       | Does `./init.sh` still pass after the change?                                  |             |       |
| Maintainability   | Is the code self-explanatory; do non-obvious choices have a `DECISIONS.md` entry? |             |       |
| Handoff readiness | Can a fresh session continue from repo artifacts alone (no chat needed)?       |             |       |
| UI pre-pass | The change handles loading/empty/error/success, keeps tap targets >= 44pt (48dp flutter), visible focus states, dark-mode tokens, safe text overflow, and keyboard navigation. |  |  |

## Verdict

- [ ] Accept
- [ ] Revise
- [ ] Block

## Required Follow-Up

- Missing evidence:
- Required fixes:
- Next review trigger:
