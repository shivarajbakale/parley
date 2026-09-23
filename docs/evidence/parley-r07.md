# parley-r07 — Nunito type and animated empty states

Verified 2026-09-24 on branch `nunito-empty-states`.

## Gates

- `make check` → analyze clean; `ui-lint: 223 file(s) scanned, 0 violation(s)`;
  plan-lint and superplan-lint 0 violations; Flutter tests, ui-probe and
  goldens all passed (122 goldens re-baselined for the new type).
- `make native-test` → `92 Kotlin test(s), 0 failure(s)`.
- New and changed tests: `test/screens/empty_scene_test.dart`,
  `overview_page_test.dart`, `history_page_test.dart`,
  `history_detail_page_test.dart`, `router_test.dart`.

## Device (emulator-5554, API 36)

- `make run-capture` → `parley-r07/run-capture.png`: Setup in Nunito.
- `parley-r07/overview-setup-ring.png`: the setup ring before the first
  dictation, "1 of 4 done", zero figures hidden.
- `parley-r07/history-off.png`: the dozing-orb scene, "Parley is off", Turn on.
- `parley-r07/history-no-match.png`: the magnifier scene, "No match for
  “invoice”", Clear filters.

The ready state ("Nothing yet", Try it opens the practice sheet) needs the
accessibility service on and a real Groq key; it is covered by
`history_page_test.dart` and `overview_page_test.dart`, not by a device frame.
