# doc-lint — the gate that holds the budget where the work happens

`doc-lint` is the harness primitive that holds the four entry files
(`AGENTS.md`, `CLAUDE.md`, `ARCHITECTURE.md`, `claude-progress.md`) inside
their per-file budgets, the session prelude under 40 KB, and the rest of the
nine-rule contract that decides whether an instruction file is stale, broken,
or unexplained.

The Node implementation (`scripts/doc-lint.mjs`) runs at the repository root
and across the ten Node scaffold sources. This page is the Dart counterpart
that ships with every generated Flutter project — same nine rules, same
budgets, same fixtures, so a drift that ships from this template fails on
the next `make check` rather than the next sync to the root repo.

## Run it

```bash
make doc-lint        # exits 1 on any violation
dart run tool/doc_lint.dart --strict
```

`make check` runs it as part of the gate chain, between `superplan-lint` and
`design-system-reference`.

## What it catches

| Rule | What fires | Why it matters |
| --- | --- | --- |
| **D1** | `AGENTS.md` is past its 150-line budget | The contract every agent reads first is the one that gets read in full; if it grows past budget, the middle is the part agents use least, so a constraint buried at line 400 is a constraint nobody applies. |
| **D2** | `CLAUDE.md` is past 30 lines, or repeats a paragraph from `AGENTS.md` | The CLAUDE pointer exists to stop being a copy. A duplicated paragraph makes both files load and one redundant. |
| **D3** | `ARCHITECTURE.md` is missing, over 150 lines, or has a code block over 20 lines | A map points at the file; it does not reproduce it. A copy of code is a copy that goes stale. |
| **D4** | `claude-progress.md` is past 120 lines | State is what is true now. The narrative of finished sessions belongs in `docs/history/` and in the commit messages that already carry it. |
| **D5** | The session prelude (AGENTS + CLAUDE + claude-progress + feature_list) is past 40 KB | Read in full before the first useful action, every session. The prelude is the byte-cost a project pays for being harnessed; it should not regress. |
| **D6** | A code sample imports an undeclared package, a relative path that doesn't resolve, a heading names a stack choice the manifest doesn't use, or `make <target>` / `npm run <script>` is documented but undefined | Stale prose points an agent at a library the project cannot import, or a command that doesn't exist. Both are how a kit quietly starts describing another project. |
| **D7** | A markdown link points to a file that is not there | A link to nothing is a claim that nothing backs. The agent follows the link; the build fails. |
| **D8** | A constraint does not name the failure it prevents, or there are more than 15 constraints | A rule whose consequence nobody can name is a rule nobody can weigh. |
| **D9** | A passing feature has no evidence file, an evidence file points to a feature nobody knows about, or the same feature is in both the register and the archive | Two answers to whether the work is done is worse than either answer on its own. |

## Budgets

```
AGENTS.md           150 lines
CLAUDE.md            30 lines
ARCHITECTURE.md     150 lines
claude-progress.md  120 lines
session prelude     40 KB
```

These match `scripts/doc-lint.mjs` byte-for-byte. The corpus
(`tool/fixtures/shared-doc-lint-cases.json`) is the same corpus
`__tests__/flutter-doc-lint-gate.test.ts` runs against the Node version, so a
divergence between the two implementations fails on both sides.

## Flutter-specific differences

- **`pubspec.yaml` is scanned, not `package.json`.** The Node version reads
  `package.json`; the Dart version reads `pubspec.yaml`. Both paths assert
  the same constraint (the manifest doesn't declare what the code claims).
  Both paths run if both files exist.
- **Dart imports are scanned too.** A code block with
  `import 'package:riverpod/riverpod.dart';` fails D6 the same way a Node
  `from 'riverpod'` does — both are undeclared package imports.

## Why both files in a corpus case

The shared fixture corpus has each case carry BOTH `pubspec.yaml` and
`package.json` when D6 needs to fire. The Dart side reads the former; the
Node side reads the latter. Either implementation reading its file finds the
manifest empty, then D6 fires when the code claims a dep that isn't there.
A single-file case would only fire on one side; two files means both sides
agree the rule fires.

## What this gate is not

- **It is not the Node `doc-lint.mjs` rewritten in Dart.** The two
  implementations are separate files with separate test suites, sharing a
  corpus. The Node version stays the canonical source for the ten Node
  scaffolders.
- **It is not stricter than the root.** The budgets are identical.
- **It is not opt-in.** A scaffold that ships without `make doc-lint`
  failing on arrival is a scaffold that will be switched off the moment the
  budget drifts. The gate runs in `init.sh` and `make check`.

## When you cannot use it

A Flutter project that has no `pubspec.yaml` is not a Flutter project.
A Flutter project that has no `AGENTS.md` / `CLAUDE.md` is not harnessed,
and the gate exits 0 with the note `no AGENTS.md or CLAUDE.md — not a
harnessed project`. The latter is by design: a project that has not adopted
the harness has not adopted a budget to enforce.
