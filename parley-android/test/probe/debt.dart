/// What the probe's kit-wide rules report today, surface by surface.
///
/// **Thirty-two across ten surfaces, all of them `contrast`.** The map was
/// empty for 86 commits and is kept — rather than deleted — because the
/// mechanism is a **ratchet** and it works in both directions:
///
///   * a surface that gains a violation fails, because its count went up;
///   * a surface that loses one **also fails**, until the number here is
///     lowered — so a fix cannot be quietly spent somewhere else.
///
/// The last nine before these were `dead-band`, and they were paid off.
///
/// That rule arrived with `flutter-062`, when a booking form shipped with 247
/// points of white between its last field and its pinned button and every
/// other rule passed it — nothing in the repository had ever asked whether a
/// screen was *empty*, only whether it was broken. It found the class the
/// moment it existed: seven surfaces across five screens, each a short page
/// under a bar that has to be at the bottom.
///
/// `screen/detail` was the first paid off. Taking the type scale down a fifth
/// shortened every row on the page, so the three related rows that used to
/// carry it to its pinned bar stopped 173 points short; a fourth row is what
/// the section is for and what closed it.
///
/// The other six were paid off in `flutter-086`, and **not one of them by
/// moving pixels**. Each void was sitting on a question the screen had raised
/// and never answered, which is what the rule is really measuring:
///
///   * `screen/form_who` — three fields, and no answer to "do I already have
///     a desk?". A panel of the bookings this account holds.
///   * `screen/form_when` — a date picked blind. How full that day already
///     is, as a bar, and how many of the reader's team are in.
///   * `screen/form_review` — what was chosen, and nothing about what
///     Confirm does. The invite, the door code, the cancellation window.
///   * `screen/profile_activity` — four rows of history for an account a
///     month old. Four more, which is what a month looks like.
///   * `screen/profile_badges` — a wall of what was earned, silent on what
///     is next. The next badge and the distance to it.
///   * `screen/welcome` — a product named and never described. The three
///     figures in the stat row now each carry the line that says what they
///     mean.
///
/// It reached zero, and `flutter-085` put three back. Giving a row the height
/// `ComponentSpec.listRowMinHeight` declares, rather than the one Material's
/// `ListTile` picked, took eight points off every single-line row and
/// twenty-four off every two-line one. On most screens that is the point. On
/// three it was the `dead-band` rule doing its job: `screen/detail` had been
/// filling its page to the pinned bar with row height, and once the rows told
/// the truth about how much content they hold, 231 points of the page were
/// nothing. `screen/form_review` had 25 points of scroll left and lost them.
///
/// `flutter-087` paid all three, in content rather than by loosening
/// `_deadBandFloor` — retuning a rule to fit a result is the exact move this
/// repository has a probe to prevent:
///
///   * `screen/detail` and `screen/detail@long` — a page that said what a
///     guide *is* and never where the reader had got to. `LibraryItem` carries
///     `minutes` and `progress` now, and a `Where you are` section draws them
///     above the blurb.
///   * `screen/form_review` — a fourth thing that happens after Confirm. The
///     reminder the evening before, which is the one thing left that the
///     reader could not see from the review.
///
/// The second half of the mechanism is what still earns the file at zero: a
/// surface added to the corpus arrives at zero and has to stay there, and
/// there is nowhere left to park a regression. The root gate's `DEBT_CEILING` in
/// `__tests__/flutter-ui-probe.test.ts` holds the same total, so banking a fix
/// means lowering both in one change.
///
/// Four rules are graded here rather than absolutely — `target`, `contrast`,
/// `clipped-text` and `overlap` — because each grades a kit that was built
/// before anything measured the thing it measures, and each finds a *class*
/// rather than an instance. `target` and `contrast` came first and
/// `flutter-032` emptied them: the list peaked at 45 controls and 24 strings
/// across 23 surfaces. `clipped-text` and `overlap` arrived with `flutter-040`,
/// when a demo blog shipped with a cut headline in every row and a back
/// chevron drawn through its eyebrow, and it turned out no gate in the
/// repository had ever asked either question. They found the rest of the kit,
/// and that number sat here for 86 commits.
///
/// **What paid them off**, in the order the count came down:
///
///   * *The type scale and the header.* Twenty-one were geometry rather than
///     argument: the ratio tightened from 1.13 to 1.10, the component page's
///     bar went compact, and the stage stopped paying the page gutter twice —
///     a string that no longer overflows is a string that no longer clips.
///   * *A defect in a component.* `DSTabBar` in `DSTabLayout.auto` counted its
///     tabs instead of measuring them, so five labels that wanted more than
///     the bar had were laid out as though they fitted.
///   * *A blind spot in a rule.* All nineteen `overlap` were a run of text
///     behind a pinned bar, which is the kit's design and not an accident:
///     `AppChromeSurface` is an opaque tint on Android and a `BackdropFilter`
///     on Apple, and both destroy what is under them. Eleven `clipped-text`
///     were a tab or a segment label — a choice in a mutually exclusive set,
///     which is what the rule's own message means by "a label may be
///     truncated". `AppChromeOcclusion` and `AppChoiceLabel` are the kit
///     stating each fact where a gate can read it, rather than the gate
///     inferring paint order or guessing from a font size. Four `target` were
///     a control the *viewport* was cutting: the semantics tree reports an
///     ancestor's clip beside an already-shortened rect, which read as a
///     26-point tab and a 46-point stepper button, so the rule measures the
///     scrollers from the render tree now.
///   * *A decision the gate disagreed with.* Nine, and they were paid last on
///     purpose — see `DECISIONS.md`, "Three answers to a probe finding".
///     `DSListTile` and the media row documented single-line titles, and
///     one line cut "Sign out of every device" and "Quarterly report" at a
///     width somebody owns; both take two lines now. A settings row put an
///     email address on its trailing edge, where `ListTile` hands the trailing
///     slot the row and the label it answers ellipsises to nothing; the
///     address is under the label now. A slider was pinned at 160 points
///     inside a row on a 320-point phone, and a search field's placeholder was
///     written longer than the narrowest phone the kit is graded at.
///
/// **What the thirty-two are.** `flutter-089` taught `contrast` to resolve a
/// background it had never been able to read, and the rule turned out to have
/// been saying nothing at all on a real screen. It gave up at the first
/// `RenderCustomPaint` or `RenderStack` it met walking up, and every
/// `Material` in the kit inserts one of each — so all twenty-six strings on
/// the dashboard were ungraded, the gradient hero included. It now reads a
/// gradient's stops, walks through a stack when the text is its bottom child,
/// and walks through a painter that draws only in front of its child.
///
/// What it found is five colour pairs, not thirty-two problems:
///
///   * `#78827F on #FFFFFF` at 11pt, 3.95:1 — the secondary text role on a
///     light surface. Chart axis labels, `vs last week`, `No data yet`. The
///     source of most of this ledger.
///   * `#848F8B on #202B27` at 11pt, 4.38:1 — the same role in dark, a
///     twelfth of a point short.
///   * `#F8FBFA on #3DA08C` at 13pt, 3.03:1 — a filled button's label on the
///     accent.
///   * `#008368 on #DBEEEA` and `on #D4EDE4` at 12–13pt, ~3.9:1 — accent text
///     on an accent well.
///
/// They are owed here rather than fixed in the same change because each is a
/// palette role: moving one moves every screen that draws it and every golden
/// that records it, which is a design decision and not a lint fix.
///
/// The full text of every violation, with the matrix cell and the
/// measurement, is printed whenever a surface fails.
///
/// The count is of *distinct things*, not of measurements: one control found
/// in eighteen cells of the matrix is one entry.
const Map<String, Map<String, int>> knownDebt = <String, Map<String, int>>{
  'catalog/DSBottomInsets': <String, int>{},
  'catalog/DSBottomNavBar': <String, int>{},
  'catalog/DSBottomSheet': <String, int>{},
  'catalog/DSChart': <String, int>{},
  'catalog/DSComponentStyle': <String, int>{},
  'catalog/DSControlTile': <String, int>{},
  'catalog/DSDismissibleTile': <String, int>{},
  'catalog/DSFab': <String, int>{'contrast': 1},
  'catalog/DSLargeAppBar': <String, int>{},
  'catalog/DSListTile': <String, int>{},
  'catalog/DSMediaHero': <String, int>{},
  'catalog/DSMediaRow': <String, int>{},
  'catalog/DSMediaTile': <String, int>{},
  'catalog/DSOverlaySurface': <String, int>{},
  'catalog/DSPageHeader': <String, int>{},
  'catalog/DSPinnedActionBar': <String, int>{},
  'catalog/DSProgressIndicator': <String, int>{},
  'catalog/DSProgressRing': <String, int>{},
  'catalog/DSSearchBar': <String, int>{},
  'catalog/DSSectionHeader': <String, int>{},
  'catalog/DSSegmentedButton': <String, int>{},
  'catalog/DSSegmentedProgress': <String, int>{},
  'catalog/DSSettingsSection': <String, int>{},
  'catalog/DSSidebar': <String, int>{},
  'catalog/DSSlider': <String, int>{},
  'catalog/DSStatTile': <String, int>{},
  'catalog/DSTabBar': <String, int>{},
  'catalog/DSThemeModePicker': <String, int>{},
  'catalog/DSTour': <String, int>{},
  'catalog/gallery': <String, int>{},
  'screen/browse': <String, int>{},
  'screen/dashboard': <String, int>{},
  'screen/detail': <String, int>{},
  'screen/detail@long': <String, int>{},
  'screen/form_review': <String, int>{},
  'screen/form_when': <String, int>{},
  'screen/form_who': <String, int>{},
  'screen/inbox': <String, int>{},
  'screen/inbox@long': <String, int>{},
  'screen/insight_month': <String, int>{},
  'screen/insight_week': <String, int>{},
  'screen/library': <String, int>{},
  'screen/library@long': <String, int>{},
  'screen/login': <String, int>{},
  'screen/order_placed': <String, int>{},
  'screen/profile_activity': <String, int>{},
  'screen/profile_badges': <String, int>{},
  'screen/settings': <String, int>{},
  'screen/tour_1': <String, int>{},
  'screen/tour_2': <String, int>{},
  'screen/tour_3': <String, int>{},
  'screen/welcome': <String, int>{},
};
