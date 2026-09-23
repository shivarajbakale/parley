// Design-system reference generator — the half of `ui_lint` that makes it fair.
//
// `tool/ui_lint.dart` fails a screen that hand-rolls a control the kit already
// owns. That rule is only reasonable if the kit is findable. Forty-four widgets
// live in `lib/design_system/`, thirty-three of them carry a doc comment, and
// the only way to learn what the other eleven do is to open them one at a time.
// An agent that cannot find `DSListTile` in one pass writes a `ListTile`, and
// then argues with the lint.
//
// So the kit describes itself. This walks `lib/design_system/*.dart` and writes
// `docs/references/design-system-reference-llms.txt`: every component, the job
// it is for, the neighbour it gets confused with, its constructors and their
// parameters, its enums and their values, and the companion classes shipped
// alongside it. One file, read in one pass, before composing a screen.
//
// The `use` / `instead` halves are curated by hand in `_selection` below,
// because they are the half a parser cannot produce. `instead` is the useful
// half: "use DSDialog for dialogs" teaches nothing, while "DSDialog when the
// answer blocks the next step, DSBottomSheet when it does not" is the decision
// somebody is actually making. A component with no entry fails the build, so a
// widget cannot join the kit with no guidance attached.
//
// Deterministic on purpose — no timestamp, no directory ordering — so
// `--check` can compare byte-for-byte and say "the reference is stale" instead
// of rewriting a file underneath somebody's checkout.
//
// Two targets on purpose. `make design-system-reference` verifies and is what
// `make check` depends on; `make design-system-reference-update` rewrites the
// file. A gate that silently rewrites the tree it is checking cannot fail.

import 'dart:io';

const sourceDir = 'lib/design_system';
const outFile = 'docs/references/design-system-reference-llms.txt';

/// The barrel is not a component, and a leading underscore means the file is
/// private to the design system — the same convention `ui_lint`'s barrel-drift
/// rule uses.
bool isComponentFile(String name) =>
    name.endsWith('.dart') &&
    name != 'design_system.dart' &&
    !name.startsWith('_');

// ---------------------------------------------------------------------------
// Selection guidance — hand-written, one entry per component file.
// ---------------------------------------------------------------------------

class Selection {
  /// The job this component is for, stated so a wrong fit is obvious.
  final String use;

  /// The neighbour reached for by mistake, and the question that separates
  /// them. This is the half that earns the file.
  final String instead;

  const Selection({required this.use, required this.instead});
}

const _selection = <String, Selection>{
  'ds_ground': Selection(
    use:
        'Wrapping a page scaffold so the page sits on the identity\'s colour wash '
        '(`ChromeSpec.groundWash`). `DSPage`, `DSFormPage` and the home shell already do; a '
        'screen built on a bare `Scaffold` wraps it the same way. Inside it scaffolds paint '
        'no fill, the ground stays opaque, and an identity with no wash gets its child back.',
    instead:
        'A `Container` with a gradient behind one screen\'s scaffold — the wash is the '
        'identity\'s, so it belongs in the spec and reaches every page at once. For a '
        'raised white surface on the wash use `DSCard`.',
  ),
  // ── Action ────────────────────────────────────────────────────────────────
  'ds_button': Selection(
    use:
        'A tap causes something to happen — submit, confirm, run, open. Five variants, one '
        'meaning each: `primary` (the one action this screen is for, at most one per view), '
        '`secondary` (a real action that is not the main one), `outlined` (secondary weight '
        'where a fill would compete with the content behind it), `ghost` (available but must '
        'not draw the eye — Cancel, Skip, Show more) and `destructive` (removes something the '
        'user cannot get back).',
    instead:
        '`DSIconButton` when the icon alone carries the meaning and there is no room for a '
        'label — there is no `isIconOnly` here, because a label-less button skips the tooltip '
        'and the semantic label a `DSIconButton` requires. `DSFab` for the one screen-level '
        'action that floats above the content. `DSCard(onTap:)` where a button that looks '
        'like a card was wanted. For a green, amber or blue button, no variant: '
        '`style: DSButtonStyle(fillColor:, labelColor:)` at whichever layer suits — a green '
        '"Retry" is still a secondary action, and a status usually belongs on a `DSMessage` '
        'rather than on a button.',
  ),
  'ds_text': Selection(
    use:
        'Every string the app draws. Pass the `DSTextRole` that says what the string is — '
        '`pageTitle`, `eyebrow`, `itemTitle`, `itemMeta`, `fieldError`, `metric`, `control`, '
        '`count` and thirteen more — and the step, the grey, the weight, the tracking, '
        'the casing, the line limit, the ellipsis, the tabular figures, the text-scale ceiling '
        'and the heading semantics all arrive with it. `DSText.rich` with `DSTextSpan` for a '
        'line whose runs differ, so an emphasised word does not have to leave the system.',
    instead:
        'A raw `Text` with `Theme.of(context).textTheme.x.copyWith(...)` — that is this '
        'decision re-made per call site, and it is what left twenty-one places clipping with '
        'no ellipsis and three `semanticsLabel`s across two hundred and thirty-seven strings. '
        'The question that separates the roles is what the string *is*, never how big it '
        'looks: a row\'s supporting line is `itemSubtitle` and a field\'s is `fieldHelper`, '
        'and they are the same size today only because the scale currently puts them there. '
        'A one-off that no role fits is `style: DSTextStyle(...)` at layer 4, not a new role.',
  ),
  'ds_hero': Selection(
    use:
        'The plate that heads the first screen of a flow — sign-in, sign-up, '
        'a paywall, a first-run welcome. It is the one component whose job is '
        'to say what app this is: a brand mark, a wash of the accent and the '
        "page{2019}s own ground rising over it on a sheet radius.",
    instead:
        'DSPageHeader for every screen after the first, where the question is '
        '"where am I" rather than "what is this"; DSLargeAppBar when the '
        'title has to collapse as content scrolls under it, which a hero '
        'never does. If the screen has a hero it does not also have a header.',
  ),
  'ds_icon_button': Selection(
    use:
        'An action with no label, where the glyph is unambiguous AND space genuinely does not '
        'allow one — an app bar, a card corner, a list trailing slot. Two variants: '
        '`standard` for an action that must be available without competing with the content, '
        '`filled` for the one prominent icon action on a surface. `semanticLabel` is required '
        'and the tooltip defaults to it; `tone` carries meaning; a toggle passes '
        '`selectedIcon` so the fill is not the only signal; `DSIconButtonGroup` keeps the '
        'targets 8dp apart.',
    instead:
        'A labelled `DSButton` in a form or a pinned action bar, always — an icon that '
        'needs its tooltip to be understood in a primary action position is a design smell. '
        'The set a reader knows unlabelled is small: search, home, close, share, add, delete, '
        'settings. `DSMenu` when there are more than two of them in one slot. A tonal or '
        'outlined icon button is `DSIconButtonStyle` in `ThemeData`, set once, not a variant '
        'passed at every call site.',
  ),
  'ds_fab': Selection(
    use:
        'The single most likely action on a screen, floating above the content.',
    instead:
        '`DSButton` inside the layout when the action belongs to a section rather than the '
        'screen. Two FABs on one screen means neither is the primary action.',
  ),
  'ds_menu': Selection(
    use:
        'Three to seven actions on one item, opened from an overflow affordance.',
    instead:
        '`DSSelect` when the rows are values rather than commands — a menu performs and '
        'closes, a select reports. `DSBottomSheet` past eight actions, or when they need '
        'descriptions at size. `DSDialog` when the choice needs explaining before it is made.',
  ),
  'ds_component_style': Selection(
    use:
        'Extending it to give a new component a style object, so the component can be '
        'restyled by an identity, a theme extension, a `DSScope` or a `style:` argument '
        'without being edited. `DSCardStyle` is the worked example.',
    instead:
        '`DSScope` when what a container wants to say is only size, density, tone or '
        'enabled — those four are the scope layer, not a style object. And nothing at all '
        'for a component with no appearance of its own: a style class with one field that '
        'nobody overrides is ceremony.',
  ),
  'ds_scope': Selection(
    use:
        'In a container, to give the controls inside it a default size, density, tone or '
        'enabled state — a footer whose buttons are small without every call site saying '
        'so. Read it with `DSScope.sizeOf(context)` and let an explicit argument win.',
    instead:
        'A `style:` argument for one instance, a `ThemeExtension` for a whole screen, and '
        '`ComponentSpec` for the whole app. Scope is the layer between the last two, and '
        'it carries only those four properties — colour, padding and type stay in the '
        'style chain.',
  ),
  'ds_pressable': Selection(
    use:
        'Wrapping something tappable that is not already a kit component, to give it the '
        'kit’s press dip — a spring on Android, a curve on Apple, nothing under reduced motion.',
    instead:
        'Nothing, if the thing being pressed is already a `DSButton`, `DSCard` or `DSChip`: '
        'they wrap it themselves, and a second wrap dips twice. It observes the press from a '
        '`Listener` and never takes the tap, so the widget underneath keeps its own callback.',
  ),

  // ── Input ─────────────────────────────────────────────────────────────────
  'ds_date_strip': Selection(
    use:
        'Picking a day that is near a reference day, where seeing the neighbouring days is '
        'part of the decision — booking, scheduling, a log, an agenda.',
    instead:
        '`showDatePicker` for a date that is far away or exact: a birth date, a deadline in '
        'March. For a date *range* nothing here yet — a range has a different model, different '
        'semantics and different cell painting, so it is a component of its own rather than a '
        'flag on this one.',
  ),
  'ds_stepper': Selection(
    use:
        'A small, bounded quantity the user adjusts rather than types — a count, a party '
        'size, a rating, a repeat interval.',
    instead:
        '`DSTextField` with a numeric keyboard when the quantity is large or unbounded; a '
        'stepper there is a lot of taps. `DSSlider` when the feel of the position matters '
        'and precision does not. `DSSwitch` for two states.',
  ),
  'ds_text_field': Selection(
    use:
        'The user types free text. One skin, one geometry; the helper slot is reserved so an '
        'error never moves the form, and the label is always drawn — `hintText` is an example, '
        'never a replacement for it.',
    instead:
        '`DSSelect` or `DSSegmentedButton` for one value from a known set. `DSStepper` for a '
        'bounded number. `DSDateStrip` or `showDatePicker` for a date. `DSSearchBar` when typing '
        'filters a list in place rather than filling a field that gets submitted.',
  ),
  'ds_control_tile': Selection(
    use:
        'A labelled row whose trailing edge carries a control — a checkbox, a switch, a '
        'radio. `DSCheckboxTile`, `DSSwitchTile` and `DSRadioTile` are the three shipped '
        'shapes. The whole row is the target, the control state is published once for the '
        'row, and the geometry is `DSListTile`\'s by construction, so a settings row and a '
        'list row are the same height.',
    instead:
        'a bare `DSCheckbox` or `DSSwitch` when there is no label to hang the row on — a '
        'control in a toolbar, a checkbox in a table cell. `DSListTile` when the trailing '
        'edge reports rather than sets: a version number is not a control.',
  ),
  'ds_radio': Selection(
    use:
        'One choice from two to about six, all visible at once, where the options need a '
        'sentence each. Always inside a `DSRadioGroup`, which owns the value and the '
        'exclusivity — a radio outside one asserts rather than rendering an unmanaged '
        'circle.',
    instead:
        '`DSSegmentedButton` when the options are one or two words and the choice is a view '
        'rather than an answer. `DSSelect` past six options. `DSCheckbox` when more than one '
        'may be on at once.',
  ),
  'ds_pull_quote': Selection(
    use:
        'One sentence lifted out of an article, so a reader who is skimming stops on the '
        'line that carries the piece. A rule in the accent down the start edge and one step '
        'up the type scale — the rule spans the words, however many lines they take.',
    instead:
        '`DSMessage` when the words are the app talking to the reader rather than the piece '
        'talking about itself, and a plain `Text` when the sentence is simply the next '
        'sentence. Never a filled `DSCard`: a reading column has one surface, and a second '
        'one inside it reads as a widget rather than as a quote.',
  ),
  'ds_well': Selection(
    use:
        'The tinted container behind a glyph — a list row\'s leading mark, a dialog\'s icon, '
        'a sidebar\'s brand. Takes a `tone` or a category `hue` and reads the identity\'s '
        'derived container/on-container pair, so it is legible in both themes without any '
        'call site naming a colour.',
    instead:
        '`DSAvatar` when the thing behind the glyph is a person or an entity with an image '
        'and initials. `DSBadge` when the shape carries a word rather than a glyph. A bare '
        '`Icon` when there is no container — a well around every icon is a page of '
        'coloured circles.',
  ),
  'ds_illustration': Selection(
    use:
        'A drawn scene for a moment that happens once or rarely — first run, onboarding, a '
        'full-screen failure, a permission ask, a paywall. Six kinds painted from the '
        'palette, so they recolour with the identity; one pass of motion and then still, '
        'and the last frame under reduced motion. Install a `DSIllustrationScope` with your '
        'own `DSIllustrationDelegate` to replace all six with a designer\'s Lottie or Rive '
        'without the kit depending on either.',
    instead:
        'a glyph in a `DSWell` — which is what `DSEmptyState` draws by default — for an '
        'ordinary empty state, and nothing at all for an empty filter result inside a list, '
        'where a drawing above every result is noise. `DSSkeleton` while content is still '
        'arriving: an illustration says the screen has settled.',
  ),
  'ds_image': Selection(
    use:
        'A picture the app did not ship in its bundle — a remote thumbnail, a hero, a photo '
        'from the API. It draws the box at its final size before a byte arrives (so nothing '
        'under it reflows), shimmers while it waits, fades the first frame in unless it came '
        'from the cache or the device asked for less motion, and falls back to one glyph on '
        'the well when it never arrives. `DSImage.provider` takes any `ImageProvider`, which '
        'is where a disk cache from a package plugs in.',
    instead:
        '`DSAvatar` for a person or an account — it is round, it carries the initials '
        'fallback and the presence ring, and it is the one picture with a name attached. '
        '`DSMediaRow` for a row and `DSMediaTile` for a grid cell, and `DSIllustration` '
        'for a drawn scene, which is not a fetch and has no failed state. A raw `Image.asset` only for '
        'something the build guarantees is there and that carries no state — a logo in the '
        'app bar; `ui_lint` fails a network image anywhere else, because the three states '
        'above are what gets left out.',
  ),
  'ds_status_state': Selection(
    use:
        'The screen when it has no content to show: `DSEmptyState` for nothing yet, '
        '`DSEmptyState.noResults` for a filter that matched nothing, and `DSErrorState` when '
        'the content failed to load. All three share one style object, so an empty screen '
        'and a failed screen cannot drift apart.',
    instead:
        '`DSMessage` when there is content and the state is a condition alongside it. '
        '`DSSkeleton` while the content is still arriving — an empty state shown during a '
        'load says the wrong thing and then replaces itself.',
  ),
  'ds_bottom_insets': Selection(
    use:
        'Wrap a screen\'s scaffold in `DSBottomInsetsHost` so the snack bar, the floating '
        'action button and the pinned action bar know what else is at the bottom of the '
        'screen. Components report their own measured heights into it; the screen reads '
        '`DSBottomInsets.of(context).scrollPadding` for its scroll view.',
    instead:
        'nothing — there is no second mechanism. Hand-computing an offset at a call site is '
        'what this replaces, and it is wrong the moment the text scale, the helper line or '
        'the home indicator changes.',
  ),
  'ds_checkbox': Selection(
    use:
        'Independent binary choices where zero or many may be on, and multi-select rows.',
    instead:
        '`DSSwitch` when the change applies the instant it flips with nothing to save. '
        '`DSSegmentedButton` when exactly one of a small set may be on.',
  ),
  'ds_switch': Selection(
    use: 'A setting that takes effect immediately, with no save step.',
    instead:
        '`DSCheckbox` inside a form that is submitted — a switch implies the change already '
        'happened, and a switch that needs a Save button is a lie.',
  ),
  'ds_slider': Selection(
    use:
        'A continuous value where the approximate position matters more than the exact number.',
    instead:
        '`DSTextField` when the user knows the number and typing it is faster than aiming.',
  ),
  'ds_select': Selection(
    use:
        'One value from a list too long for segments and short enough to scan — roughly 4 to '
        '20 — or several, through `DSMultiSelect`. Rows are `DSSelectOption` widgets, so an '
        'avatar, a badge, a second line or a disabled row with a reason are all composition. '
        'The list separates its options the way the identity asked for — `DSSelectSeparator` '
        'follows `component.dividerPolicy`, the same switch `DSListTile` reads — and draws '
        'one between every pair of options and nowhere else, so a section header keeps the '
        'rows it labels and the last row has no floor under it.',
    instead:
        '`DSSegmentedButton` at four or fewer, where showing all the options costs nothing. '
        '`DSMenu` when the rows are actions rather than values. `DSChipGroup` for filters '
        'that stay visible.',
  ),
  'ds_segmented_button': Selection(
    use: 'Two to four mutually exclusive options, all visible at once.',
    instead:
        '`DSTabBar` when the choice switches between *views* rather than setting a value. '
        '`DSSelect` past four segments — they stop fitting the width.',
  ),

  // ── Navigation & chrome ───────────────────────────────────────────────────
  'ds_pinned_header': Selection(
    use:
        'A search field, a filter strip or a tab bar that has to stay on screen while the list '
        'under it scrolls. It is a sliver and takes its height from its child, so a band of chips '
        'is the height of its chips at any text size; stack as many as the screen needs and each '
        'pins under the one before it.',
    instead:
        '`DSPageHeader.sliver`\'s `below` slot when the control belongs to the title block and '
        'should collapse with it. A plain `SliverToBoxAdapter` when the band is content and may '
        'leave. `DSPinnedActionBar` for the bottom edge.',
  ),
  'ds_pinned_action_bar': Selection(
    use:
        'The screen\'s primary action, pinned to the bottom edge over the content.',
    instead:
        '`DSFab` when the action is a shortcut rather than the step the screen exists for. A '
        'button inside the scroll when the user may reasonably never reach it.',
  ),
  'ds_bottom_nav_bar': Selection(
    use:
        'Three to five top-level destinations, each with its own navigation stack. The count is '
        'asserted, not suggested. Badge the destination that has news, never the app, and give '
        'the selected destination a filled `selectedIcon` so selection survives greyscale.',
    instead:
        '`DSSidebar` at six or more destinations, or on a tablet width. `DSTabBar` for peer '
        'views inside one destination — a tab is not a destination. `DSSegmentedButton` when '
        'there are only two. A bar and a drawer are alternatives, not layers.',
  ),
  'ds_sidebar': Selection(
    use:
        'Six or more destinations, or secondary destinations that do not deserve a bar slot.',
    instead:
        '`DSBottomNavBar` when there are five or fewer and they are used constantly — a drawer '
        'hides them behind a tap.',
  ),
  'ds_tab_bar': Selection(
    use: 'Two or more peer views of the same subject, switched in place.',
    instead:
        '`DSContentSection` when the sections are read together rather than instead of each '
        'other. `DSBottomNavBar` when they are separate destinations with their own stacks.',
  ),
  'ds_large_app_bar': Selection(
    use:
        'A screen whose header carries something beyond its name — a headline, a subtitle, an '
        'eyebrow, a tab strip — and should collapse as it scrolls.',
    instead:
        '`DSCompactAppBar` when the header holds nothing but the screen’s name; `DSPageHeader` '
        'inside the scroll body when the title should stay put and the screen has no app bar '
        'of its own.',
  ),
  'ds_compact_app_bar': Selection(
    use:
        'A screen whose header is a word: a navigation bar, one line tall, no collapsing title.',
    instead:
        '`DSLargeAppBar` as soon as the header has payload — a subtitle, an eyebrow, a tab '
        'strip or actions. The `header-earns-its-height` lint picks between the two.',
  ),

  // ── Overlay ───────────────────────────────────────────────────────────────
  'ds_overlay': Selection(
    use:
        'Presenting any transient surface: `showDSOverlay` is the kit\'s only entry point, '
        'and `DSOverlaySurface` is the shape and depth for a caller presenting through a '
        'route of their own. Five presentations — sheet, dialog, popover, menu, fullScreen — '
        'share one scrim, one motion contract and one dismissal policy.',
    instead:
        '`DSBottomSheet`, `DSDialog`, `DSSelect` and `DSMenu` for the four surfaces the kit '
        'already ships; reach for this directly only when none of them is the surface.',
  ),
  'ds_dialog': Selection(
    use:
        'A decision that blocks the next step — confirm, destroy, resolve a conflict.',
    instead:
        '`DSBottomSheet` when the user may reasonably ignore it and carry on — a dialog that '
        'is safe to dismiss should not have been a dialog. `DSMessage` when nothing has to be '
        'decided, and `DSSnackBar` when it has already happened.',
  ),
  'ds_bottom_sheet': Selection(
    use:
        'Companion content or a short task, at one height or at several. Snap points are the '
        'opt-in: passing them is what makes the sheet settle at stages.',
    instead:
        '`DSDialog` when the app cannot continue until the question is answered. `DSMenu` for '
        'a short list of actions on one item.',
  ),
  'ds_snack_bar': Selection(
    use: 'Confirming something already happened, with at most one undo action.',
    instead:
        '`DSMessage` when the message must stay until it is dealt with — a snack bar leaves, '
        'and anything the user must act on cannot leave on a timer.',
  ),
  'ds_search_bar': Selection(
    use: 'Filtering a list that is already on screen, in place.',
    instead:
        '`DSTextField` when the value is submitted rather than used as you type.',
  ),

  // ── Surface ───────────────────────────────────────────────────────────────
  'ds_chat_bubble': Selection(
    use:
        'One turn in a thread, on the side of whoever said it. Carries a typed '
        '`DSChatStatus` \u2014 sending, streaming, sent, failed \u2014 because a '
        'conversation is the surface where the network is visible: a message '
        'exists in the transcript before the server acknowledges it, and a '
        'message that failed is the one thing on the screen the user can still '
        'act on.',
    instead:
        '`DSMessage` for a banner the app says about the screen. The question '
        'that separates them is whose voice it is: a turn in the conversation '
        'takes a bubble, and the app talking about the conversation does not. '
        '`DSListTile` when the rows are records rather than speech.',
  ),
  'ds_composer': Selection(
    use:
        'The bar a conversation is written in: a field that grows with the '
        'text while the bar keeps its bottom edge, a send affordance that is '
        'dead until there is something to send, and one place that clears the '
        'keyboard, the home indicator and any navigation bar under it.',
    instead:
        '`DSPinnedActionBar` when the pinned control is a decision rather than '
        'an input \u2014 Buy, Save, Continue. `DSTextField` inside a `DSPage` '
        'when the writing is a field in something that gets submitted and '
        'left, which is a different shape from a turn that gets answered.',
  ),
  'ds_card': Selection(
    use:
        'The one raised surface in the kit: a group of content that is a unit the user can '
        'act on or navigate to. Three grounds, which are the three surface roles — `elevated` '
        'on `surface` with a shadow, `filled` on `well`, `outlined` on `canvas` with a '
        'hairline. It draws no margin: the page gutter has a single owner.',
    instead:
        'N rows in a list go in **one** card, not in N cards — that is `DSListTile` inside a '
        'single `DSCard`. A figure and its label are a `DSStatTile`. A message is a `DSMessage`. '
        '`DSContentSection` when the group needs a title and a trailing '
        'action but no surface of its own. A card with `onTap` and a button inside it is a '
        'defect, not a layout: the outer gesture swallows the inner one, and a debug '
        'assertion says so.',
  ),
  'ds_message': Selection(
    use:
        'A persistent message about the state of something — icon, tone and text, staying until '
        'it is acted on or dismissed. `scope` decides placement: screen is full bleed above the '
        'content, section is inset inside it, compact is one line. `tone` decides meaning, and '
        '`neutral` is the one for state (a draft, a read-only notice) rather than information.',
    instead:
        '`DSSnackBar` when it merely confirms something that already happened — seconds, not '
        'persistence. `DSDialog` when the user must answer before anything else can happen. '
        '`DSTextField.errorText` when the message belongs to one field and should sit with it. '
        'An `error` message needs an action unless the condition genuinely clears itself.',
  ),
  'ds_avatar': Selection(
    use:
        'A person or entity’s identity, at one of four sizes, with an initials fallback.',
    instead:
        '`DSIconContainer` when the glyph is a category or an action, not an identity.',
  ),
  'ds_badge': Selection(
    use: 'A short status or count attached to something else.',
    instead:
        '`DSChip` when it is tappable — a badge is read, a chip is pressed. `DSMessage` when '
        'the status needs a sentence.',
  ),
  'ds_chart': Selection(
    use:
        'The shape of a run of numbers: `sparkline` for a trend beside a figure with no '
        'axes at all, `line` for a value over a continuous run, `bar` for a value across '
        'named categories, grouped or stacked. A series takes its hue from the identity\'s '
        'category ramp by name, so one series is one colour across the whole app and no '
        'call site picks a colour. The scrub is a long press, not a drag, so a chart '
        'inside a paged shell does not swallow the swipe to the next tab.',
    instead:
        '`DSMetricBar` when there is one value against a known ceiling and the shape is a '
        'single proportion. `DSProgressRing` when that proportion is the screen\'s subject. '
        '`DSStatTile` when the number is the message and the movement is a delta beside it '
        '\u2014 a chart drawn for three numbers is three numbers made harder to read.',
  ),
  'ds_chip': Selection(
    use:
        'Something short, secondary and one of several. Three roles, and the role is the '
        'component: `tag` is an attribute (\u201cDraft\u201d, \u201cPDF\u201d) that takes no tab stop and is read '
        'as text; `filter` is a facet the user turns on and off, announced as toggled; '
        '`input` is a value the user entered, carrying a second, separately named remove '
        'control. `DSChipGroup` owns the 8dp gaps, the overflow chip, and the '
        'selected-first order.',
    instead:
        '`DSSegmentedButton` for two to four visible, mutually exclusive options \u2014 a filter '
        'row does not tell the user only one may be on. `DSBadge` when it only reports state '
        'and nothing happens on tap. `DSSearchChip` when the row is the page\u2019s own search '
        'filters. A tint is `tone` or `markColor`, both tokens; there is no `color`, because '
        'a field typed `Color?` with no further constraint is an invitation the lint cannot '
        'decline.',
  ),

  // ── Media ─────────────────────────────────────────────────────────────────
  'ds_media': Selection(
    use:
        'Building a media shape the kit does not ship, and wanting its picture to carry the '
        'family\u2019s status vocabulary — duration, watched progress, playback, live, offline, '
        'selection, rank — exactly as the three shipped shapes do. `DSMediaSource` is also '
        'the content model all three take: one value that carries the URL or asset *and* its '
        'text alternative, so the two cannot be set inconsistently.',
    instead:
        '`DSMediaRow`, `DSMediaTile` or `DSMediaHero` first — they are this box plus a text '
        'budget, and a fourth shape composed in `lib/screens/` is what `ui_lint` fails. '
        '`DSImage` when the picture carries no status at all: it is the same three loading '
        'states with none of the overlay.',
  ),
  'ds_media_row': Selection(
    use:
        'A list of things the reader recognises by their picture: articles, episodes, tracks, '
        'files. A 64dp picture at `md` and 48 at `compact`, a two-line title, one supporting '
        'line, a wrapped row of small facts, and one trailing control that keeps its own tap '
        'target. `status` draws and speaks the media vocabulary; `menuItems` puts the same '
        'commands on a long press and on a screen reader\u2019s action rotor.',
    instead:
        '`DSListTile` when the leading graphic is a 40dp glyph rather than a picture — they '
        'are different vertical rhythms. `DSMediaTile` when the layout is a grid or a '
        'carousel rather than a vertical list. `DSDismissibleTile(child: DSMediaRow(...))` '
        'for swipe: this component deliberately does not own the gesture. If the row needs '
        'more than four title lines it has stopped being a row — that is a card.',
  ),
  'ds_media_tile': Selection(
    use:
        'A two-dimensional or horizontal layout of media: a poster grid, an album shelf, a '
        'continue-watching carousel. `width: null` fills the grid column it is given; a token '
        'width makes it a carousel item, so a `Row` of tiles is the whole carousel.',
    instead:
        '`DSMediaRow` for a vertical list — a row gives the title three times the width, '
        'which is what a long list is actually scanned in. `DSMediaHero` for the single '
        'featured item above the grid. `DSStatTile` when the cell is a figure rather than a '
        'thing, and `DSCard` when it has no picture.',
  ),
  'ds_media_hero': Selection(
    use:
        'The one featured item a surface leads with: a top story, the album a screen is '
        'about, the video a tab opens on. 16:9 across its container, text below the picture '
        'by default, and `fullBleed: true` when the media should meet the screen edge — the '
        'only member of the family permitted to drop the page gutter.',
    instead:
        '`DSMediaTile` the moment there are two of them: two heroes is a grid whose cells are '
        'too big. `DSLargeAppBar` when the thing at the top is the page\u2019s title rather '
        'than one of its items, and `DSCard` when the feature is text rather than a picture. '
        '`placement: overlay` only over a picture you control — it is opt-in for that reason, '
        'and it falls back to `below` past 1.6x text scale.',
  ),

  // ── List & structure ──────────────────────────────────────────────────────
  'ds_stat_tile': Selection(
    use:
        'One figure a reader takes in at a glance — a total, a count, a rate, a balance — '
        'with its label above it and an optional mark of which category it belongs to.',
    instead:
        '`DSProgressRing` or `DSMetricBar` when the figure has a known ceiling and the '
        'reading is the ratio rather than the number. `DSStatTileGrid` when there are '
        'several: the tile draws no surface, so a row of them is one card of cells rather '
        'than four cards. For a figure inside running text, no component — it is a `Text`.',
  ),
  'ds_list_tile': Selection(
    use:
        'A text-led row in a list: a tinted leading well, a title, a subtitle, a trailing '
        'control or chevron, one tap target. `tone` carries meaning (a destructive row is '
        '`tone: DSTone.error`), `selected` plus `selectionMode` carry choice, `meta` is the '
        'third line that does not eat the subtitle\u2019s two-line cap, and `DSListTileGroup` '
        'draws the separators the identity asked for under every row but the last.',
    instead:
        '`DSMediaRow` when the leading graphic is a 64dp picture rather than a 40dp glyph '
        '\u2014 they are different vertical rhythms. `DSStatTile` when the row is a '
        'figure rather than a destination. `DSSettingsRow` (in `ds_settings.dart`) inside a '
        'grouped settings container, which owns the hairline separators and the inset shape. '
        'A chevron promises a route: a row that opens a sheet sets `chevron: false` on its '
        'style, or the promise is broken.',
  ),
  'ds_dismissible_tile': Selection(
    use:
        'A list row that can be swiped away, with the standard delete confirmation behind it.',
    instead:
        '`DSListTile` plus a `DSMenu` when the action is rare enough that a swipe would '
        'mostly be an accident.',
  ),
  'ds_section_header': Selection(
    use: 'A title above a group, with an optional trailing action.',
    instead:
        '`DSPageHeader` for the screen’s own title — a screen with two headers at the same '
        'weight has no title.',
  ),
  'ds_form_page': Selection(
    use:
        'A screen whose job is to be filled in or chosen from, with its primary action in a '
        'pinned bar — sign-in, sign-up, create, edit, one step of a flow. The header is fixed '
        'rather than a sliver, because a reader halfway down a form with the title and the '
        'bar both scrolled away is filling in fields for an unnamed thing. It installs the '
        'bottom-inset host and ends the scroll at the height the bar reports.',
    instead:
        '`DSPage` when the content is the subject and the header may scroll away, which is '
        'nearly every other screen. `DSFormPage.fullBleed` when the rows inset their own '
        'content — a `DSListTile` inside a gutter-padded scroll is indented twice.',
  ),
  'ds_page': Selection(
    use:
        'A screen that is a title over scrolling content — nearly every screen. It '
        'installs the bottom-inset host, so a floating button and a pinned action bar '
        'can see each other, and it ends the scroll clear of both. DSPageSection and '
        'DSGutter are the only two places the page gutter is spelled.',
    instead:
        'A bare `Scaffold` when the screen has no header and no scroll at all — a '
        'splash, a full-bleed player. `DSPage.surface` when there is a header but the '
        'body manages its own space.',
  ),
  'ds_page_header': Selection(
    use:
        'The screen’s title inside the scroll body, with an eyebrow and actions.',
    instead:
        '`DSLargeAppBar` when the title should collapse into the app bar as the screen scrolls.',
  ),
  'ds_field_group': Selection(
    use:
        'A run of form fields under one eyebrow, on the page background, with a wrapping '
        'footer for the sentence too long for a field’s one-line helper.',
    instead:
        '`DSSettingsSection` when the children are rows that navigate, report or toggle. A '
        'field dropped into that section is an outline ring on identical grey, inset twice, '
        'with the row divider running between two things that are not rows.',
  ),
  'ds_settings': Selection(
    use:
        'A grouped, inset settings block — an eyebrow, hairline-separated rows, a footer note.',
    instead:
        'A `ListView` of `DSListTile`s when the rows are content rather than settings; the '
        'grouped container is what makes a settings screen read as settings.',
  ),
  'ds_theme_mode_picker': Selection(
    use: 'The light / dark / system control, wired to the theme provider.',
    instead:
        'A hand-built `DSSegmentedButton` over `ThemeMode` — this one already carries the '
        'labels, icons and provider wiring.',
  ),

  // ── State ─────────────────────────────────────────────────────────────────
  'ds_skeleton': Selection(
    use: 'Loading, when the shape of what is coming is already known.',
    instead:
        '`DSProgressIndicator` when there is no content shape to preview — a skeleton of an '
        'unknown layout is a guess the user has to unlearn.',
  ),
  'ds_divider': Selection(
    use:
        'A hairline between two adjacent blocks that are not cards — a run of rows, a menu, '
        'a stat strip. It occupies exactly its own thickness, which Material\'s Divider does '
        'not.',
    instead:
        'Whitespace first: a screen that draws a line between every pair of things has decided '
        'none of them group. `DSCard` when the block is a surface rather than a neighbour.',
  ),
  'ds_expansion': Selection(
    use:
        'Content most readers will not open, under the row that names it — an FAQ answer, a '
        '"what\'s included" list, an advanced block, the technical detail behind a failure.',
    instead:
        '`DSListTile` with an onTap when the content deserves its own route: a disclosure that '
        'opens onto three paragraphs and four controls is a screen pretending to be a row. '
        '`DSTabBar` when the sections are peers meant to be compared — an accordion hides '
        'everything but one thing, which is the opposite of comparing. Never a form field: an '
        'error on a collapsed panel is an error the user cannot see.',
  ),
  'ds_refresh': Selection(
    use:
        'A screen showing server data the user may want again — wraps the scrollable and makes '
        'the pull work on a list short enough to fit, which the raw indicator does not.',
    instead:
        'A Retry `DSButton` inside `DSStatusState` when the last load *failed*: a pull says '
        '"this is stale", and a screen showing an error has nothing to pull. Nothing at all '
        'when the data is local — pass `enabled: false` rather than teaching the gesture and '
        'then ignoring it.',
  ),
  'ds_progress_indicator': Selection(
    use:
        'An operation in flight — determinate with a value, indeterminate without.',
    instead:
        '`DSSkeleton` when the wait is for content to arrive rather than for work to finish.',
  ),
  'ds_progress_ring': Selection(
    use:
        'One value against a known ceiling, round, with the figure legible without reading '
        'the arc — a quota, a goal, a completion percentage.',
    instead:
        '`DSMetricBar` when the proportion has to be compared against its neighbours: a column '
        'of bars shares a baseline and a grid of rings does not. `DSStatTile` when there is no '
        'ceiling. `DSProgressIndicator` for work in flight — a ring with no value has nothing '
        'to put in its label, so this one has no indeterminate form.',
  ),
  'ds_segmented_progress': Selection(
    use:
        'An ordinal position in a fixed, countable sequence — step 3 of 5 — where the count '
        'itself is what the user needs: onboarding, a multi-step form, a checkout, a streak.',
    instead:
        '`DSMetricBar` past about eight steps, where the segments become stripes, with a '
        '"3 of 12" label. `DSTabBar` for unordered peers the user may visit in any order — '
        'using a tab bar for a wizard is the mistake `docs/principles/component-selection.md` '
        'names.',
  ),
  'ds_metric_bar': Selection(
    use:
        'One value against a known ceiling, linear, in one line of vertical space — and '
        '`.stacked` for parts of a whole with a legend.',
    instead:
        '`DSProgressRing` for the one hero proportion with room to breathe. '
        '`DSSegmentedProgress` for an ordinal position in a fixed sequence. '
        '`DSProgressIndicator` for a task in flight.',
  ),

  'ds_time_grid': Selection(
    use:
        'A day as a column of hours with what is booked drawn on it, for when '
        'the question is *when* and the answer is read from the shape of the '
        'day \u2014 where the gaps are, what runs long, what collides. Slots that '
        'overlap are laid side by side rather than stacked, and a slot outside '
        'the window widens the window rather than being clipped.',
    instead:
        '`DSListTile` rows under a `DSSectionHeader` when the question is '
        '*what*: an agenda of five things over ten hours is nine hours of '
        'empty grid, and the list says the same thing in a fifth of the '
        'height. `DSDateStrip` is what picks the day this draws.',
  ),
  'ds_tour': Selection(
    use:
        'A new user has to be told what the app does before they can use it, and the telling '
        'is worth the taps — which is to say the last slide hands over to something rather '
        'than merely getting out of the way. `DSTour` is the sequence; `DSTourSlide` is one '
        'stop of it, reached for directly only when you own the paging.',
    instead:
        'An empty state on the screen itself, which introduces a feature at the moment it is '
        'wanted rather than three screens early — a tour whose slides only advertise is a run '
        'of taps that produces nothing. `DSTour` itself instead of `DSTourSlide` whenever the '
        'paging is not already yours: it builds the slides from a list of `DSTourStop` and '
        'drives the offset for you.',
  ),
  'ds_tour_dots': Selection(
    use:
        'A paged sequence needs to say how long it is and how far through it you are. Driven '
        'by the live fractional scroll position, so it is already telling the truth when the '
        'finger lets go.',
    instead:
        '`DSSegmentedProgress` for a checklist, where the segments are discrete tasks that '
        'stay done — this is a position, not a score.',
  ),
  'ds_tour_art': Selection(
    use:
        'Drawing a tour slide\'s picture. `DSTourCanvas` composes it at one width so it never '
        'reflows and the caller can scale the whole board; `DSTourFillSlot` is the blank that '
        'fills in, for when the argument for the tour is that the app has something afterwards '
        'it does not have now.',
    instead:
        '`DSIllustration` for one of the six generic states the kit already draws. '
        '`DSSkeleton` instead of `DSTourFillSlot` when the content is genuinely still loading '
        '— the fill slot is a drawing of a state change and never waits on anything.',
  ),
};

// ---------------------------------------------------------------------------
// Categories — ordered; the output follows this order, then Other.
// ---------------------------------------------------------------------------

const _categories = <String, List<String>>{
  'Foundation': [
    'ds_text',
    'ds_pressable',
    'ds_component_style',
    'ds_scope',
    'ds_ground',
  ],
  'Action': ['ds_button', 'ds_icon_button', 'ds_fab', 'ds_menu'],
  'Input': [
    'ds_stepper',
    'ds_control_tile',
    'ds_radio',
    'ds_date_strip',
    'ds_time_grid',
    'ds_text_field',
    'ds_composer',
    'ds_checkbox',
    'ds_switch',
    'ds_slider',
    'ds_select',
    'ds_segmented_button',
  ],
  'Navigation & chrome': [
    'ds_bottom_nav_bar',
    'ds_sidebar',
    'ds_tab_bar',
    'ds_large_app_bar',
    'ds_compact_app_bar',
    'ds_pinned_action_bar',
    'ds_pinned_header',
    'ds_bottom_insets',
    'ds_tour',
    'ds_tour_dots',
    'ds_tour_art',
  ],
  'Overlay': [
    'ds_overlay',
    'ds_dialog',
    'ds_bottom_sheet',
    'ds_snack_bar',
    'ds_search_bar',
  ],
  'Surface': [
    'ds_card',
    'ds_image',
    'ds_message',
    'ds_pull_quote',
    'ds_well',
    'ds_avatar',
    'ds_badge',
    'ds_chip',
  ],
  'List & structure': [
    'ds_divider',
    'ds_expansion',
    'ds_stat_tile',
    'ds_list_tile',
    'ds_media',
    'ds_media_row',
    'ds_media_tile',
    'ds_media_hero',
    'ds_chat_bubble',
    'ds_dismissible_tile',
    'ds_section_header',
    'ds_page',
    'ds_form_page',
    'ds_page_header',
    'ds_hero',
    'ds_field_group',
    'ds_settings',
    'ds_theme_mode_picker',
  ],
  'State': [
    'ds_chart',
    'ds_skeleton',
    'ds_status_state',
    'ds_illustration',
    'ds_refresh',
    'ds_progress_indicator',
    'ds_progress_ring',
    'ds_metric_bar',
    'ds_segmented_progress',
  ],
};

String categoryOf(String key) {
  for (final entry in _categories.entries) {
    if (entry.value.contains(key)) return entry.key;
  }
  return 'Other';
}

// ---------------------------------------------------------------------------
// The parsed shape of a component file.
// ---------------------------------------------------------------------------

class Param {
  final String name;
  final String type;
  final bool isRequired;
  final String? defaultValue;

  const Param({
    required this.name,
    required this.type,
    this.isRequired = false,
    this.defaultValue,
  });

  String render() {
    final head = isRequired ? 'required ' : '';
    final body = type.isEmpty ? name : '$type $name';
    final tail = defaultValue == null ? '' : ' = $defaultValue';
    return '$head$body$tail';
  }
}

class Ctor {
  /// Empty for the unnamed constructor, otherwise the part after the dot.
  final String name;
  final bool isConst;
  final bool isFactory;
  final List<Param> params;

  const Ctor({
    required this.name,
    required this.params,
    this.isConst = false,
    this.isFactory = false,
  });

  String signature(String className) {
    final prefix = isFactory ? 'factory ' : (isConst ? 'const ' : '');
    final full = name.isEmpty ? className : '$className.$name';
    return '$prefix$full(…)';
  }
}

class StaticMethod {
  final String name;
  final String returnType;
  final List<Param> params;

  const StaticMethod({
    required this.name,
    required this.returnType,
    required this.params,
  });
}

class ClassDecl {
  final String name;
  final String generics;
  final String superclass;
  final List<String> doc;
  final List<Ctor> ctors;
  final List<StaticMethod> statics;

  const ClassDecl({
    required this.name,
    required this.generics,
    required this.superclass,
    required this.doc,
    required this.ctors,
    required this.statics,
  });

  bool get isPublic => !name.startsWith('_');
}

class EnumDecl {
  final String name;
  final List<String> values;
  const EnumDecl({required this.name, required this.values});

  bool get isPublic => !name.startsWith('_');
}

class TopLevelFn {
  final String name;
  final String returnType;
  final List<Param> params;
  final List<String> doc;

  const TopLevelFn({
    required this.name,
    required this.returnType,
    required this.params,
    required this.doc,
  });
}

class Component {
  /// File basename without `.dart` — the key used by `_selection`.
  final String key;
  final String path;

  /// The layer the file declares on its first line: `foundation`, `atom`,
  /// `molecule`, `organism` or `template`. It says what the component may be
  /// built from, and `tool/ui_lint.dart` fails an import that reaches above
  /// its own tier.
  final String tier;
  final List<ClassDecl> classes;
  final List<EnumDecl> enums;
  final List<TopLevelFn> functions;

  const Component({
    required this.key,
    required this.path,
    required this.tier,
    required this.classes,
    required this.enums,
    required this.functions,
  });

  /// The class the file is named after — `ds_button.dart` → `DSButton`. Falls
  /// back to the first public class, then to nothing (a file of helpers).
  ClassDecl? get primary {
    final wanted = _expectedName(key);
    for (final c in classes) {
      if (c.isPublic && c.name.toLowerCase() == wanted) return c;
    }
    // A widget before anything else. A file whose first public declaration is
    // a strategy interface or a style object still ships a *component*, and
    // naming the entry after the interface sends a reader to the one class
    // they cannot put on a screen.
    for (final c in classes) {
      if (c.isPublic && _widgetBases.contains(c.superclass)) return c;
    }
    for (final c in classes) {
      if (c.isPublic) return c;
    }
    return null;
  }

  String get title {
    final p = primary;
    if (p != null) return p.name;
    if (functions.isNotEmpty) return functions.first.name;
    return _expectedName(key);
  }

  List<ClassDecl> get companions =>
      classes.where((c) => c.isPublic && c != primary).toList();
}

/// The superclasses that make a class something a caller can render.
const _widgetBases = {
  'StatelessWidget',
  'StatefulWidget',
  'InheritedWidget',
  'ImplicitlyAnimatedWidget',
};

/// `ds_bottom_sheet` → `dsbottomsheet`, so it matches `DSBottomSheet`
/// however the class capitalises its acronym.
String _expectedName(String key) => key.replaceAll('_', '').toLowerCase();

// ---------------------------------------------------------------------------
// Parsing. Regex over lines, brace-depth aware — the same approach `ui_lint`
// takes, and for the same reason: adding `package:analyzer` would put a
// dependency in the generated app for the sake of one script.
// ---------------------------------------------------------------------------

final _classRe = RegExp(
  r'^(?:abstract\s+|sealed\s+|final\s+|base\s+)*class\s+(\w+)(<[^>]*>)?\s*(.*)$',
);
final _enumRe = RegExp(r'^enum\s+(\w+)\s*\{?(.*)$');
final _extendsRe = RegExp(
  r'extends\s+([\w<>, ?]+?)(?:\s+(?:with|implements)\b|\s*\{|$)',
);
// A field declaration is a class member, so it sits at exactly two spaces and
// has no initialiser. Without both halves, `final rawOnPressed = isLoading ?
// null : onPressed;` inside a build method reads as a field named `onPressed`
// of type `rawOnPressed = isLoading ? null :`, and that is the type the
// reference then prints for the real constructor parameter.
final _fieldRe = RegExp(r'^  final\s+([^=;]+?)\s+(\w+)\s*;\s*$');
final _staticRe = RegExp(r'^\s{2,}static\s+([\w<>?,\s]+?)\s+(\w+)\s*\(');
final _topFnRe = RegExp(r'^(?:Future<[\w<>?,\s]*>|[\w<>?,]+)\s+(\w+)\s*[(<]');

final _tierRe = RegExp(r'^// ds-tier: \d+ — (\w+)$');

Component parseComponent(String path, String source) {
  final key = path.split('/').last.replaceAll('.dart', '');
  final lines = source.split('\n');
  final classes = <ClassDecl>[];
  final enums = <EnumDecl>[];
  final functions = <TopLevelFn>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty || line.startsWith(' ') || line.startsWith('//')) continue;

    final enumMatch = _enumRe.firstMatch(line);
    if (enumMatch != null) {
      final end = _blockEnd(lines, i);
      enums.add(
        EnumDecl(
          name: enumMatch.group(1)!,
          values: _enumValues(lines.sublist(i, end + 1)),
        ),
      );
      i = end;
      continue;
    }

    final classMatch = _classRe.firstMatch(line);
    if (classMatch != null) {
      final end = _blockEnd(lines, i);
      final name = classMatch.group(1)!;
      final ext = _extendsRe.firstMatch(classMatch.group(3) ?? '');
      classes.add(
        ClassDecl(
          name: name,
          generics: classMatch.group(2) ?? '',
          superclass: ext == null ? '' : ext.group(1)!.trim(),
          doc: _docAbove(lines, i),
          ctors: _ctorsIn(lines, i, end, name),
          statics: _staticsIn(lines, i, end),
        ),
      );
      i = end;
      continue;
    }

    // A top-level function — `showDSBottomSheet(...)` is the whole public API
    // of `ds_bottom_sheet.dart`, and a class-only parser would report the file
    // as empty.
    final fnMatch = _topFnRe.firstMatch(line);
    if (fnMatch != null && line.contains('(')) {
      final name = fnMatch.group(1)!;
      if (!name.startsWith('_')) {
        final open = line.indexOf('(');
        functions.add(
          TopLevelFn(
            name: name,
            returnType: line.substring(0, line.indexOf(name)).trim(),
            params: _paramsAt(lines, i, open),
            doc: _docAbove(lines, i),
          ),
        );
      }
      i = _blockEnd(lines, i);
      continue;
    }
  }

  return Component(
    key: key,
    path: path,
    tier: _tierRe.firstMatch(lines.first)?.group(1) ?? 'undeclared',
    classes: classes,
    enums: enums,
    functions: functions,
  );
}

/// Index of the line closing the block opened at or after [start].
int _blockEnd(List<String> lines, int start) {
  var depth = 0;
  var opened = false;
  for (var i = start; i < lines.length; i++) {
    for (final ch in lines[i].split('')) {
      if (ch == '{') {
        depth++;
        opened = true;
      } else if (ch == '}') {
        depth--;
        if (opened && depth == 0) return i;
      }
    }
    // A one-line declaration with no body at all: `class DSTabItem;`
    if (!opened && lines[i].trimRight().endsWith(';')) return i;
  }
  return lines.length - 1;
}

List<String> _docAbove(List<String> lines, int index) {
  final doc = <String>[];
  for (var i = index - 1; i >= 0; i--) {
    final line = lines[i].trimLeft();
    if (line.startsWith('///')) {
      doc.insert(0, line.substring(3).trim());
      continue;
    }
    break;
  }
  // Drop a trailing code sample; the reference is a map, not a tutorial.
  final fence = doc.indexWhere((l) => l.startsWith('```'));
  return fence == -1 ? doc : doc.sublist(0, fence);
}

List<String> _enumValues(List<String> block) {
  final body = block.join('\n');
  final open = body.indexOf('{');
  if (open == -1) return const [];
  final close = body.lastIndexOf('}');
  if (close <= open) return const [];
  var inner = body
      .substring(open + 1, close)
      .split('\n')
      .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
      .join(' ');

  // In an enhanced enum a semicolon ends the value list and the fields,
  // constructor and methods follow. Without this cut the last value arrives
  // glued to the constructor that follows it.
  final semi = inner.indexOf(';');
  if (semi != -1) inner = inner.substring(0, semi);

  return inner
      .split(',')
      // A value may carry constructor arguments — `info(0xFF)` — and the
      // identifier in front of them is the name.
      .map((v) => RegExp(r'^\s*(\w+)').firstMatch(v)?.group(1))
      .whereType<String>()
      .toList();
}

Map<String, String> _fieldTypes(List<String> lines, int start, int end) {
  final types = <String, String>{};
  for (var i = start; i <= end && i < lines.length; i++) {
    final m = _fieldRe.firstMatch(lines[i]);
    if (m != null) types[m.group(2)!] = m.group(1)!.trim();
  }
  return types;
}

List<Ctor> _ctorsIn(List<String> lines, int start, int end, String className) {
  final ctors = <Ctor>[];
  final fields = _fieldTypes(lines, start, end);
  final head = RegExp(
    '^\\s{2,}(const\\s+|factory\\s+)?$className(?:\\.(\\w+))?\\s*\\(',
  );

  for (var i = start + 1; i <= end && i < lines.length; i++) {
    final m = head.firstMatch(lines[i]);
    if (m == null) continue;
    final open = lines[i].indexOf('(', lines[i].indexOf(className));
    final name = m.group(2) ?? '';
    if (name.startsWith('_')) continue;
    ctors.add(
      Ctor(
        name: name,
        isConst: (m.group(1) ?? '').trim() == 'const',
        isFactory: (m.group(1) ?? '').trim() == 'factory',
        params: _paramsAt(lines, i, open, fields: fields),
      ),
    );
  }
  return ctors;
}

List<StaticMethod> _staticsIn(List<String> lines, int start, int end) {
  final out = <StaticMethod>[];
  for (var i = start + 1; i <= end && i < lines.length; i++) {
    final m = _staticRe.firstMatch(lines[i]);
    if (m == null) continue;
    final name = m.group(2)!;
    if (name.startsWith('_')) continue;
    out.add(
      StaticMethod(
        name: name,
        returnType: m.group(1)!.trim(),
        params: _paramsAt(lines, i, lines[i].indexOf('(', m.start)),
      ),
    );
  }
  return out;
}

/// Reads the parameter list that opens at [open] on line [line], following it
/// across as many lines as it takes to balance.
List<Param> _paramsAt(
  List<String> lines,
  int line,
  int open, {
  Map<String, String> fields = const {},
}) {
  if (open < 0) return const [];
  final buffer = StringBuffer();
  var depth = 0;
  var started = false;

  outer:
  for (var i = line; i < lines.length; i++) {
    final text = i == line ? lines[i].substring(open) : lines[i];
    for (final ch in text.split('')) {
      if (ch == '(') {
        depth++;
        if (!started) {
          started = true;
          continue;
        }
      } else if (ch == ')') {
        depth--;
        if (depth == 0) break outer;
      }
      if (started) buffer.write(ch);
    }
    buffer.write(' ');
  }

  return _parseParams(buffer.toString(), fields);
}

List<Param> _parseParams(String raw, Map<String, String> fields) {
  final cleaned = raw.replaceAll(RegExp(r'[{}\[\]]'), ' ');
  final parts = _splitTopLevel(cleaned);
  final params = <Param>[];

  for (final part in parts) {
    var text = part.trim();
    if (text.isEmpty) continue;

    final isRequired = text.startsWith('required ');
    if (isRequired) text = text.substring('required '.length).trim();

    String? defaultValue;
    final eq = _topLevelIndexOf(text, '=');
    if (eq != -1) {
      defaultValue = text.substring(eq + 1).trim();
      text = text.substring(0, eq).trim();
    }
    if (text.isEmpty) continue;

    final space = text.lastIndexOf(' ');
    var name = space == -1 ? text : text.substring(space + 1).trim();
    var type = space == -1
        ? ''
        : text.substring(0, space).replaceAll(RegExp(r'\s+'), ' ').trim();

    // `this.body`, `super.key`, and the narrowed form `required Widget
    // this.body` — which is legal Dart and leaves the `this.` on what the
    // split took for the parameter name.
    if (name.startsWith('this.')) {
      name = name.substring(5);
      if (type.isEmpty) type = fields[name] ?? '';
    } else if (name.startsWith('super.')) {
      name = name.substring(6);
      if (type.isEmpty && name == 'key') type = 'Key?';
    }
    if (name.isEmpty) continue;

    params.add(
      Param(
        name: name,
        type: type,
        isRequired: isRequired,
        defaultValue: defaultValue,
      ),
    );
  }
  return params;
}

/// Splits on commas that are not inside `<>`, `()` or a string.
List<String> _splitTopLevel(String text) {
  final out = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (final ch in text.split('')) {
    if (ch == '<' || ch == '(') depth++;
    if (ch == '>' || ch == ')') depth--;
    if (ch == ',' && depth <= 0) {
      out.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(ch);
  }
  out.add(buffer.toString());
  return out;
}

int _topLevelIndexOf(String text, String needle) {
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch == '<' || ch == '(') depth++;
    if (ch == '>' || ch == ')') depth--;
    // `=>` is a body, not a default.
    if (depth == 0 &&
        ch == needle &&
        (i + 1 >= text.length || text[i + 1] != '>')) {
      return i;
    }
  }
  return -1;
}

// ---------------------------------------------------------------------------
// The coverage gate.
// ---------------------------------------------------------------------------

/// Component keys that ship with no selection entry, and entries that name no
/// shipped component. Either one means the reference has drifted from the kit.
({List<String> missing, List<String> stale}) selectionGaps(List<String> keys) {
  final missing = keys.where((k) => !_selection.containsKey(k)).toList()
    ..sort();
  final stale = _selection.keys.where((k) => !keys.contains(k)).toList()
    ..sort();
  return (missing: missing, stale: stale);
}

// ---------------------------------------------------------------------------
// Rendering.
// ---------------------------------------------------------------------------

const _preamble = '''
# Design System Reference (LLM-friendly)

Every widget shipped in `lib/design_system/`, in one file. Read this before
composing a screen: `tool/ui_lint.dart` fails a screen that hand-rolls a
control the kit already owns, and this is where you find out what it owns.

## How to use this file

- **Start with `Use when:` / `Instead:`.** Picking the wrong control is the
  failure no gate catches — `ui_lint` checks that a widget came from the kit,
  never that it suited the job. `Instead:` names the neighbour that gets
  reached for by mistake and the question that separates the two.
- **Reach for a component by name; do not hand-roll it.** Everything here is
  exported from `lib/design_system/design_system.dart`, so one import gets you
  all of it.
- **Colour, radius, motion, depth and type are tokens**, from `lib/theme/`.
  A component takes its own defaults from them; passing a literal in is what
  `ui_lint` rules 11–18 fail.
- **`Enums`** are the variant sets. They are the only legal values for the
  matching parameter — there is no string-typed variant anywhere in the kit.
- **`Also in this file`** lists the companion classes exported alongside the
  main one: the item types, the controllers, the slot widgets.
- **`Tier`** is the layer the component sits on, and therefore what it may be
  built from. `foundation` declares nothing that paints — the style chain, the
  scopes, the press and inset plumbing. An `atom` is the smallest thing that
  paints and reaches no further than another atom. A `molecule` composes
  atoms into one unit of meaning; an `organism` composes molecules into a
  region of a screen; a `template` composes organisms and owns nothing but
  layout. An import may reach its own tier or below and no further, which
  `tool/ui_lint.dart` fails a build over.

Generated by `tool/design_system_reference.dart` — do not hand-edit. Run
`make design-system-reference-update` after adding a component. Selection
guidance is curated in that file, and a component with no entry fails
`make check`.
''';

String renderReference(List<Component> components) {
  final out = StringBuffer();
  out.writeln('<!-- design-system-reference:v1 — generated, do not hand-edit.');
  out.writeln('     Regenerate with: make design-system-reference-update -->');
  out.writeln();
  out.write(_preamble);
  out.writeln();
  out.writeln('> ${components.length} components · `lib/design_system/`');
  out.writeln();

  final order = [..._categories.keys, 'Other'];
  final byCategory = <String, List<Component>>{};
  for (final c in components) {
    byCategory.putIfAbsent(categoryOf(c.key), () => []).add(c);
  }

  for (final category in order) {
    final group = byCategory[category];
    if (group == null || group.isEmpty) continue;
    group.sort((a, b) => a.title.compareTo(b.title));
    out.writeln('## $category (${group.length})');
    out.writeln();
    for (final c in group) {
      out.write(_renderComponent(c));
    }
  }

  return out.toString();
}

String _renderComponent(Component c) {
  final out = StringBuffer();
  final pick = _selection[c.key];
  final primary = c.primary;

  out.writeln('### `${c.title}`');
  out.writeln();
  if (pick != null) {
    out.writeln('- **Use when:** ${pick.use}');
    out.writeln('- **Instead:** ${pick.instead}');
  }
  out.writeln('- **File:** `${c.path}`');
  out.writeln('- **Tier:** ${c.tier}');

  if (primary != null && primary.superclass.isNotEmpty) {
    out.writeln('- **Kind:** `${primary.superclass}`');
  }

  final doc =
      primary?.doc ??
      (c.functions.isEmpty ? const <String>[] : c.functions.first.doc);
  final summary = _summarise(doc);
  if (summary.isNotEmpty) out.writeln('- **Notes:** $summary');

  if (primary != null) {
    for (final ctor in primary.ctors) {
      out.writeln('- **Constructor:** `${ctor.signature(primary.name)}`');
      for (final p in ctor.params) {
        out.writeln('  - `${p.render()}`');
      }
    }
    for (final s in primary.statics) {
      final args = s.params.map((p) => p.render()).join(', ');
      out.writeln(
        '- **Static:** `${s.returnType} ${primary.name}.${s.name}($args)`',
      );
    }
  }

  for (final fn in c.functions) {
    out.writeln('- **Function:** `${fn.returnType} ${fn.name}(…)`');
    for (final p in fn.params) {
      out.writeln('  - `${p.render()}`');
    }
  }

  final publicEnums = c.enums.where((e) => e.isPublic).toList();
  for (final e in publicEnums) {
    out.writeln(
      '- **Enum `${e.name}`:** ${e.values.map((v) => '`$v`').join(', ')}',
    );
  }

  final companions = c.companions;
  if (companions.isNotEmpty) {
    final names = companions
        .map((k) {
          final kind = k.superclass.isEmpty ? '' : ' (`${k.superclass}`)';
          return '`${k.name}`$kind';
        })
        .join(', ');
    out.writeln('- **Also in this file:** $names');
  }

  out.writeln();
  return out.toString();
}

/// The first sentence or two of the doc comment, flattened. The reference is a
/// map — the full doc stays in the source, where it is next to the code.
String _summarise(List<String> doc) {
  // Stop at the first bullet rather than filtering bullets out: dropping the
  // list under "Features:" leaves the colon dangling on a sentence that now
  // introduces nothing.
  final end = doc.indexWhere((l) => l.startsWith('- ') || l.startsWith('•'));
  final prose = end == -1 ? doc : doc.sublist(0, end);
  final joined = prose.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (joined.isEmpty) return '';
  final parts = joined
      .split(RegExp(r'(?<=\.)\s+'))
      // "Features:" introduces the list that was just dropped.
      .where((s) => !s.trimRight().endsWith(':'))
      .toList();
  final take = parts.take(2).join(' ').trim();
  return take.length > 240 ? '${take.substring(0, 237)}…' : take;
}

// ---------------------------------------------------------------------------
// Entry point.
// ---------------------------------------------------------------------------

/// The kit's directory, resolved from the package root — which is the working
/// directory for both `dart run` and `flutter test`.
Directory componentDirectory() => Directory(sourceDir);

List<Component> readComponents(Directory dir) {
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => isComponentFile(f.path.split('/').last))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final parsed = files
      .map(
        (f) => parseComponent(
          f.path.replaceAll(RegExp(r'^\./'), ''),
          f.readAsStringSync(),
        ),
      )
      .toList();

  // A `ds_foo_style.dart` is not a component of its own — it is `DSFoo`'s
  // style class, living in a file because the tier check forbids the import
  // cycle it caused where it used to live. Folded back in, so the reference
  // reads the way the kit is used: one entry per component, its style knobs
  // under it.
  final byKey = {for (final c in parsed) c.key: c};
  final folded = <Component>[];
  for (final c in parsed) {
    if (c.key.endsWith('_style')) {
      final owner = byKey[c.key.substring(0, c.key.length - '_style'.length)];
      if (owner != null) {
        folded.add(
          Component(
            key: owner.key,
            path: owner.path,
            tier: owner.tier,
            classes: [...c.classes, ...owner.classes],
            enums: [...c.enums, ...owner.enums],
            functions: [...c.functions, ...owner.functions],
          ),
        );
        continue;
      }
    }
    if (byKey.containsKey('${c.key}_style')) continue;
    folded.add(c);
  }
  return folded;
}

void main(List<String> args) {
  final checkOnly = args.contains('--check');

  final dir = Directory(sourceDir);
  if (!dir.existsSync()) {
    stderr.writeln(
      'design-system-reference: no $sourceDir — run from the project root.',
    );
    exit(1);
  }

  final components = readComponents(dir);

  final gaps = selectionGaps(components.map((c) => c.key).toList());
  if (gaps.missing.isNotEmpty || gaps.stale.isNotEmpty) {
    if (gaps.missing.isNotEmpty) {
      stderr.writeln(
        '\ndesign-system-reference: ${gaps.missing.length} component(s) have no selection entry:',
      );
      for (final k in gaps.missing) {
        stderr.writeln('  - $k');
      }
      stderr.writeln(
        '\nAdd `use` + `instead` for each in _selection '
        '(tool/design_system_reference.dart).',
      );
      stderr.writeln(
        'A component nobody can find is a component that gets '
        'hand-rolled a second time — which is what ui_lint then fails.',
      );
    }
    if (gaps.stale.isNotEmpty) {
      stderr.writeln(
        '\ndesign-system-reference: ${gaps.stale.length} selection entr(y/ies) '
        'name no shipped component: ${gaps.stale.join(', ')}',
      );
    }
    exit(1);
  }

  final rendered = renderReference(components);
  final out = File(outFile);

  if (checkOnly) {
    final current = out.existsSync() ? out.readAsStringSync() : null;
    if (current == rendered) {
      stdout.writeln(
        'design-system-reference: ${components.length} component(s), reference is current',
      );
      exit(0);
    }
    stderr.writeln(
      current == null
          ? '\ndesign-system-reference: $outFile does not exist.'
          : '\ndesign-system-reference: $outFile is stale — the kit has changed since it was written.',
    );
    stderr.writeln(
      'Run `make design-system-reference-update` and commit the result.',
    );
    exit(1);
  }

  out.parent.createSync(recursive: true);
  out.writeAsStringSync(rendered);
  stdout.writeln(
    'design-system-reference: ${components.length} component(s) → $outFile',
  );
}
