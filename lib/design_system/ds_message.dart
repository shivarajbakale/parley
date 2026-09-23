// ds-tier: 2 — molecule

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:flutter/semantics.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_progress_indicator.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The tone of a message, which is [DSScope]'s own vocabulary.
///
/// Deliberately not a sixth enum spelling the same five words. `DSBanner` and
/// `DSInfoCard` each declared their own `{ info, success, warning, error }`,
/// which is half of why they were two components; declaring a third here
/// would have repeated the mistake inside the fix.
typedef DSMessageTone = DSTone;

/// Where the message sits, which decides its bleed, its inset and its radius
/// — not what it means.
enum DSMessageScope {
  /// Full bleed, under the app bar, square at the screen edges.
  screen,

  /// Inset, inside a card or a section.
  section,

  /// One line. No title, no action, no dismiss — a one-line message that also
  /// has three affordances is not compact, it is a section message with its
  /// title deleted.
  compact,
}

/// [DSMessage]'s appearance, as data.
@immutable
class DSMessageStyle extends DSComponentStyle<DSMessageStyle> {
  const DSMessageStyle({
    this.padding,
    this.radius,
    this.ruleWidth,
    this.showRule,
    this.borderColor,
    this.borderWidth,
    this.iconSize,
    this.iconGap,
    this.titleStyle,
    this.messageStyle,
    this.fillColor,
    this.accentColor,
    this.foregroundColor,
    this.icons,
  });

  final EdgeInsetsGeometry? padding;
  final BorderRadius? radius;

  /// The leading rule — the classic banner bar down the leading edge.
  final double? ruleWidth;

  /// Whether that bar is drawn. Off by default since the message grew a
  /// border: a 3pt slab down one side of a 14pt radius reads as a comma
  /// stuck to the box, and the hairline that now runs all the way round
  /// carries the tone at the edge more evenly. On for a caller who wants the
  /// louder banner.
  ///
  /// The icon is not optional either way: it is the SC 1.4.1 channel, and
  /// `tool/ui_lint.dart` asserts the [icons] map is total over the tone enum
  /// so no tone can lose it.
  final bool? showRule;

  /// The hairline that closes the shape, in the tone's own hue.
  ///
  /// A tinted fill with no edge is a rectangle of colour floating on the page
  /// — the shape every stock alert component has, and the reason a stack of
  /// them reads as swatches rather than as one family. The border is the
  /// accent laid over the fill at a low alpha rather than a second palette
  /// entry, so it is always a step from the fill it encloses and never a hard
  /// line drawn beside it.
  final Color? borderColor;
  final double? borderWidth;

  final double? iconSize;
  final double? iconGap;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final Color? fillColor;
  final Color? accentColor;
  final Color? foregroundColor;

  /// A map rather than five fields, because a consumer swapping to their own
  /// icon set wants to do it once. It is the only `Map` in any style class in
  /// the kit and it earns it: the alternative is `infoIcon`, `successIcon`,
  /// `warningIcon`, `errorIcon`, `neutralIcon`, and a sixth the day a tone is
  /// added.
  final Map<DSMessageTone, IconData>? icons;

  @override
  DSMessageStyle merge(DSMessageStyle? other) {
    if (other == null) return this;
    return DSMessageStyle(
      padding: other.padding ?? padding,
      radius: other.radius ?? radius,
      ruleWidth: other.ruleWidth ?? ruleWidth,
      showRule: other.showRule ?? showRule,
      borderColor: other.borderColor ?? borderColor,
      borderWidth: other.borderWidth ?? borderWidth,
      iconSize: other.iconSize ?? iconSize,
      iconGap: other.iconGap ?? iconGap,
      titleStyle: other.titleStyle ?? titleStyle,
      messageStyle: other.messageStyle ?? messageStyle,
      fillColor: other.fillColor ?? fillColor,
      accentColor: other.accentColor ?? accentColor,
      foregroundColor: other.foregroundColor ?? foregroundColor,
      // Merged key by key: a consumer replacing the error glyph alone should
      // not lose the other four.
      icons: icons == null || other.icons == null
          ? other.icons ?? icons
          : {...icons!, ...other.icons!},
    );
  }

  @override
  DSMessageStyle copyWith({
    EdgeInsetsGeometry? padding,
    BorderRadius? radius,
    double? ruleWidth,
    bool? showRule,
    Color? borderColor,
    double? borderWidth,
    double? iconSize,
    double? iconGap,
    TextStyle? titleStyle,
    TextStyle? messageStyle,
    Color? fillColor,
    Color? accentColor,
    Color? foregroundColor,
    Map<DSMessageTone, IconData>? icons,
  }) => DSMessageStyle(
    padding: padding ?? this.padding,
    radius: radius ?? this.radius,
    ruleWidth: ruleWidth ?? this.ruleWidth,
    showRule: showRule ?? this.showRule,
    borderColor: borderColor ?? this.borderColor,
    borderWidth: borderWidth ?? this.borderWidth,
    iconSize: iconSize ?? this.iconSize,
    iconGap: iconGap ?? this.iconGap,
    titleStyle: titleStyle ?? this.titleStyle,
    messageStyle: messageStyle ?? this.messageStyle,
    fillColor: fillColor ?? this.fillColor,
    accentColor: accentColor ?? this.accentColor,
    foregroundColor: foregroundColor ?? this.foregroundColor,
    icons: icons ?? this.icons,
  );

  @override
  DSMessageStyle lerp(DSMessageStyle? other, double t) {
    if (other == null) return this;
    return DSMessageStyle(
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      radius: BorderRadius.lerp(radius, other.radius, t),
      ruleWidth: lerpDouble(ruleWidth, other.ruleWidth, t),
      // Neither of these two has a midpoint. They switch at the halfway mark
      // rather than pretending to interpolate.
      showRule: t < 0.5 ? showRule : other.showRule,
      icons: t < 0.5 ? icons : other.icons,
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      iconGap: lerpDouble(iconGap, other.iconGap, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      messageStyle: TextStyle.lerp(messageStyle, other.messageStyle, t),
      fillColor: Color.lerp(fillColor, other.fillColor, t),
      accentColor: Color.lerp(accentColor, other.accentColor, t),
      foregroundColor: Color.lerp(foregroundColor, other.foregroundColor, t),
    );
  }

  /// The glyph set every tone falls back to.
  ///
  /// Filled and rounded for the four tones that mean something, hollow for
  /// the one that does not. The outlined set this replaces was a hairline
  /// glyph beside a semibold title — the icon is one of the three channels
  /// and it was the faintest thing in the box. Filled weight is also what
  /// every kit worth copying draws here, because a 20pt outline at a 1.5pt
  /// stroke is the first thing to disappear on a dim phone in sunlight.
  ///
  /// [DSMessageTone.neutral] keeps a ring on purpose: it is the tone with no
  /// hue and nothing to report, and an unfilled glyph says so before the text
  /// does.
  ///
  /// Total over [DSMessageTone] by construction, and a widget test plus a
  /// `ui_lint` rule keep it that way — a tone with no icon is a message whose
  /// only channel is colour.
  static const Map<DSMessageTone, IconData> defaultIcons = {
    DSMessageTone.neutral: Icons.circle_outlined,
    DSMessageTone.info: Icons.info_rounded,
    DSMessageTone.success: Icons.check_circle_rounded,
    DSMessageTone.warning: Icons.warning_rounded,
    DSMessageTone.error: Icons.error_rounded,
  };

  static DSMessageStyle resolve(
    BuildContext context,
    DSMessageTone tone,
    DSMessageScope scope, [
    DSMessageStyle? own,
  ]) {
    final palette = context.palette;
    final design = context.design;
    final space = design.space;
    final text = Theme.of(context).textTheme;

    // `neutral` is state rather than information, and it reads as state
    // because it is the one tone with no hue: the audit found four call sites
    // using `info` for a draft or a read-only notice, and a blue "Draft"
    // reads as something the user should act on.
    final (ground, accent, foreground) = switch (tone) {
      // `outlineSoft` was the plan's choice for the rule and it disappeared
      // in the golden — 1.5:1 on `well`. The rule is one of the three
      // redundant channels, so a rule nobody can see is the defect this
      // component exists to fix. `textSecondary` clears 4.5:1 on `well` in
      // both themes and still reads as grey, which is what `neutral` means.
      DSMessageTone.neutral => (
        palette.muted,
        palette.mutedForeground,
        palette.foreground,
      ),
      DSMessageTone.info => (
        palette.tint(palette.primary),
        palette.primary,
        palette.foreground,
      ),
      DSMessageTone.success => (
        palette.tint(palette.success),
        palette.success,
        palette.foreground,
      ),
      DSMessageTone.warning => (
        palette.tint(palette.warning),
        palette.warning,
        palette.foreground,
      ),
      DSMessageTone.error => (
        palette.tint(palette.destructive),
        palette.destructive,
        palette.foreground,
      ),
    };

    // The wash and the hairline it implies — `DSToneWash`, which `DSCard`
    // reads too, so a `success` message and a `success` card on one screen
    // are the same green. Both are derived from the two colours above rather
    // than being palette entries of their own, so an identity that re-hues
    // `error` gets a matching fill and edge for free.
    final neutral = tone == DSMessageTone.neutral;
    final fill = DSToneWash.fill(
      container: ground,
      surface: palette.card,
      neutral: neutral,
    );
    final border = DSToneWash.border(
      accent: accent,
      fill: fill,
      brightness: palette.brightness,
      neutral: neutral,
    );

    final (padding, radius, icon, title, message) = switch (scope) {
      DSMessageScope.compact => (
        EdgeInsets.symmetric(
          horizontal: space.md,
          vertical: space.sm + space.hairline,
        ),
        BorderRadius.all(Radius.circular(context.radiusOf(AppShape.control))),
        design.component.iconSizeSmall,
        DSTextRole.control.styleOf(context),
        text.bodySmall,
      ),
      DSMessageScope.section => (
        // Square-ish rather than tall: 16 and 14 around a 20pt glyph is the
        // inset a bordered box wants, and the 14 the release before this used
        // on the horizontal was tuned for a box with no edge to sit inside.
        EdgeInsets.symmetric(
          horizontal: space.lg,
          vertical: space.md + space.hairline,
        ),
        BorderRadius.all(Radius.circular(context.radiusOf(AppShape.card))),
        design.component.iconSizeInline,
        DSTextRole.control.styleOf(context),
        text.bodyMedium,
      ),
      DSMessageScope.screen => (
        EdgeInsets.symmetric(
          horizontal: space.pageGutter,
          vertical: space.md + space.hairline,
        ),
        // Square at the screen edges: a full-bleed surface with rounded
        // corners has two left edges, one of them imaginary.
        BorderRadius.zero,
        design.component.iconSizeInline,
        DSTextRole.control.styleOf(context),
        text.bodyMedium,
      ),
    };

    return resolveStyle(
      context: context,
      specDefaults: DSMessageStyle(
        padding: padding,
        radius: radius,
        ruleWidth: space.hairline + 1,
        showRule: false,
        borderColor: border,
        borderWidth: design.component.hairlineWidth,
        iconSize: icon,
        iconGap: space.md,
        titleStyle: title.copyWith(
          color: foreground,
          fontWeight: context.design.type.emphasisWeight,
        ),
        messageStyle: message?.copyWith(color: foreground),
        fillColor: fill,
        accentColor: accent,
        foregroundColor: foreground,
        icons: defaultIcons,
      ),
      own: own,
    );
  }
}

/// A persistent message about the state of something.
///
/// See `docs/plans/11-ds-message.plan.md`. This is `DSBanner` and `DSInfoCard`
/// merged: they declared identical variant enums and differed only in radius,
/// padding and whether there was a body — which is a [DSMessageScope], not a
/// second class.
///
/// [message] is required, and that is the accessibility fix rather than a
/// convenience: `DSInfoCard` took a title and an icon and no body, so on the
/// demo screens the difference between "saved" and "failed" was a glyph and a
/// hue. Three channels now, always — icon, tone and text.
///
/// **Use when** the message must survive until it is acted on. **Instead:**
/// `DSSnackBar` when it merely confirms something that already happened;
/// `DSDialog` when the user must answer before anything else can happen;
/// `DSTextField.errorText` when it belongs to one field.
class DSMessage extends StatefulWidget {
  const DSMessage({
    super.key,
    required this.message,
    this.title,
    this.tone = DSMessageTone.info,
    this.scope = DSMessageScope.section,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.icon,
    this.loading = false,
    this.haptic = false,
    this.style,
    this.titleSlot,
    this.messageSlot,
    this.iconSlot,
    this.action,
    this.trailing,
    this.footer,
  });

  /// Full bleed, under the app bar.
  const DSMessage.screen({
    super.key,
    required this.message,
    this.title,
    this.tone = DSMessageTone.info,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.icon,
    this.loading = false,
    this.haptic = false,
    this.style,
    this.titleSlot,
    this.messageSlot,
    this.iconSlot,
    this.action,
    this.trailing,
    this.footer,
  }) : scope = DSMessageScope.screen;

  /// Inset, inside a card or a section.
  const DSMessage.section({
    super.key,
    required this.message,
    this.title,
    this.tone = DSMessageTone.info,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.icon,
    this.loading = false,
    this.haptic = false,
    this.style,
    this.titleSlot,
    this.messageSlot,
    this.iconSlot,
    this.action,
    this.trailing,
    this.footer,
  }) : scope = DSMessageScope.section;

  /// One line, no title, no action, no dismiss.
  const DSMessage.compact({
    super.key,
    required this.message,
    this.tone = DSMessageTone.info,
    this.icon,
    this.loading = false,
    this.style,
    this.messageSlot,
    this.iconSlot,
  }) : scope = DSMessageScope.compact,
       title = null,
       actionLabel = null,
       onAction = null,
       onDismiss = null,
       haptic = false,
       titleSlot = null,
       action = null,
       trailing = null,
       footer = null;

  /// Required. A message that is only an icon and a tone cannot be built.
  final String message;

  final String? title;
  final DSMessageTone tone;
  final DSMessageScope scope;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Null is not dismissible, and that is the default for [DSMessageTone.error]
  /// at the call site: a message the user can dismiss without fixing was not
  /// important, and one they can neither dismiss nor act on is a trap.
  final VoidCallback? onDismiss;

  /// Defaults to the tone's glyph. [iconSlot] is the hatch.
  final IconData? icon;

  final bool loading;

  /// Whether the message is a consequence of something the user just did.
  ///
  /// Off by default, because the widget cannot tell: a `warning` that appears
  /// because the device went offline is ambient, and buzzing a pocket for it
  /// teaches the user to ignore the buzz. The caller knows which it is.
  final bool haptic;

  final DSMessageStyle? style;
  final Widget? titleSlot;
  final Widget? messageSlot;
  final Widget? iconSlot;

  /// A caller needing two actions, a countdown or a progress bar. The
  /// one-primary-action rule is then theirs to keep.
  final Widget? action;

  /// Replaces the dismiss control — a "Learn more" chevron, a snooze menu.
  final Widget? trailing;

  final Widget? footer;

  /// Warning and error interrupt; the rest wait their turn.
  ///
  /// This is the ARIA `alert` / `status` split, and it matters because a
  /// polite green "Saved" must not cut across what the user is reading.
  bool get assertive =>
      tone == DSMessageTone.warning || tone == DSMessageTone.error;

  @override
  State<DSMessage> createState() => _DSMessageState();
}

class _DSMessageState extends State<DSMessage>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final motion = context.design.motion;
    _controller = AnimationController(
      vsync: this,
      duration: motion.scaled(motion.normal),
      value: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
    );
    if (!MediaQuery.disableAnimationsOf(context)) _controller!.forward();
    _announce();
    if (widget.haptic && widget.assertive) AppHaptics.warning();
  }

  @override
  void didUpdateWidget(covariant DSMessage old) {
    super.didUpdateWidget(old);
    if (old.tone != widget.tone || old.message != widget.message) _announce();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// A `liveRegion` alone cannot say *how* urgently, so the two assertive
  /// tones also post an assertive announcement. Flutter's widget-level
  /// `Semantics` has no politeness argument; `SemanticsService` does.
  void _announce() {
    if (!widget.assertive) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      [widget.title, widget.message].nonNulls.join('. '),
      Directionality.of(context),
      assertiveness: Assertiveness.assertive,
    );
  }

  Future<void> _dismiss() async {
    // The removal is committed only after the collapse, so the list below
    // does not snap shut around a gap.
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _controller!.reverse();
    }
    widget.onDismiss!();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSMessageStyle.resolve(
      context,
      widget.tone,
      widget.scope,
      widget.style,
    );
    final motion = context.design.motion;
    final curve = CurvedAnimation(
      parent: _controller!,
      curve: motion.enter,
      reverseCurve: motion.exit,
    );

    // The annotation is the outermost thing this widget builds, not something
    // buried under the transitions: a live region under an animation is a node
    // a reader finds only if it happens to walk that far.
    return Semantics(
      container: true,
      liveRegion: true,
      child: SizeTransition(
        sizeFactor: curve,
        alignment: AlignmentDirectional.topStart,
        child: FadeTransition(
          opacity: curve,
          child: _surface(context, resolved),
        ),
      ),
    );
  }

  /// The edge, as one decision rather than two.
  ///
  /// Three shapes come out of it: a hairline all the way round for a box that
  /// sits inside a layout, a hairline along the bottom only for the full
  /// bleed one — a vertical line at the bezel is an edge the screen already
  /// has — and the classic accent bar down the leading side when a caller
  /// asks for it. `borderWidth: 0` with `showRule: false` is the way back to
  /// no edge at all.
  BoxBorder? _border(DSMessageStyle resolved) {
    final width = resolved.borderWidth ?? 0;
    final hairline = width <= 0 || resolved.borderColor == null
        ? BorderSide.none
        : BorderSide(color: resolved.borderColor!, width: width);
    final rule = (resolved.showRule ?? false)
        ? BorderSide(color: resolved.accentColor!, width: resolved.ruleWidth!)
        : null;

    if (widget.scope == DSMessageScope.screen) {
      final leading = rule ?? BorderSide.none;
      if (leading == BorderSide.none && hairline == BorderSide.none) {
        return null;
      }
      return BorderDirectional(start: leading, bottom: hairline);
    }
    if (rule == null) {
      return hairline == BorderSide.none
          ? null
          : Border.fromBorderSide(hairline);
    }
    // The whole edge goes accent when the rule is on, and only the leading
    // side is thick. Two colours on one rounded box is not a look Flutter
    // will draw — `Border.paint` asserts on it — and it is not one worth
    // wanting either: an accent bar joined to a neutral hairline reads as a
    // seam.
    final rest = BorderSide(
      color: resolved.accentColor!,
      width: hairline.width,
    );
    return BorderDirectional(start: rule, top: rest, end: rest, bottom: rest);
  }

  Widget _surface(BuildContext context, DSMessageStyle resolved) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolved.fillColor,
        // Null rather than zero. `BorderDirectional.paint` asserts
        // `borderRadius == null` on a non-uniform border where `Border.paint`
        // only rejects a *non-zero* radius, and the screen scope is square —
        // so a square directional border would assert on paint.
        borderRadius: resolved.radius == BorderRadius.zero
            ? null
            : resolved.radius,
        border: _border(resolved),
      ),
      child: Padding(
        padding: resolved.padding!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(context, resolved),
            if (widget.footer != null) ...[
              SizedBox(height: context.design.space.sm),
              widget.footer!,
            ],
          ],
        ),
      ),
    );
  }

  /// The height of the line the glyph has to sit on.
  ///
  /// Top-aligning the icon against the text column is what a `Row` does by
  /// default, and it is wrong by a couple of points at every text scale: a
  /// 20pt glyph hung from the top of a 22pt line box floats above the letters
  /// beside it. Measuring the leading line and centring in it is the same
  /// thing a baseline would buy, without asking a wrapping paragraph to
  /// expose one.
  double _leadLineHeight(BuildContext context, DSMessageStyle resolved) {
    final lead = widget.title != null || widget.titleSlot != null
        ? resolved.titleStyle
        : resolved.messageStyle;
    final size = lead?.fontSize;
    if (size == null) return resolved.iconSize!;
    final factor = lead?.height ?? context.design.type.bodyHeight;
    return MediaQuery.textScalerOf(context).scale(size) * factor;
  }

  Widget _row(BuildContext context, DSMessageStyle resolved) {
    final space = context.design.space;
    final action = _action(context, resolved);
    final line = math.max(
      _leadLineHeight(context, resolved),
      resolved.iconSize!,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One of three redundant channels, with nothing to say the text has
        // not — so it is excluded rather than read out as "info circle".
        ExcludeSemantics(
          child: SizedBox(
            height: line,
            child: Center(
              child:
                  widget.iconSlot ??
                  Icon(
                    widget.icon ?? resolved.icons![widget.tone],
                    size: resolved.iconSize,
                    color: resolved.accentColor,
                  ),
            ),
          ),
        ),
        SizedBox(width: resolved.iconGap!),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.titleSlot != null || widget.title != null) ...[
                      widget.titleSlot ??
                          Text(widget.title!, style: resolved.titleStyle),
                      // A 2pt gap under a semibold title is a title with a
                      // descender problem, not a title with a gap.
                      SizedBox(height: space.xs),
                    ],
                    // Never truncates. A truncated error is a support ticket.
                    widget.messageSlot ??
                        Text(widget.message, style: resolved.messageStyle),
                  ],
                ),
              ),
              if (action != null) ...[SizedBox(height: space.sm), action],
            ],
          ),
        ),
        if (widget.loading) ...[
          SizedBox(width: space.sm),
          SizedBox.square(
            dimension: resolved.iconSize!,
            // The kit's indicator, not Material's: it draws
            // `CircularProgressIndicator.adaptive`, so a working message
            // spins the system spinner on Apple instead of a Material arc.
            // This read as a Material ring on iOS for as long as the whole
            // design system was exempt from `raw-progress` by directory.
            child: DSProgressIndicator.circular(
              style: DSProgressStyle(
                strokeWidth: resolved.ruleWidth! - 1,
                indicatorColor: resolved.accentColor,
              ),
            ),
          ),
        ],
        if (widget.trailing != null) ...[
          SizedBox(width: space.sm),
          widget.trailing!,
        ] else if (widget.onDismiss != null) ...[
          SizedBox(width: space.sm),
          _dismissButton(context, resolved),
        ],
      ],
    );
  }

  /// The action sits under the message rather than beside it, at every text
  /// scale: a label that has to share a row with a wrapping message is a
  /// label that ends up two characters wide.
  Widget? _action(BuildContext context, DSMessageStyle resolved) {
    if (widget.action != null) return widget.action;
    if (widget.actionLabel == null || widget.onAction == null) return null;
    final full = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final button = DSButton(
      label: widget.actionLabel!,
      onPressed: widget.onAction,
      size: DSButtonSize.sm,
      variant: DSButtonVariant.ghost,
      fullWidth: full,
      // Text on a status tint reads in `foreground`, not the tone's accent —
      // the accent stays on the message's icon. See the icon/text split
      // ruling from the 15-role palette migration.
      style: DSButtonStyle(labelColor: resolved.foregroundColor),
    );
    return full
        ? button
        : Align(alignment: AlignmentDirectional.centerStart, child: button);
  }

  Widget _dismissButton(BuildContext context, DSMessageStyle resolved) {
    final target = context.design.component.minTapTarget;
    return IconButton(
      icon: const Icon(Icons.close_rounded),
      // Never an unlabelled ✕: the label names what is being dismissed.
      tooltip: 'Dismiss ${widget.title ?? widget.message}',
      // A step below the tone's glyph: the dismiss is the way out of the
      // message, not one of the three channels that carry it, and drawn at
      // the same weight it competes with the thing it closes.
      iconSize: context.design.component.iconSizeSmall,
      color: resolved.foregroundColor,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: target, height: target),
      onPressed: _dismiss,
    );
  }
}

/// The container a caller puts two actions in, so both read as belonging to
/// the message rather than to the screen.
class DSMessageActions extends StatelessWidget {
  const DSMessageActions({super.key, required this.children, this.tone});

  final List<Widget> children;
  final DSMessageTone? tone;

  @override
  Widget build(BuildContext context) => DSScope.merge(
    context,
    size: DSSize.sm,
    tone: tone,
    child: Wrap(
      spacing: context.design.space.sm,
      runSpacing: context.design.space.xs,
      children: children,
    ),
  );
}

/// A pointer for a generated app that pulls an update, rather than a missing
/// symbol. Removed in the next release.
@Deprecated(
  'DSBanner is now DSMessage.screen — one component, one tone enum. '
  'See docs/plans/11-ds-message.plan.md.',
)
typedef DSBanner = DSMessage;

@Deprecated('DSBannerVariant is now DSMessageTone.')
typedef DSBannerVariant = DSMessageTone;

@Deprecated(
  'DSInfoCard is now DSMessage.section, and `message` is required — an '
  'icon-and-tone-only message was the accessibility defect this fixes.',
)
typedef DSInfoCard = DSMessage;

@Deprecated('DSInfoCardVariant is now DSMessageTone.')
typedef DSInfoCardVariant = DSMessageTone;
