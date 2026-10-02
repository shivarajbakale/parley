<!-- super-plan:v1 — generated, do not hand-edit.
     Regenerate with: dart run tool/super_plan.dart SUPERPLAN.json -o SUPERPLAN.md -->

# Superplan — Habit Tracker

A daily habit tracker with streaks, daily check-in, and reminders.

**Problem.** People who want to build a habit forget to do it on day two. The reminder fires, they snooze, and the streak they were excited about the day before is gone before week one ends. They need a single screen that says what to do today, what they did yesterday, and what is at risk if they skip today — and they need it to be the first thing they see.

**Target users.** Adults forming one to three new habits at a time, comfortable with a phone, not comfortable with a journal.

**Industry.** health-wellness — see `docs/references/industry-conventions.md` for the design language this brief pulls from.

## Decisions

2 answered by you, 2 assumed. Every assumption below is a question that was not asked — read those first.

| | Question | Call | Why |
| --- | --- | --- | --- |
| you | Does a habit need an account, or does it live on the device? | On the device. No auth in the MVP. | — |
| you | Does a missed day break the streak, or is there a grace day? | A missed day breaks it. No grace day. | — |
| **assumed** | Can a habit repeat more than once a day? | No — one check-in per habit per day. | Multiple check-ins turns the ring into a counter and the streak into an average; that is a different app |
| **assumed** | Do reminders fire locally or from a server? | Locally, via the notifications seam. | A server-side reminder needs accounts and a scheduler, and auth is already out of the MVP |

## MVP cut

**In:**
- Today's habits list, with check-off and current streak per row
- Add / edit / delete a habit
- Stats tab with weekly completion ring and per-habit streak history
- Local notifications: one per habit, daily at the user's chosen time

**Deferred (explicit):**
- Cloud sync / cross-device
- Apple HealthKit / Google Fit integration
- Premium tier or paywall (free for MVP)

## App-level non-goals

- Social features. A streak that belongs to your friend group is a different product.
- Analytics dashboards beyond a streak counter and a weekly completion ring.
- Habit libraries. The user names their own habits, period.

## Navigation map

```
tabs: Today · Stats · Settings
```

```
Home shell
  ├─ /habits           Today (tab 1)
  ├─ /habits/new       New habit (pushed)
  ├─ /habits/:id       Habit detail (pushed from row)
  ├─ /habits/:id/edit  Edit habit (pushed from detail)
  ├─ /stats            Stats (tab 2)
  └─ /settings         Settings (tab 3)
```

## Modules

| Module | Decision |
| --- | --- |
| `auth` | none |
| `onboarding` | required |
| `paywall` | none |
| `analytics` | required |
| `push` | required |

## Theme tokens

- Habit ring colour reuses palette.action for completed streaks
- Streak numbers use typography.headlineSmall for at-a-glance readability
- Day cells in stats use spacing.half-step

## Dependencies

- **flutter_local_notifications** — Daily reminders; iOS and Android both supported without Firebase
- **intl** — Already a transitive dep; explicit pin for date formatting in stats

## Routes

6 routes. Each renders a phone-frame wireframe from the same twelve archetypes the per-feature `FEATURE-PLAN.md` keys off, so the shape approved here and the shape approved per feature cannot drift.

### Today · `/`

Archetype: `focal` — one hero (today's date + ring), then a bento of the three habits due

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│   Today                          ⋯ │
├────────────────────────────────────┤
│ ┌────────────────────────────────┐ │
│ │ Mon · Mar 4                    │ │
│ │ 2 of 3 done                    │ │
│ └────────────────────────────────┘ │
│                                    │
│ ┌──────────────┐ ┌───────────────┐ │
│ │ Read 10 … 5d │ │ Stretch       │ │
│ └──────────────┘ └───────────────┘ │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ Drink water · 1l today         │ │
│ └────────────────────────────────┘ │
│                                    │
│                                    │
│                                    │
│                                    │
│                     ( + Add habit… │
├────────────────────────────────────┤
│   ● Today    ○ Stats   ○ Settings  │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ No habits yet. The   │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ hero says 'Add your  │   │ Habits could not be  │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ first habit'. One    │   │ loaded. Pull to      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ button: New habit.   │   │ refresh.             │
│                      │   │                      │   │                      │
│                      │   │ [ Add habit ]        │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max    retry, never a raw error
```

Success: Today's list renders, the ring fills as rows check off.

**Look & feel**

- **Header:** DSLargeAppBar with the date as title, the count as subtitle
- **Motion:** Tap-to-check fires a 200ms ring-fill on the row, no other animation
- **Dark mode:** Ring colour stays the same; tile surfaces use the surface ladder, not pure white

**Layout (region → kit)**

| Region | Kit | Purpose |
| --- | --- | --- |
| `header` | `DSLargeAppBar` | — |
| `body.scroll` | `DSListTile`, `DSCard` | — |
| `fab` | `DSFab` | — |

scroll `scrollable_header_pinned_fab` · pinned: `header`, `fab` · safe area ✓ top · safe area ✓ bottom

**Components (2)**

| Kit | Region | Purpose | Why | Not |
| --- | --- | --- | --- | --- |
| `DSLargeAppBar` _(chrome)_ | `header` | Carried forward from the legacy control/why/rejected triple. See the per-feature plan for the role of this kit on this route. | It carries the date+count subtitle and pushes back under scroll, which makes the bento the content rather than a header chrome strip | `a custom AppBar with a CircularProgressIndicator drawn in it` |
| `DSListTile` _(row)_ | `body.bento` | Carried forward from the legacy control/why/rejected triple. See the per-feature plan for the role of this kit on this route. | Row is the only pattern that supports a leading checkbox and trailing streak chip without hand-rolling layout | `Card with a Row of widgets, which ui-lint will reject anyway` |

**Best practices — Accessibility**

- Each row's checkbox announces habit name + streak ('Read 10 pages, 5 day streak')
- The hero's ring is decorative and aria-hidden; the count is read from the subtitle

**Best practices — Design-system rules**

- Every checkbox uses DSTapTarget — VoiceOver users get the same hit area as everyone else
- No inline Theme.of(context).primary — all colours come from tokens

**Best practices — Verification**

- Text scale 2.0: every row's streak chip stays inside its tap target
- Narrow width (390pt): the bento rows reflow to a single column without clipping

**Best practices — Non-goals**

- Streak history on the home screen — that lives in the Stats tab

**Gestures (1)**

| Selector | Event | Behaviour | Haptic |
| --- | --- | --- | --- |
| `DSCard (today’s habit)` | `tap` | marks the habit complete for today | selectionClick |

**Journeys (1)**

- **Check in and see the streak grow** ✓ happy path
  - `/ → tap today’s card → streak +1`

**APIs required**

- **Entities:** Habit, Completion

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/habits/today` | no | list today's habits with completion state |
| POST | `/habits/:id/check` | no | mark habit complete for today |

- **Providers:** habitsForTodayProvider, checkHabitProvider

| From | To | Note |
| --- | --- | --- |
| `home_screen` | `/habits` | first tab |
| `habit_detail_page` | `/habits/:id` | the row tap |

**Blast radius**

```
new (3)
  ├── lib/screens/home/today_page.dart
  ├── lib/widgets/today_hero.dart
  └── test/screens/today_page_test.dart

changed (2)
  ├── lib/screens/home_screen.dart
  └── lib/utils/app_router.dart
```

**Sprint**

- order `1`, size `M`

Verification gate:
- `flutter analyze --no-fatal-infos`
- `dart run tool/ui_lint.dart`
- `flutter test test/screens/today_page_test.dart`
- `make ui-probe`

### All habits · `/habits`

Archetype: `collection` — every habit the user has, filterable by status

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│ ‹                                ⋯ │
├────────────────────────────────────┤
│ All habits                         │
│                                    │
│ [ ⌕ Search habits                ] │
│                                    │
│ ( All ) ( Active ) ( Paused ) ▸    │
│                                    │
│ ────────────────────────────────── │
│  Read 10 pages      5d             │
│ ────────────────────────────────── │
│  Stretch           12d             │
│ ────────────────────────────────── │
│  Drink water · 1l   2d             │
│ ────────────────────────────────── │
│                                    │
│ ◂ swipe: Archive                   │
│   also on: the row's overflow men… │
│                     ( + Add habit… │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                   zero results                  error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ No habits yet. 'Add  │   │ No habits match that │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ your first habit'    │   │ filter or search.    │   │ Habits could not be  │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ with a primary       │   │ Clear filters.       │   │ loaded.              │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ action.              │   │                      │   │                      │
│                      │   │                      │   │ [ Clear filters ]    │   │ [ Try again ]        │
│                      │   │ [ Add habit ]        │   │                      │   │                      │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max       clears the filter       retry, never a raw error
```

Success: The list renders; pull-to-refresh updates it.

**Look & feel**

- **Header:** Plain DSAppBar — no large variant, this is a pushed route so the back chevron matters
- **Motion:** Swipe-archive animates a 240ms slide-out; no other motion
- **Dark mode:** Filter chip selected state uses surface-2; non-selected uses surface-1

**Layout (region → kit)**

| Region | Kit | Purpose |
| --- | --- | --- |
| `header` | `DSCompactAppBar` | — |
| `body.scroll` | `DSDismissibleTile`, `DSSearchBar`, `DSChipGroup` | — |

scroll `scrollable` · pinned: `header` · safe area ✓ top · safe area ✓ bottom

**Components (3)**

| Kit | Region | Purpose | Why | Not |
| --- | --- | --- | --- | --- |
| `DSDismissibleTile` _(row)_ | `body.list` | Carried forward from the legacy control/why/rejected triple. See the per-feature plan for the role of this kit on this route. | Archive is a common destructive action and a swipe is the gesture users already have for it on iOS | `a trailing icon button on every row, which crowds the row` |
| `DSMenu` _(overlay)_ | `body.list` | Carried forward from the legacy control/why/rejected triple. See the per-feature plan for the role of this kit on this route. | The swipe's tappable twin — a swipe with no twin is invisible to a reader using VoiceOver | `nothing — the swipe alone` |
| `DSSearchBar` _(chrome)_ | `body.scroll` | Carried forward from the legacy control/why/rejected triple. See the per-feature plan for the role of this kit on this route. | Search in place, not a separate search route | `a search icon that pushes a full-screen search route` |

**Best practices — Accessibility**

- Each row announces habit name + current streak + filter status
- Swipe-to-archive has a confirm step so a misfire is recoverable

**Best practices — Design-system rules**

- Every control from the kit; no inline Theme.of(context) colours

**Best practices — Verification**

- Text scale 2.0: filter chips do not overlap the search field
- Pull-to-refresh works on every filter state

**Best practices — Non-goals**

- Bulk-edit across multiple habits

**Gestures (2)**

| Selector | Event | Behaviour | Haptic |
| --- | --- | --- | --- |
| `DSDismissibleTile` | `swipe` | archives the habit, with undo in a snack bar | mediumImpact |
| `DSListTile` | `tap` | pushes /habit/:id | none |

**Journeys (2)**

- **Find a habit and open it** ✓ happy path
  - `/habits → search → tap row → /habit/:id`
- **Archive the wrong habit**
  - `/habits → swipe → undo`

**APIs required**

- **Entities:** Habit

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/habits` | no | list every habit |
| DELETE | `/habits/:id` | no | archive a habit (soft delete) |

- **Providers:** habitsRepositoryProvider

| From | To | Note |
| --- | --- | --- |
| `today_page` | `/habits` | 'See all' link in the bento's footer |

**Blast radius**

```
new (2)
  ├── lib/screens/habits/habit_list_page.dart
  └── test/screens/habit_list_page_test.dart

changed (2)
  ├── lib/utils/app_router.dart
  └── lib/utils/app_routes.dart
```

**Sprint**

- order `2`, size `M`, depends on home

Verification gate:
- `flutter test test/screens/habit_list_page_test.dart`
- `make ui-probe`

### Habit detail · `/habits/:id`

Archetype: `detail` — one habit, with its streak history and edit access

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│ ‹                                ⋯ │
├────────────────────────────────────┤
│ Habit detail                       │
│ 12-day streak                      │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ This week                      │ │
│ │ ────────────────────────────── │ │
│ │ Mon · done   ✓                 │ │
│ │ Tue · done   ✓                 │ │
│ │ Wed · today  ·                 │ │
│ │ Thu          ·                 │ │
│ │ Fri          ·                 │ │
│ │ Sat          ·                 │ │
│ │ Sun          ·                 │ │
│ └────────────────────────────────┘ │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ History                        │ │
│ │ ────────────────────────────── │ │
│ │ Best streak    21d             │ │
│ │ Completions     98             │ │
│ │ Started      Nov 4             │ │
│ └────────────────────────────────┘ │
├────────────────────────────────────┤
│ [ ● ] [           Edit           ] │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ An archived habit    │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ reads 'Archived on   │   │ This habit could not │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ <date>' and offers   │   │ be opened. Back to   │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ Unarchive.           │   │ list.                │
│                      │   │                      │   │                      │
│                      │   │ [ Edit ]             │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max    retry, never a raw error
```

Success: Detail renders and the pinned bar stays put while it scrolls.

**Look & feel**

- **Header:** DSLargeAppBar; subtitle is the streak count; overflow menu holds Pause / Archive
- **Motion:** Day cells highlight on tap with a 150ms fade, no other motion
- **Dark mode:** Section background uses surface-1; the today cell uses action.tint at 10% alpha

**Layout (region → kit)**

| Region | Kit | Purpose |
| --- | --- | --- |
| `header` | `DSLargeAppBar` | — |
| `body.scroll` | `DSSettingsSection` | — |
| `footer` | `DSPinnedActionBar` | — |

scroll `scrollable_header_pinned_footer` · pinned: `header`, `footer` · safe area ✓ top · safe area ✓ bottom

**Components (2)**

| Kit | Region | Purpose | Why | Not |
| --- | --- | --- | --- | --- |
| `DSPinnedActionBar` _(chrome)_ | `footer` | Carried forward from the legacy control/why/rejected triple. See the per-feature plan for the role of this kit on this route. | Edit must not scroll away on a long history; the pinned bar is what makes Detail the archetype it is | `a FAB, which covers the last row of the history` |
| `DSMenu` _(overlay)_ | `header` | Carried forward from the legacy control/why/rejected triple. See the per-feature plan for the role of this kit on this route. | Pause and Archive are destructive — they go in the overflow, not in a row of three buttons | `two more buttons next to Edit` |

**Best practices — Accessibility**

- Day cells are tappable and announce the date + completion state
- Edit button has the same hit area as the screen's primary tap targets

**Best practices — Design-system rules**

- No inline Theme.of(context).primary — every colour from tokens

**Best practices — Verification**

- Long content (180-day history) still has the pinned bar above the safe area

**Best practices — Non-goals**

- Graphing the streak. Counts and a list are enough.

**Gestures (1)**

| Selector | Event | Behaviour | Haptic |
| --- | --- | --- | --- |
| `edge of the detail page` | `swipe` | pops back to the list (iOS edge-swipe) | none |

**Journeys (1)**

- **Edit from the detail view** ✓ happy path
  - `/habit/:id → Edit → /habit/:id/edit → save → back`

**APIs required**

- **Entities:** Habit, Completion

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/habits/:id` | no | fetch one habit with its history |

- **Providers:** habitDetailProvider

| From | To | Note |
| --- | --- | --- |
| `habit_list_page` | `/habits/:id` | the row tap |

**Blast radius**

```
new (2)
  ├── lib/screens/habits/habit_detail_page.dart
  └── test/screens/habit_detail_page_test.dart

changed (2)
  ├── lib/utils/app_router.dart
  └── lib/utils/app_routes.dart
```

**Sprint**

- order `3`, size `L`, depends on habit-list

Verification gate:
- `flutter test test/screens/habit_detail_page_test.dart`
- `make ui-probe`

### Edit habit · `/habits/:id/edit`

Archetype: `form` — create or edit a habit's name, time, and reminder

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│ ‹ Edit habit                       │
├────────────────────────────────────┤
│ Name                               │
│ [ Read 10 pages                  ] │
│                                    │
│ Reminder time                      │
│ [ 8:00 AM                        ] │
│ Local notifications fire daily     │
│                                    │
│ Days                               │
│ [ Every day                      ] │
│ Tap to change                      │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
├────────────────────────────────────┤
│ [              Save              ] │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ A new habit opens    │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ with the name field  │   │ This habit could not │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ focused.             │   │ be saved. Nothing    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │                      │   │ was lost.            │
│                      │   │ [ Save ]             │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max    retry, never a raw error
```

Success: Save returns to the detail page with the new values on it.

**Look & feel**

- **Header:** DSAppBar with title 'New habit' or 'Edit habit', cancel on the left
- **Motion:** Field focus animates the helper label up; nothing else moves
- **Dark mode:** Field background uses surface-2; helper uses textTheme.bodySmall

**Layout (region → kit)**

| Region | Kit | Purpose |
| --- | --- | --- |
| `header` | `DSCompactAppBar` | — |
| `body.scroll` | `DSTextField` | — |
| `footer` | `DSPinnedActionBar` | — |

scroll `scrollable_header_pinned_footer` · pinned: `header`, `footer` · safe area ✓ top · safe area ✓ bottom

**Components (2)**

| Kit | Region | Purpose | Why | Not |
| --- | --- | --- | --- | --- |
| `DSTextField` _(input)_ | `body.form` | Carried forward from the legacy control/why/rejected triple. See the per-feature plan for the role of this kit on this route. | It owns the label-above / helper-below contract — when validation fires, the layout does not jump | `TextFormField, which ui-lint rejects anyway` |
| `DSPinnedActionBar` _(chrome)_ | `footer` | Carried forward from the legacy control/why/rejected triple. See the per-feature plan for the role of this kit on this route. | Save is full-width and above the safe area, the Form archetype's only legal primary placement | `a floating Save button, which is the desktop pattern` |

**Best practices — Accessibility**

- Each field's label is read with the field, not above it
- Validation errors replace the helper, not the label

**Best practices — Design-system rules**

- Field spacing uses spacing.field, not arbitrary gaps

**Best practices — Verification**

- Keyboard avoidance: the pinned bar stays above the keyboard, the focused field stays visible

**Best practices — Non-goals**

- Inline habit icon picker. Ship a placeholder for the MVP.

**Gestures (1)**

| Selector | Event | Behaviour | Haptic |
| --- | --- | --- | --- |
| `primary button` | `tap` | saves the habit and pops | lightImpact |

**Journeys (1)**

- **Create a habit from scratch** ✓ happy path
  - `/habits → FAB → /habit/new → save → /habits`

**APIs required**

- **Entities:** Habit

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/habits` | no | create a habit |
| PUT | `/habits/:id` | no | update a habit |

- **Providers:** habitsRepositoryProvider

| From | To | Note |
| --- | --- | --- |
| `habit_detail_page` | `/habits/:id/edit` | the pinned Edit button |
| `habit_list_page` | `/habits/new` | the primary Add button |

**Blast radius**

```
new (3)
  ├── lib/screens/habits/habit_edit_page.dart
  ├── lib/screens/habits/habit_new_page.dart
  └── test/screens/habit_edit_page_test.dart

changed (1)
  └── lib/services/notifications/notification_service.dart
```

**Sprint**

- order `4`, size `L`, depends on habit-detail

Verification gate:
- `flutter test test/screens/habit_edit_page_test.dart`
- `make ui-probe`

### Stats · `/stats`

Archetype: `settings` — weekly completion ring per habit and a settings-style scroll list

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│   Stats                            │
├────────────────────────────────────┤
│ THIS WEEK                          │
│ ┌────────────────────────────────┐ │
│ │ Read 10 pages  5 / 7           │ │
│ │ Stretch        6 / 7           │ │
│ │ Drink water    7 / 7           │ │
│ └────────────────────────────────┘ │
│                                    │
│ STREAKS                            │
│ ┌────────────────────────────────┐ │
│ │ Longest       21d              │ │
│ │ Current best  12d              │ │
│ └────────────────────────────────┘ │
│                                    │
│                                    │
│                                    │
│                                    │
├────────────────────────────────────┤
│   ○ Today    ● Stats   ○ Settings  │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ Stats will appear    │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ once you start a     │   │ Stats could not be   │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ habit.               │   │ loaded. Pull to      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │                      │   │ refresh.             │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max    retry, never a raw error
```

Success: Sections render with real ratios.

**Look & feel**

- **Header:** DSLargeAppBar with 'Stats' title, no subtitle
- **Motion:** Ring fills on scroll-into-view, 300ms once, never again
- **Dark mode:** Eyebrow uses textTheme.labelSmall; rows use surface-1

**Layout (region → kit)**

| Region | Kit | Purpose |
| --- | --- | --- |
| `header` | `DSCompactAppBar` | — |
| `body.scroll` | `DSSettingsSection` | — |

scroll `scrollable` · pinned: `header` · safe area ✓ top · safe area ✓ bottom

**Components (2)**

| Kit | Region | Purpose | Why | Not |
| --- | --- | --- | --- | --- |
| `DSSettingsSection` _(grouping)_ | `body.eyebrow` | Carried forward from the legacy control/why/rejected triple. See the per-feature plan for the role of this kit on this route. | Settings-style grouped inset rows. Stats is a list of facts, not a hero page | `a Card per habit, which is the dashboard pattern` |
| `DSProgressRing` _(feedback)_ | `body.scroll` | Carried forward from the legacy control/why/rejected triple. See the per-feature plan for the role of this kit on this route. | The completion ratio is the dominant fact; a ring encodes ratio without a legend | `a progress bar, which encodes completion but not ratio visually` |

**Best practices — Accessibility**

- Each ratio is also written as text ('5 of 7'), so a screen reader does not need to parse the ring

**Best practices — Design-system rules**

- Ring size follows DesignSpec.progressSize.large; no hand-coded dimensions

**Best practices — Verification**

- Empty state: no habits yet, a 'Stats will appear once you start a habit' message

**Best practices — Non-goals**

- Charts beyond per-habit ratios. No line graphs, no heatmaps.

**APIs required**

- **Entities:** Habit, Completion

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/stats/weekly` | no | completion counts per habit for the last 7 days |

- **Providers:** weeklyStatsProvider

| From | To | Note |
| --- | --- | --- |
| `home_screen` | `/stats` | second tab |

**Blast radius**

```
new (2)
  ├── lib/screens/stats/stats_page.dart
  └── test/screens/stats_page_test.dart

changed (1)
  └── lib/screens/home_screen.dart
```

**Sprint**

- order `5`, size `M`, depends on home, habit-list

Verification gate:
- `flutter test test/screens/stats_page_test.dart`
- `make ui-probe`

### Settings · `/settings`

Archetype: `settings` — reminder defaults, theme, about

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│   Settings                         │
├────────────────────────────────────┤
│ REMINDERS                          │
│ ┌────────────────────────────────┐ │
│ │ Default reminder time  8:00 A… │ │
│ │ Snooze length            5 mi… │ │
│ └────────────────────────────────┘ │
│                                    │
│ APPEARANCE                         │
│ ┌────────────────────────────────┐ │
│ │ Theme       System ›           │ │
│ │ Text size  Default ›           │ │
│ └────────────────────────────────┘ │
│                                    │
│ ABOUT                              │
│ ┌────────────────────────────────┐ │
│ │ Version         1.0.0          │ │
│ │ Privacy policy      ›          │ │
│ └────────────────────────────────┘ │
├────────────────────────────────────┤
│   ○ Today    ○ Stats   ● Settings  │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ Not applicable —     │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ settings has at      │   │ Settings could not   │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ least three rows.    │   │ be loaded. Try       │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │                      │   │ again.               │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max    retry, never a raw error
```

Success: Settings render and every tap target is reachable.

**Look & feel**

- **Header:** DSAppBar with 'Settings' title, plain (no large variant)
- **Motion:** No animation; settings is a read-mostly list
- **Dark mode:** Grouped rows use surface-1, eyebrows use textTheme.labelSmall

**Layout (region → kit)**

| Region | Kit | Purpose |
| --- | --- | --- |
| `header` | `DSCompactAppBar` | — |
| `body.scroll` | `DSSettingsSection` | — |

scroll `scrollable` · pinned: `header` · safe area ✓ top · safe area ✓ bottom

**Components (1)**

| Kit | Region | Purpose | Why | Not |
| --- | --- | --- | --- | --- |
| `DSSettingsSection` _(grouping)_ | `body.eyebrow` | Carried forward from the legacy control/why/rejected triple. See the per-feature plan for the role of this kit on this route. | Grouped inset rows by what the user is changing, not by which service owns it | `a ListView of ListTiles, which is what ui-lint forbids` |

**Best practices — Accessibility**

- Each row's right value is also the focusable tap target, not just the chevron

**Best practices — Design-system rules**

- Destructive actions would live in their own bottom group (none in MVP)

**Best practices — Verification**

- Text scale 2.0: every row's right value stays inside its cell

**Best practices — Non-goals**

- Account / sign-in — auth is deferred to post-MVP

**APIs required**


- **Providers:** settingsProvider

| From | To | Note |
| --- | --- | --- |
| `home_screen` | `/settings` | third tab |

**Blast radius**

```
new (2)
  ├── lib/screens/settings/settings_page.dart
  └── test/screens/settings_page_test.dart

changed (1)
  └── lib/screens/home_screen.dart
```

**Sprint**

- order `6`, size `S`, depends on home

Verification gate:
- `flutter test test/screens/settings_page_test.dart`

## Shared entities

- **Habit** — id, name, createdAt, reminderTime (TimeOfDay), daysOfWeek (List<int>), archivedAt (DateTime?), pausedAt (DateTime?)
- **Completion** — id, habitId (FK), date (DateOnly), createdAt

## Shared providers

- habitsRepositoryProvider — owns CRUD + completion writes
- notificationServiceProvider — schedules daily local notifications

## Shared mocks

- GET /habits → list of Habit
- GET /habits/today → list of { habit, completion }
- GET /habits/:id → Habit + last-30-days completions
- POST /habits/:id/check → 204
- POST /habits → Habit
- PUT /habits/:id → Habit
- DELETE /habits/:id → 204
- GET /stats/weekly → list of { habit, completed, total }

## Open questions

- Notification time when user has set 'do not disturb': fall back silently or surface a setting? (deferred to post-MVP)
- Should 'archive' be undoable for 5 seconds, or require an Unarchive from Settings? (default to undo)

## Sprint order

| # | Route | Size | Depends on |
| --- | --- | --- | --- |
| 1 | `home` | `M` | — |
| 2 | `habit-list` | `M` | home |
| 3 | `habit-detail` | `L` | habit-list |
| 4 | `habit-edit` | `L` | habit-detail |
| 5 | `stats` | `M` | home, habit-list |
| 6 | `settings` | `S` | home |

## DS component inventory

9 distinct kit components across 6 routes. Sorted by reuse count descending; a kit used by 3+ routes is the visual vocabulary of the app, a kit used by exactly one deserves a second look.

| Kit | Used by | Uses |
| --- | --- | --- |
| `DSMenu` _(overlay)_ | `habit-detail`, `habit-list` | 2 |
| `DSPinnedActionBar` _(chrome)_ | `habit-detail`, `habit-edit` | 2 |
| `DSSettingsSection` _(grouping)_ | `settings`, `stats` | 2 |
| `DSDismissibleTile` _(row)_ | `habit-list` | 1 |
| `DSLargeAppBar` _(chrome)_ | `home` | 1 |
| `DSListTile` _(row)_ | `home` | 1 |
| `DSProgressRing` _(feedback)_ | `stats` | 1 |
| `DSSearchBar` _(chrome)_ | `habit-list` | 1 |
| `DSTextField` _(input)_ | `habit-edit` | 1 |

---

Approve this before any file under `lib/` is written. Every frame
above is drawn from this superplan's JSON, so the picture and the
build cannot drift; the archetypes are the twelve in
`docs/principles/screen-archetypes.md`, which every demo screen names
and `test/screens/archetypes_test.dart` holds them to.
