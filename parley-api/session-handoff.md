# Session Handoff

Use this template at the end of any session that another agent (or future-you)
will need to pick up. Keep it short — it's a pointer, not a transcript.

## Verified Now

- What is currently working:
- What verification actually ran (which Levels, exact commands):

## Changed This Session

- Code or behavior added (resources, endpoints, schema):
- Infrastructure or harness changes:

## Broken Or Unverified

- Known defect:
- Unverified path:
- Risk for the next session:

## Next Best Step

- Highest-priority unfinished feature:
- Why it is next:
- What counts as passing (quote `feature_list.json` if relevant):
- What must not change during that step (envelope, validation, schema):

## Commands

- Startup: `./init.sh`
- Fast gate: `make check`
- Full pipeline: `make verify`
- Focused debug:
