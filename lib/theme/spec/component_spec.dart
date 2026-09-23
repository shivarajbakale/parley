import 'package:flutter/widgets.dart';
import 'package:parley_android/theme/spec/shape_spec.dart';

/// How a chip is drawn.
enum ChipStyle { filled, tonal, outlined }

/// Whether rows in a list are separated, and how far the separator is inset.
enum DividerPolicy {
  /// Nothing between rows. Space does the separating.
  none,

  /// A line that starts where the row's text starts, so the leading element
  /// reads as belonging to its row rather than to the list.
  inset,

  /// From where the row's content starts to where it ends: the gutter on
  /// both sides, never the screen edge.
  full,
}

/// What a list row's leading slot looks like.
enum LeadingStyle {
  /// A tinted well behind the glyph — the shape that makes a colour-per-item
  /// list read as a set.
  well,

  /// The glyph alone, on the row's own surface.
  bare,

  /// No leading slot at all.
  none,
}

/// The geometry and idiom decisions that are neither pure colour nor pure
/// spacing, gathered so an identity can state them in one place.
///
/// This is where "the same tokens, a different app" is actually decided: two
/// identities can share a palette and a scale and still look nothing alike if
/// one puts every row behind a tinted well with no dividers and the other uses
/// bare glyphs and full-bleed rules.
@immutable
class ComponentSpec {
  /// The button ramp — small, medium, large — and the height of a text field.
  ///
  /// Distinct from the tap target, and deliberately so: a control may be
  /// visually shorter than 44/48 so long as its gesture area is not, because
  /// [DSTapTarget] centres the painted pill in a box the full [minTapTarget]
  /// and forwards a hit in the margin to it.
  ///
  /// [buttonHeight] used to be 48 — the tap floor, to the point. A pill sized
  /// by an accessibility minimum is a pill nobody chose, and it showed: every
  /// button in the app painted 48 around a 19-point label, which is sixty per
  /// cent air. 44 is a number with a reason behind it (Apple's floor, drawn
  /// rather than inherited) and the target is still 48.
  ///
  /// Three named steps rather than one token and two sums. The ramp used to
  /// be `buttonHeight - space.md` and `buttonHeight + space.sm`, so lowering
  /// the middle step silently dragged the small one under any size worth
  /// painting — a change to one button size was a change to three.
  final double buttonHeightSm;
  final double buttonHeight;
  final double buttonHeightLg;
  final double fieldHeight;

  /// The smallest a tap target may be, and the kit's only answer to that
  /// question.
  ///
  /// 48 clears both vendor floors — Apple asks 44, Android asks 48 — and it is
  /// deliberately one number rather than two. A minimum is a floor, not a
  /// target: a control 4pt larger than Apple's minimum is not a defect, while
  /// two disagreeing floors in one kit is exactly the defect this replaced. It
  /// used to disagree with `AppPlatform.minTapTarget`, which returned 44 on
  /// Apple and was read by two components while fifteen read this one, so the
  /// most safety-critical dimension in a touch interface had two answers
  /// depending on which file you were in.
  final double minTapTarget;

  final double listRowMinHeight;
  final DividerPolicy dividerPolicy;
  final LeadingStyle leadingStyle;

  /// Size of the leading well, and the shape role it takes.
  final double wellSize;

  /// A list row's leading well as a share of the row's minimum height, and
  /// its glyph as a share of the well. Ratios, not points, so the well keeps
  /// its proportion in the row when an identity changes the row height.
  final double rowWellRatio;
  final double rowWellGlyphRatio;
  final AppShape wellShape;

  /// The glyph ladder, five steps, smallest first.
  ///
  /// Five named steps rather than the thirteen literals they replace. The lint
  /// reads colour, radius, duration and shadow and had nothing to say about
  /// size, so every hand-typed dimension in the kit passed the gate — 13
  /// distinct icon sizes against a token layer that offered two. The steps are
  /// roles, not measurements: pick the one whose sentence describes where the
  /// glyph sits, and the identity decides what that is worth in points.
  ///
  /// - [iconSizeMicro] — inside a badge, or a chip's affordance.
  /// - [iconSizeSmall] — inside a tab, a segment, or beside a dense label.
  /// - [iconSizeInline] — beside a label in a row, a menu, a field, a snack
  ///   bar. The most common glyph in the kit and the one that had no name.
  /// - [iconSize] — the default, and what an [IconTheme] hands anything that
  ///   does not ask.
  /// - [iconSizeLarge] — a section's or a sidebar's leading glyph.
  final double iconSizeMicro;
  final double iconSizeSmall;
  final double iconSizeInline;
  final double iconSize;
  final double iconSizeLarge;

  /// The editorial glyph size, which is not on the control ladder.
  ///
  /// A glyph this size is artwork rather than an affordance — it heads a
  /// splash, a paywall or an empty state — and scaling it with the control
  /// ladder would make every icon in the app move when a card's chevron
  /// changed.
  ///
  /// There used to be a second, larger step, `glyphIllustration`. Its only
  /// consumer was the icon that headed each slide of the old onboarding
  /// carousel; `DSTour` draws real illustrations instead, and a knob nothing
  /// turns is a promise the app does not keep.
  final double glyphHero;

  /// The sheet grabber: the pill at the top edge of a bottom sheet.
  ///
  /// Named because three sheets drew it at two different widths — 40 in one,
  /// 32 in the other two — and a user who opens both in one session watches
  /// the app change its mind about its own affordance.
  final double grabberWidth;
  final double grabberHeight;

  /// The circular well a dialog or a modal puts its glyph in.
  final double iconWellSize;

  /// The width of a toolbar's or a row's leading column, and the side of the
  /// square tile an app icon sits in. One value: they are the same column.
  final double leadingSlotSize;

  /// The widest a chip's label may get before it ellipsizes.
  ///
  /// A chip is a summary, and one that grows to fit its text stops being a
  /// chip and becomes a paragraph with a border.
  final double chipMaxWidth;

  /// How much of the screen an overlay surface — a dialog, a centred modal —
  /// takes across.
  ///
  /// A dialog that hugs its own text measures a different width for every
  /// message it carries, so two confirmations in one session look like two
  /// different components. One fraction of the screen instead: the surface is
  /// the same shape whatever it says.
  ///
  /// It is deliberately generous, and narrowing it is not free: at 0.78 a
  /// 390-point phone gives a 304-point dialog, and "Cancel" beside a verb
  /// no longer fits on one line, so every two-action confirm silently
  /// becomes a stack. [dialogMinWidth] is the floor that says so.
  final double overlayWidthFactor;

  /// The ceiling [overlayWidthFactor] is clamped to.
  ///
  /// On a tablet 90% of the screen is a banner, not a decision.
  final double overlayMaxWidth;

  /// The floor a dialog's surface is held to, so a one-word confirmation is
  /// still the shape of a dialog rather than the shape of its longest line.
  final double dialogMinWidth;

  /// The shortest a bottom sheet may be. Below this a sheet reads as a
  /// mis-drawn bar rather than as a surface.
  final double sheetMinHeight;

  /// An anchored menu's width band. Narrower than a popover on purpose: a
  /// menu is a list of verbs, and a verb that needs 320 points is a sentence.
  final double menuMinWidth;
  final double menuMaxWidth;

  /// The controls that carry a selection, at their drawn size.
  ///
  /// The visual size and the tap target are two numbers on purpose: a 48-point
  /// checkbox is a grey slab, and an 18-point tap target is a miss. Every
  /// control in this group draws at its own size inside a
  /// [minTapTarget]-square gesture area.
  final double checkboxSize;

  /// The shape role a checkbox takes, replacing the `isCircular` boolean each
  /// call site used to pass.
  ///
  /// A house style that ticks circles rather than boxes says so once, here,
  /// the same way [chipStyle] and [wellShape] are decided once — rather than
  /// at every one of the forty call sites that would otherwise each have to
  /// remember.
  final AppShape checkboxShape;

  /// The radio's circle. The same nominal size as the checkbox: at 20 it read
  /// oversized in a list row, and the tap target, not the glyph, carries reach.
  final double radioSize;

  /// The stroke a checkbox, a radio and an unselected control draw with.
  final double controlStroke;

  /// The switch: its track and the thumb that travels along it, plus the size
  /// the thumb grows to while a finger is on it.
  ///
  /// Both platforms grow the thumb under the finger; neither the Material nor
  /// the Cupertino switch this replaced did it here.
  final double switchTrackWidth;
  final double switchTrackHeight;
  final double switchThumbSize;
  final double switchPressedThumbSize;

  /// The switch a list row carries. A full 52-point track docked at a row's
  /// trailing edge outweighs the label it belongs to; the row, not the
  /// control, is the tap target there. Standalone switches keep the full size.
  final double switchCompactTrackWidth;
  final double switchCompactTrackHeight;
  final double switchCompactThumbSize;
  final double switchCompactPressedThumbSize;

  /// The slider: the bar, the thumb, the pressed thumb, and a tick on a
  /// discrete track.
  final double sliderTrackHeight;
  final double sliderThumbSize;
  final double sliderPressedThumbSize;
  final double sliderTickSize;

  /// A flat control's own height — a segmented button, a pill tab bar — and
  /// the two steps either side of it.
  ///
  /// Distinct from [buttonHeight]: a button is a target, and a segmented
  /// control is a track with targets inside it, so the track is shorter than
  /// the 48 its segments still have to clear.
  final double controlHeight;
  final double controlHeightSm;
  final double controlHeightLg;

  /// How far the moving indicator is inset from the track it runs in. Small
  /// on purpose: a wide inset makes the indicator read as a separate object
  /// sitting on the track rather than as the track's own selected slot.
  final double trackInset;

  /// The navigation strip: its row height, the underline it draws, the
  /// narrowest a tab may be, and the fade over an overflowing edge.
  final double tabHeight;
  final double tabIndicatorHeight;
  final double minTabWidth;
  final double edgeFadeWidth;

  /// The large-title header: how tall it is when open, and where its title
  /// sits once it has closed.
  ///
  /// Both were `static const` on the widget, with their reasoning in comments
  /// that moves with them. 96 rather than Material's 152, which leaves a lot
  /// of empty space above the title — and down from 108, which was sized for
  /// a large title set at 1.5x `titleLarge` on a 1.13 scale. Both of those
  /// numbers came down, so the floor under them had to as well, or the bar
  /// would have kept the height and just held more air. It is only a floor:
  /// `DSLargeAppBar` measures the title block and takes the larger of the two.
  /// 72 is Material's own default and the
  /// width a leading button occupies: the expanded title wants the page gutter
  /// so it lines up with the content under it, and the collapsed one cannot
  /// have that, because at the gutter it is drawn straight through the back
  /// button — so the padding travels with the collapse rather than picking one
  /// of the two and being wrong half the time.
  final double headerExpandedHeight;
  final double headerCollapsedTitleStart;

  /// The compact header's height, per platform.
  ///
  /// Two fields rather than one, because this is a real platform divergence
  /// and not a default with an override: 44 is the iOS navigation bar and 56
  /// is Material's toolbar, and a bar that took one number would be wrong on
  /// one of the two platforms every time. The branch lives here rather than in
  /// the widget so a `DSCompactAppBar` never reads `AppPlatform` for a number.
  final double headerCompactHeight;
  final double headerCompactHeightApple;

  /// The two steps either side of [wellSize], so a well behind a glyph has
  /// the same three sizes every other control does.
  final double wellSizeSm;
  final double wellSizeLg;

  /// The three boxes a drawn illustration occupies, and the stroke it is
  /// drawn with at [illustrationSize].
  ///
  /// A drawing is not on the glyph ladder: it is a composed scene rather than
  /// a single mark, so scaling it with an icon would either leave the scene
  /// unreadable at 28 or make every chevron in the app move when a first-run
  /// screen changed. The stroke is stated at the medium box and scaled
  /// linearly with whichever box is drawn, so a small illustration is a
  /// smaller drawing rather than the same drawing with heavier lines.
  final double illustrationSizeSm;
  final double illustrationSize;
  final double illustrationSizeLg;
  final double illustrationStroke;

  /// The four avatar sizes, the ring an overlapping stack draws, and the
  /// status pill's height.
  ///
  /// The ring is what makes a stack of overlapping faces read as separate
  /// people rather than as a smear, and it has to be painted in the colour
  /// *behind the group* — which is why the group passes it down rather than
  /// each avatar guessing.
  final double avatarSizeSm;
  final double avatarSizeMd;
  final double avatarSizeLg;
  final double avatarSizeXl;
  final double avatarRing;
  final double badgeHeight;

  /// The notification dot: bare, and the pill it becomes when it carries a
  /// count. It never widens past [dotMaxWidth] — "99+" is the last thing it
  /// can say.
  final double dotSize;
  final double dotCountHeight;
  final double dotMaxWidth;

  /// How wide a snack bar is allowed to get. A message that spans a tablet is
  /// a message whose start and end are two eye movements apart.
  final double snackMaxWidth;

  /// How long a snack bar stays. The second value is for a bar carrying an
  /// action, because a message the user has to reach for needs longer than one
  /// they only read.
  final Duration snackDuration;
  final Duration snackActionDuration;

  /// The one floating action button size, and the height of the extended
  /// form — which is the same box with a label beside the glyph, not a
  /// second size.
  ///
  /// A FAB that comes in sm/md/lg invites two of them side by side arguing
  /// about which one is primary; the kit ships one size so that question
  /// never comes up. 40 reads as secondary next to the 48-point buttons and
  /// list rows around it, which is deliberate — the floating button is an
  /// escape hatch, not the loudest thing on the screen.
  final double fabSize;

  /// How wide the sidebar is. Wider than a phone's drawer because a sidebar
  /// shows a label beside every glyph and a truncated destination is a
  /// destination nobody picks.
  final double sidebarWidth;

  /// How far a row has to travel before a swipe commits, as a fraction of its
  /// own width.
  final double swipeThreshold;

  /// The linear progress bar's height, and the circular one's stroke.
  final double progressHeight;
  final double progressStroke;

  /// The hero plate — [DSHero]. A floor, not a height: the plate grows with
  /// its title, and this is what stops it collapsing to the height of two
  /// words on a screen where it is the first thing anyone sees.
  final double heroMinHeight;

  /// The side of the brand mark's tile on that plate.
  final double heroMarkSize;

  /// The concentric arcs painted into the plate, and the hairline that closes
  /// the sheet's top edge over it.
  final double heroPlateStroke;

  /// The plot heights of a chart, and the strip height of a sparkline.
  ///
  /// A chart is one of the few components whose height cannot come from its
  /// content: a line through seven points is as tall as it is told to be, and
  /// left to the call site it is told something different on every screen.
  /// [sparklineHeight] is deliberately near a line of body text — a sparkline
  /// sits beside a figure and must not out-weigh it.
  final double chartHeight;
  final double chartHeightSm;

  final double sparklineHeight;

  /// The stroke of a plotted line, the radius of the dot on the point being
  /// read, and the width of one bar.
  final double chartLineWidth;
  final double chartDotRadius;
  final double chartBarWidth;

  /// The room an axis keeps for its labels: a width down the leading edge for
  /// the value axis, a height along the bottom for the category axis.
  ///
  /// These are reserved rather than measured, which is what makes the plot
  /// rectangle predictable — and a predictable plot rectangle is what lets the
  /// scrub gesture map a finger position to a point index without asking the
  /// chart library where it drew anything.
  final double chartValueAxisWidth;
  final double chartCategoryAxisHeight;

  /// The vertical rule that follows the finger during a scrub.
  final double chartScrubLineWidth;

  /// Stroke width for outline icons and hairline borders.
  final double hairlineWidth;

  /// The resting outline of a field — a text field, a select, a search bar.
  ///
  /// Its own token rather than [hairlineWidth], which twenty-five components
  /// share: a card, a chip, a button outline and a chart axis are all drawn
  /// at that width, and thinning a field's border by moving it would have
  /// thinned every edge in the app.
  ///
  /// 0.5, which is a true hairline: on a 2x or 3x screen it is exactly one
  /// device pixel, the thinnest line the display can draw. On a 1x screen
  /// there is no half pixel, so it antialiases — the line reads *lighter*
  /// rather than thinner, which is the trade every hairline makes and the
  /// reason this is a token an identity can put back to 1.
  ///
  /// The focused outline is not this. A field that has the caret says so by
  /// getting heavier, and that contrast is the affordance — see
  /// `DSTextFieldStyle.focusedWidth`.
  final double fieldOutlineWidth;

  /// The edge of a selectable surface — a card, a chip — at rest and selected.
  ///
  /// Their own tokens for the reason [fieldOutlineWidth] is: a card, a chip, a
  /// button outline and a chart axis all drew at [hairlineWidth], so thinning
  /// a card's edge by moving that would have thinned every edge in the app,
  /// a chart's axis and a switch's track included.
  ///
  /// 0.5 is a true hairline — one device pixel at 2x and 3x. At 1 the edge
  /// read as a frame drawn around the content rather than as the place the
  /// surface stops, which is all an edge on an elevated card has to say: the
  /// shadow already says it is above.
  ///
  /// Selected is 1, where the two components that draw it had each written
  /// their own 1.5 — one as `hairlineWidth * 1.5` inside a `copyWith`, the
  /// other as `hairlineWidth + 0.5`. It is *twice* the resting edge now rather
  /// than one and a half times, so the state reads more strongly than it did
  /// while both lines get thinner.
  final double surfaceOutlineWidth;
  final double selectedOutlineWidth;

  /// The focus ring: how thick it is, and how far outside the control it sits.
  ///
  /// The ring is drawn *outside* the control's own bounds rather than on them,
  /// which is the only placement that works on every variant — a ring painted
  /// on the edge of a filled button is accent on accent and disappears. The gap
  /// is what makes the ring read as a ring rather than as a thicker border, and
  /// it is why 2 and 2 rather than one 4.
  ///
  /// WCAG 2.2 SC 2.4.13 asks for an indicator at least 2px thick along the
  /// longest side; 2 is the floor, not a default to trim.
  final double focusRingWidth;
  final double focusRingGap;

  final ChipStyle chipStyle;

  /// Whether a chip may carry an icon beside its label. Off by default: at
  /// chip size an icon rarely says anything the label does not, and it costs
  /// enough width to push the last chip off the screen.
  final bool chipIcons;

  /// Whether a row that pushes a route shows a trailing chevron. The
  /// alternative — an overflow menu on every row — makes the most repeated
  /// element of a list its least important one.
  final bool rowChevron;

  const ComponentSpec({
    this.buttonHeightSm = 36,
    this.buttonHeight = 44,
    this.buttonHeightLg = 52,
    this.fieldHeight = 48,
    this.minTapTarget = 48,
    this.listRowMinHeight = 56,
    // Material 3 full-width rules, on both platforms. An inset rule reads as
    // unfinished inside a card: one end meets the border and the other stops
    // short of it.
    this.dividerPolicy = DividerPolicy.full,
    this.leadingStyle = LeadingStyle.well,
    this.wellSize = 40,
    // 60% of the row, so the gap above and below the well stays in proportion
    // to the row; the glyph fills 55% of the well.
    this.rowWellRatio = 0.6,
    this.rowWellGlyphRatio = 0.55,
    this.wellShape = AppShape.control,
    this.iconSizeMicro = 16,
    this.iconSizeSmall = 18,
    this.iconSizeInline = 20,
    this.iconSize = 24,
    this.iconSizeLarge = 28,
    this.glyphHero = 48,
    this.grabberWidth = 40,
    this.grabberHeight = 4,
    this.iconWellSize = 48,
    this.leadingSlotSize = 56,
    this.chipMaxWidth = 200,
    this.overlayWidthFactor = 0.9,
    this.overlayMaxWidth = 560,
    this.dialogMinWidth = 280,
    this.sheetMinHeight = 160,
    this.menuMinWidth = 200,
    this.menuMaxWidth = 320,
    this.wellSizeSm = 32,
    this.wellSizeLg = 56,
    this.illustrationSizeSm = 96,
    this.illustrationSize = 144,
    this.illustrationSizeLg = 200,
    this.illustrationStroke = 2,
    this.avatarSizeSm = 24,
    this.avatarSizeMd = 32,
    this.avatarSizeLg = 40,
    this.avatarSizeXl = 64,
    this.avatarRing = 2,
    this.badgeHeight = 20,
    this.dotSize = 8,
    this.dotCountHeight = 16,
    this.dotMaxWidth = 28,
    this.headerExpandedHeight = 96,
    this.headerCollapsedTitleStart = 72,
    this.headerCompactHeight = 56,
    this.headerCompactHeightApple = 44,
    this.controlHeight = 36,
    this.controlHeightSm = 32,
    this.controlHeightLg = 44,
    this.trackInset = 3,
    this.tabHeight = 48,
    this.tabIndicatorHeight = 3,
    this.minTabWidth = 72,
    this.edgeFadeWidth = 24,
    this.checkboxSize = 18,
    this.checkboxShape = AppShape.control,
    this.radioSize = 18,
    this.controlStroke = 2,
    this.switchTrackWidth = 52,
    this.switchTrackHeight = 32,
    this.switchThumbSize = 24,
    this.switchPressedThumbSize = 28,
    this.switchCompactTrackWidth = 40,
    this.switchCompactTrackHeight = 24,
    this.switchCompactThumbSize = 18,
    this.switchCompactPressedThumbSize = 21,
    this.sliderTrackHeight = 4,
    this.sliderThumbSize = 20,
    this.sliderPressedThumbSize = 28,
    this.sliderTickSize = 4,
    this.snackMaxWidth = 560,
    this.snackDuration = const Duration(seconds: 4),
    this.snackActionDuration = const Duration(seconds: 6),
    this.fabSize = 40,
    this.sidebarWidth = 280,
    this.swipeThreshold = 0.4,
    this.progressHeight = 6,
    this.progressStroke = 3,
    this.heroMinHeight = 200,
    this.heroMarkSize = 56,
    this.heroPlateStroke = 1.5,
    this.chartHeight = 180,
    this.chartHeightSm = 120,
    this.sparklineHeight = 40,
    this.chartLineWidth = 2.5,
    this.chartDotRadius = 3.5,
    this.chartBarWidth = 12,
    this.chartValueAxisWidth = 36,
    this.chartCategoryAxisHeight = 24,
    this.chartScrubLineWidth = 1.5,
    this.hairlineWidth = 1,
    this.fieldOutlineWidth = 0.5,
    this.surfaceOutlineWidth = 0.5,
    this.selectedOutlineWidth = 1,
    this.focusRingWidth = 2,
    this.focusRingGap = 2,
    this.chipStyle = ChipStyle.tonal,
    this.chipIcons = false,
    this.rowChevron = true,
  });

  ComponentSpec copyWith({
    double? buttonHeightSm,
    double? buttonHeight,
    double? buttonHeightLg,
    double? fieldHeight,
    double? minTapTarget,
    double? listRowMinHeight,
    DividerPolicy? dividerPolicy,
    LeadingStyle? leadingStyle,
    double? wellSize,
    double? rowWellRatio,
    double? rowWellGlyphRatio,
    AppShape? wellShape,
    double? iconSizeMicro,
    double? iconSizeSmall,
    double? iconSizeInline,
    double? iconSize,
    double? iconSizeLarge,
    double? glyphHero,
    double? grabberWidth,
    double? grabberHeight,
    double? iconWellSize,
    double? leadingSlotSize,
    double? chipMaxWidth,
    double? overlayWidthFactor,
    double? overlayMaxWidth,
    double? dialogMinWidth,
    double? sheetMinHeight,
    double? menuMinWidth,
    double? menuMaxWidth,
    double? wellSizeSm,
    double? wellSizeLg,
    double? illustrationSizeSm,
    double? illustrationSize,
    double? illustrationSizeLg,
    double? illustrationStroke,
    double? avatarSizeSm,
    double? avatarSizeMd,
    double? avatarSizeLg,
    double? avatarSizeXl,
    double? avatarRing,
    double? badgeHeight,
    double? dotSize,
    double? dotCountHeight,
    double? dotMaxWidth,
    double? headerExpandedHeight,
    double? headerCollapsedTitleStart,
    double? headerCompactHeight,
    double? headerCompactHeightApple,
    double? controlHeight,
    double? controlHeightSm,
    double? controlHeightLg,
    double? trackInset,
    double? tabHeight,
    double? tabIndicatorHeight,
    double? minTabWidth,
    double? edgeFadeWidth,
    double? checkboxSize,
    AppShape? checkboxShape,
    double? radioSize,
    double? controlStroke,
    double? switchTrackWidth,
    double? switchTrackHeight,
    double? switchThumbSize,
    double? switchPressedThumbSize,
    double? switchCompactTrackWidth,
    double? switchCompactTrackHeight,
    double? switchCompactThumbSize,
    double? switchCompactPressedThumbSize,
    double? sliderTrackHeight,
    double? sliderThumbSize,
    double? sliderPressedThumbSize,
    double? sliderTickSize,
    double? snackMaxWidth,
    Duration? snackDuration,
    Duration? snackActionDuration,
    double? fabSize,
    double? sidebarWidth,
    double? swipeThreshold,
    double? progressHeight,
    double? progressStroke,
    double? heroMinHeight,
    double? heroMarkSize,
    double? heroPlateStroke,
    double? chartHeight,
    double? chartHeightSm,
    double? sparklineHeight,
    double? chartLineWidth,
    double? chartDotRadius,
    double? chartBarWidth,
    double? chartValueAxisWidth,
    double? chartCategoryAxisHeight,
    double? chartScrubLineWidth,
    double? hairlineWidth,
    double? fieldOutlineWidth,
    double? surfaceOutlineWidth,
    double? selectedOutlineWidth,
    double? focusRingWidth,
    double? focusRingGap,
    ChipStyle? chipStyle,
    bool? chipIcons,
    bool? rowChevron,
  }) => ComponentSpec(
    buttonHeightSm: buttonHeightSm ?? this.buttonHeightSm,
    buttonHeight: buttonHeight ?? this.buttonHeight,
    buttonHeightLg: buttonHeightLg ?? this.buttonHeightLg,
    fieldHeight: fieldHeight ?? this.fieldHeight,
    minTapTarget: minTapTarget ?? this.minTapTarget,
    listRowMinHeight: listRowMinHeight ?? this.listRowMinHeight,
    dividerPolicy: dividerPolicy ?? this.dividerPolicy,
    leadingStyle: leadingStyle ?? this.leadingStyle,
    wellSize: wellSize ?? this.wellSize,
    rowWellRatio: rowWellRatio ?? this.rowWellRatio,
    rowWellGlyphRatio: rowWellGlyphRatio ?? this.rowWellGlyphRatio,
    wellShape: wellShape ?? this.wellShape,
    iconSizeMicro: iconSizeMicro ?? this.iconSizeMicro,
    iconSizeSmall: iconSizeSmall ?? this.iconSizeSmall,
    iconSizeInline: iconSizeInline ?? this.iconSizeInline,
    iconSize: iconSize ?? this.iconSize,
    iconSizeLarge: iconSizeLarge ?? this.iconSizeLarge,
    glyphHero: glyphHero ?? this.glyphHero,
    grabberWidth: grabberWidth ?? this.grabberWidth,
    grabberHeight: grabberHeight ?? this.grabberHeight,
    iconWellSize: iconWellSize ?? this.iconWellSize,
    leadingSlotSize: leadingSlotSize ?? this.leadingSlotSize,
    chipMaxWidth: chipMaxWidth ?? this.chipMaxWidth,
    overlayWidthFactor: overlayWidthFactor ?? this.overlayWidthFactor,
    overlayMaxWidth: overlayMaxWidth ?? this.overlayMaxWidth,
    dialogMinWidth: dialogMinWidth ?? this.dialogMinWidth,
    sheetMinHeight: sheetMinHeight ?? this.sheetMinHeight,
    menuMinWidth: menuMinWidth ?? this.menuMinWidth,
    menuMaxWidth: menuMaxWidth ?? this.menuMaxWidth,
    wellSizeSm: wellSizeSm ?? this.wellSizeSm,
    wellSizeLg: wellSizeLg ?? this.wellSizeLg,
    illustrationSizeSm: illustrationSizeSm ?? this.illustrationSizeSm,
    illustrationSize: illustrationSize ?? this.illustrationSize,
    illustrationSizeLg: illustrationSizeLg ?? this.illustrationSizeLg,
    illustrationStroke: illustrationStroke ?? this.illustrationStroke,
    avatarSizeSm: avatarSizeSm ?? this.avatarSizeSm,
    avatarSizeMd: avatarSizeMd ?? this.avatarSizeMd,
    avatarSizeLg: avatarSizeLg ?? this.avatarSizeLg,
    avatarSizeXl: avatarSizeXl ?? this.avatarSizeXl,
    avatarRing: avatarRing ?? this.avatarRing,
    badgeHeight: badgeHeight ?? this.badgeHeight,
    dotSize: dotSize ?? this.dotSize,
    dotCountHeight: dotCountHeight ?? this.dotCountHeight,
    dotMaxWidth: dotMaxWidth ?? this.dotMaxWidth,
    headerExpandedHeight: headerExpandedHeight ?? this.headerExpandedHeight,
    headerCollapsedTitleStart:
        headerCollapsedTitleStart ?? this.headerCollapsedTitleStart,
    headerCompactHeight: headerCompactHeight ?? this.headerCompactHeight,
    headerCompactHeightApple:
        headerCompactHeightApple ?? this.headerCompactHeightApple,
    controlHeight: controlHeight ?? this.controlHeight,
    controlHeightSm: controlHeightSm ?? this.controlHeightSm,
    controlHeightLg: controlHeightLg ?? this.controlHeightLg,
    trackInset: trackInset ?? this.trackInset,
    tabHeight: tabHeight ?? this.tabHeight,
    tabIndicatorHeight: tabIndicatorHeight ?? this.tabIndicatorHeight,
    minTabWidth: minTabWidth ?? this.minTabWidth,
    edgeFadeWidth: edgeFadeWidth ?? this.edgeFadeWidth,
    checkboxSize: checkboxSize ?? this.checkboxSize,
    checkboxShape: checkboxShape ?? this.checkboxShape,
    radioSize: radioSize ?? this.radioSize,
    controlStroke: controlStroke ?? this.controlStroke,
    switchTrackWidth: switchTrackWidth ?? this.switchTrackWidth,
    switchTrackHeight: switchTrackHeight ?? this.switchTrackHeight,
    switchThumbSize: switchThumbSize ?? this.switchThumbSize,
    switchPressedThumbSize:
        switchPressedThumbSize ?? this.switchPressedThumbSize,
    switchCompactTrackWidth:
        switchCompactTrackWidth ?? this.switchCompactTrackWidth,
    switchCompactTrackHeight:
        switchCompactTrackHeight ?? this.switchCompactTrackHeight,
    switchCompactThumbSize:
        switchCompactThumbSize ?? this.switchCompactThumbSize,
    switchCompactPressedThumbSize:
        switchCompactPressedThumbSize ?? this.switchCompactPressedThumbSize,
    sliderTrackHeight: sliderTrackHeight ?? this.sliderTrackHeight,
    sliderThumbSize: sliderThumbSize ?? this.sliderThumbSize,
    sliderPressedThumbSize:
        sliderPressedThumbSize ?? this.sliderPressedThumbSize,
    sliderTickSize: sliderTickSize ?? this.sliderTickSize,
    snackMaxWidth: snackMaxWidth ?? this.snackMaxWidth,
    snackDuration: snackDuration ?? this.snackDuration,
    snackActionDuration: snackActionDuration ?? this.snackActionDuration,
    fabSize: fabSize ?? this.fabSize,
    sidebarWidth: sidebarWidth ?? this.sidebarWidth,
    swipeThreshold: swipeThreshold ?? this.swipeThreshold,
    progressHeight: progressHeight ?? this.progressHeight,
    progressStroke: progressStroke ?? this.progressStroke,
    heroMinHeight: heroMinHeight ?? this.heroMinHeight,
    heroMarkSize: heroMarkSize ?? this.heroMarkSize,
    heroPlateStroke: heroPlateStroke ?? this.heroPlateStroke,
    chartHeight: chartHeight ?? this.chartHeight,
    chartHeightSm: chartHeightSm ?? this.chartHeightSm,
    sparklineHeight: sparklineHeight ?? this.sparklineHeight,
    chartLineWidth: chartLineWidth ?? this.chartLineWidth,
    chartDotRadius: chartDotRadius ?? this.chartDotRadius,
    chartBarWidth: chartBarWidth ?? this.chartBarWidth,
    chartValueAxisWidth: chartValueAxisWidth ?? this.chartValueAxisWidth,
    chartCategoryAxisHeight:
        chartCategoryAxisHeight ?? this.chartCategoryAxisHeight,
    chartScrubLineWidth: chartScrubLineWidth ?? this.chartScrubLineWidth,
    hairlineWidth: hairlineWidth ?? this.hairlineWidth,
    fieldOutlineWidth: fieldOutlineWidth ?? this.fieldOutlineWidth,
    surfaceOutlineWidth: surfaceOutlineWidth ?? this.surfaceOutlineWidth,
    selectedOutlineWidth: selectedOutlineWidth ?? this.selectedOutlineWidth,
    focusRingWidth: focusRingWidth ?? this.focusRingWidth,
    focusRingGap: focusRingGap ?? this.focusRingGap,
    chipStyle: chipStyle ?? this.chipStyle,
    chipIcons: chipIcons ?? this.chipIcons,
    rowChevron: rowChevron ?? this.rowChevron,
  );
}
