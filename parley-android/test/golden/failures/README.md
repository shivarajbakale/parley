# Golden failure output

Empty until a golden fails. `matchesGoldenFile` writes four images per mismatch
here — `*_masterImage`, `*_testImage`, `*_isolatedDiff`, `*_maskedDiff` — and
they are the whole point of a red golden: look at the pair before deciding what
happened.

- The change was intended → `make golden-update`, then read the diff in the
  baselines before committing it. That reading is the review.
- The change was not intended → you have found a regression that analyses
  clean, tests clean, and is visible.

Never update a baseline to make a red gate go away.

The images themselves are ignored by git; this file is not, so the directory
keeps existing for the skills and docs that name it.
