# Constraints

Required reading before adding a dependency or changing theme tokens.

## Dependencies (`pubspec.yaml`)

MUST be true of any new dependency:

- Pinned to a `^` minor version, not `any`.
- Justified in `DECISIONS.md` (what problem it solves, what was rejected).
- Maintained — last release within ~12 months, no `discontinued: true`.
- Compatible with the existing analyzer (`flutter analyze` must still pass).

MUST NOT:

- Add a dependency for a one-off helper that fits in `lib/utils/` in
  < 50 lines.
- Add a state-management library (the project standard is Riverpod).
- Add a UI kit that replaces the design system (build into
  `lib/design_system/` instead).
- Add a logging framework without a `DECISIONS.md` entry — `debugPrint`
  is the current default.

## Theme tokens

MUST be true of any change to `lib/theme/`:

- Token names stay generic (`primary`, `surface`, `outlineVariant`). No
  feature-specific names (`todoBadge`, `cartHighlight`).
- New constants live in one of the existing token files; do not create a
  new file for a single token.
- `AppColors.lightScheme` and `AppColors.darkScheme` stay in lockstep —
  if you add a token to one, add it to the other.
- `ColorScheme` properties used in `AppTheme._buildTheme` are real Material
  3 properties, not invented names.

MUST NOT:

- Hard-code a `Color(0xFF...)` outside of `lib/theme/`. Use
  `Theme.of(context).colorScheme.<token>` from widgets.
- Reference `priority*` colors — they were removed when the todo domain was
  carved out. If you need a domain-specific accent, add a generic token
  (`accentRed`, `accentGreen`) and document the mapping in `DECISIONS.md`.

## Design system

MUST be true of any new `DS*` widget:

- Single file under `lib/design_system/`.
- Exported from `lib/design_system/design_system.dart`.
- Public API has no dependency on app providers or app models. Private
  helpers (prefixed `_ds_`) may use providers but must be private to the
  design system.
- Takes its styling from the theme — no hard-coded colors, padding, or
  font weights outside of token references.

## Layout & alignment

The house style: **content controls span the full content width and stay
aligned to the page gutters.** No shrink-wrapped widgets floating mid-row, no
uneven columns.

MUST be true of any screen or `DS*` widget that adds interactive/content
elements:

- Page content columns use `crossAxisAlignment: CrossAxisAlignment.stretch`
  (or explicit `width: double.infinity`) so children fill the column.
- Primary actions use `DSButton(isFullWidth: true)`. Forms, list rows, cards,
  and standalone pickers fill the available width.
- Multi-option controls (segmented buttons, button rows) give every option
  **equal width** — wrap each in `Expanded`, don't let intrinsic content sizing
  make them uneven.
- Labels inside fixed-width segments are **single line**: `maxLines: 1`,
  `softWrap: false`, `overflow: TextOverflow.ellipsis`. Text must never wrap a
  control to two lines.
- Left/right edges align to `AppSpacing.pageGutter` (the editorial gutter), not
  ad-hoc padding.
- Don't double up container spacing. `DSCard` already applies its own padding
  *and* margin — don't wrap its `child` in another `Padding`, and inside a
  page that's already guttered pass `margin: EdgeInsets.zero` so the card spans
  the content width instead of insetting twice.

The compact exception: a control in a tight slot (e.g. a settings row's
`trailing:`) may shrink-wrap. Make that explicit (e.g. `DSSegmentedButton(
fillWidth: false)`), don't let it happen by accident.

## Mock backend

MUST be true of any mock-route addition:

- Route registered in `lib/data/mock/mock_routes.dart`.
- Backing state lives in `lib/data/mock/mock_store.dart`.
- Realistic latency via `delay: _mockLatency`.
- Returns JSON shapes that match the real backend (when one exists).

## Verification

MUST be true at the end of every session:

- `flutter analyze` reports 0 errors.
- `flutter test` reports `All tests passed!`.
- `./init.sh` exits 0 on a fresh shell.

## Design System Usage

<!-- ux-layer:v1 -->

The design-system atoms are the ONLY approved way to build UI. Hand-rolling a
raw element that an atom already covers fails lint and code review.

### Raw element -> atom mapping

| Raw element | Use instead |
| --- | --- |
| InkWell-as-button | `ds_*` button widgets |
| `Text(style: TextStyle(color: Color(0xFF...)))` | theme scheme roles (`Theme.of(context).colorScheme`) |

### Colors are tokens only

Use semantic tokens (`primary`, `muted`, `destructive`, ...) — never raw
hex/rgb values in components. Theme changes must work without touching app code.

### Do / Don't

```tsx
// DO — variant + size carry the styling
<Button variant="outline" size="sm">Cancel</Button>

// DON'T — hand-rolled styling duplicates the atom
<button className="rounded-md border px-3 ...">Cancel</button>
```

### Flutter notes

- Buttons: `ds_*` widgets only — no raw `InkWell`-as-button.
- Colors: theme scheme roles only; hardcoded hex fails lint.

