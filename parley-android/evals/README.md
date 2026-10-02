# Harness evals

The gates in `make check` say whether one change is good. This folder asks a
different question: does the harness in `.claude/` make an agent finish real
work in this app, compared with the same app without it?

There are two layers.

**Every gate rule can fail.** `test/harness/gate_evals_test.dart` runs a seeded
defect for each rule through the real gate and requires the rule to fire. It
also refuses any declared rule that nothing has seen failing. It is an ordinary
test, so `make test` and `make check` run it. Add a case to
`tool/fixtures/gate-evals.json` when you add a rule.

**The harness helps.** `make eval` runs each task in [tasks.yaml](tasks.yaml)
twice, as a real Claude Code agent in a throwaway copy of this project: once
with `.claude/` and once with it removed. Each copy is then graded with the
project's own commands. A grade is never the agent's own report. It costs
money and minutes, so it is not part of `check`.

```
make eval                  # needs Node and a logged-in `claude` (or ANTHROPIC_API_KEY)
cd evals && npm run view   # compare the arms side by side
EVAL_KEEP=1 make eval      # keep the copies to read what the agent did
```

A useful task has a tempting wrong fix, or depends on a convention that only the
skills record. If a task scores the same in both arms, the harness is not what
made it pass.
