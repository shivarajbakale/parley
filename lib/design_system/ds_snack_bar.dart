// ds-tier: 2 — molecule

import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:parley_android/design_system/ds_bottom_insets.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Which edge a snack bar arrives at.
enum DSSnackBarPlacement { bottom, top }

/// How a snack bar looks, at every layer of the resolution chain.
@immutable
class DSSnackBarStyle extends DSComponentStyle<DSSnackBarStyle> {
  const DSSnackBarStyle({
    this.maxWidth,
    this.margin,
    this.padding,
    this.shape,
    this.fill,
    this.foreground,
    this.iconSize,
    this.duration,
    this.placement,
  });

  final double? maxWidth;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final AppShape? shape;
  final Color? fill;
  final Color? foreground;
  final double? iconSize;

  /// How long the bar stays before it leaves on its own.
  final Duration? duration;

  final DSSnackBarPlacement? placement;

  @override
  DSSnackBarStyle merge(DSSnackBarStyle? other) {
    if (other == null) return this;
    return DSSnackBarStyle(
      maxWidth: other.maxWidth ?? maxWidth,
      margin: other.margin ?? margin,
      padding: other.padding ?? padding,
      shape: other.shape ?? shape,
      fill: other.fill ?? fill,
      foreground: other.foreground ?? foreground,
      iconSize: other.iconSize ?? iconSize,
      duration: other.duration ?? duration,
      placement: other.placement ?? placement,
    );
  }

  @override
  DSSnackBarStyle copyWith({
    double? maxWidth,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    AppShape? shape,
    Color? fill,
    Color? foreground,
    double? iconSize,
    Duration? duration,
    DSSnackBarPlacement? placement,
  }) => DSSnackBarStyle(
    maxWidth: maxWidth ?? this.maxWidth,
    margin: margin ?? this.margin,
    padding: padding ?? this.padding,
    shape: shape ?? this.shape,
    fill: fill ?? this.fill,
    foreground: foreground ?? this.foreground,
    iconSize: iconSize ?? this.iconSize,
    duration: duration ?? this.duration,
    placement: placement ?? this.placement,
  );

  @override
  DSSnackBarStyle lerp(DSSnackBarStyle? other, double t) {
    if (other == null) return this;
    return DSSnackBarStyle(
      maxWidth: lerpDouble(maxWidth, other.maxWidth, t),
      margin: EdgeInsetsGeometry.lerp(margin, other.margin, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      shape: t < 0.5 ? shape : other.shape,
      fill: Color.lerp(fill, other.fill, t),
      foreground: Color.lerp(foreground, other.foreground, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      duration: t < 0.5 ? duration : other.duration,
      placement: t < 0.5 ? placement : other.placement,
    );
  }

  /// The fill and foreground a tone reports in, derived by the identity.
  ///
  /// `AppColors.success` and `AppColors.warning` used to be read here as
  /// constants: they did not move with the theme and were contrast-checked
  /// against nothing. Every pair below comes from the palette, so a dark build
  /// gets a dark build's answer.
  static (Color, Color) toneColors(BuildContext context, DSTone tone) {
    final palette = context.palette;
    return switch (tone) {
      DSTone.neutral => (palette.inverseBackground, palette.inverseForeground),
      DSTone.info => (palette.primary, palette.primaryForeground),
      DSTone.success => (palette.success, palette.onSuccess),
      DSTone.warning => (palette.warning, palette.onWarning),
      DSTone.error => (palette.destructive, palette.onDestructive),
    };
  }

  /// The default glyph for a tone. Null for [DSTone.neutral]: a plain report
  /// has nothing to illustrate, and an icon there is decoration.
  static IconData? toneIcon(DSTone tone) => switch (tone) {
    DSTone.neutral => null,
    DSTone.info => Icons.info_outline,
    DSTone.success => Icons.check_circle_outline,
    DSTone.warning => Icons.warning_amber,
    DSTone.error => Icons.error_outline,
  };

  static DSSnackBarStyle resolve(
    BuildContext context, {
    DSTone tone = DSTone.neutral,
    bool hasAction = false,
    DSSnackBarStyle? own,
  }) {
    final design = context.design;
    final component = design.component;
    final space = design.space;
    final (fill, foreground) = toneColors(context, tone);

    return resolveStyle(
      context: context,
      specDefaults: DSSnackBarStyle(
        maxWidth: component.snackMaxWidth,
        margin: EdgeInsets.all(space.md),
        padding: EdgeInsets.symmetric(
          horizontal: space.md,
          vertical: space.sm + space.hairline,
        ),
        shape: AppShape.card,
        fill: fill,
        foreground: foreground,
        iconSize: component.iconSizeInline,
        duration: hasAction
            ? component.snackActionDuration
            : component.snackDuration,
        placement: DSSnackBarPlacement.bottom,
      ),
      own: own,
    );
  }
}

/// The app's transient message.
///
/// See `docs/plans/30-ds-snackbar-fab-action-bar.plan.md`. It is a widget now.
/// It used to be `class DSSnackBar { DSSnackBar._(); static void show }` —
/// the one component in the kit that could not take a style object, could not
/// be rendered in the catalog and could not be golden-tested, because there
/// was nothing to render.
///
/// It is the weakest of the kit's four ways to say that something happened,
/// and it must stay that way: it is transient, it never takes focus, and it
/// must never carry the only copy of something the user needs. `DSMessage`
/// states a condition alongside the content, `DSDialog` asks for a decision,
/// and `DSErrorState` is what the content becomes when it fails.
///
/// **The haptic is the reason a snack bar is in the design system at all.** A
/// failure the user feels is a failure they notice, and the same message with
/// no haptic is one they scroll past. [showDSSnackBar] fires the haptic that
/// matches the tone, and a test asserts it.
class DSSnackBar extends StatelessWidget {
  const DSSnackBar({
    super.key,
    required this.message,
    this.tone = DSTone.neutral,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.iconSlot,
    this.messageSlot,
    this.action,
    this.style,
  }) : assert(
         actionLabel == null || onAction != null,
         'an action label with nothing to invoke is a button that does '
         'nothing — pass onAction',
       );

  /// What happened, in one line the user does not have to act on.
  final String message;

  final DSTone tone;

  /// Overrides the tone's own glyph.
  final IconData? icon;

  final String? actionLabel;
  final VoidCallback? onAction;

  final Widget? iconSlot;
  final Widget? messageSlot;

  /// Replaces the trailing action. Ships [DSSnackBarAction].
  final Widget? action;

  final DSSnackBarStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSSnackBarStyle.resolve(
      context,
      tone: tone,
      hasAction: actionLabel != null || action != null,
      own: style,
    );
    final glyph = icon ?? DSSnackBarStyle.toneIcon(tone);
    final text = Theme.of(context).textTheme;
    final space = context.design.space;

    final trailing =
        action ??
        (actionLabel != null
            ? DSSnackBarAction(label: actionLabel!, onPressed: onAction!)
            : null);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: resolved.maxWidth!),
      // Above the content it covers, at the overlay's own step: a snackbar
      // that casts nothing reads as a stripe painted on the screen.
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: context.shapeOf(resolved.shape!),
          shadows: context.design.elevation.resolve(
            elevation: context.design.elevation.high,
            brightness: context.palette.brightness,
            shadowColor: context.palette.overlay,
          ),
        ),
        child: Material(
          color: resolved.fill,
          shape: context.shapeOf(resolved.shape!),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: resolved.padding!,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconSlot != null)
                  iconSlot!
                else if (glyph != null)
                  Icon(
                    glyph,
                    color: resolved.foreground,
                    size: resolved.iconSize,
                  ),
                if (iconSlot != null || glyph != null)
                  SizedBox(width: space.md),
                Expanded(
                  child:
                      messageSlot ??
                      Text(
                        message,
                        // One step below body: the bar is a transient report,
                        // not the page's own prose, and at 16pt a two-line
                        // message pushes the bar tall enough to cover the row
                        // the user just acted on.
                        style: text.bodySmall?.copyWith(
                          color: resolved.foreground,
                        ),
                      ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: space.sm),
                  // The action is small and sits on the tone's own fill, so it
                  // inherits both from the bar rather than being told twice.
                  DSScope(
                    size: DSSize.sm,
                    child: IconTheme.merge(
                      data: IconThemeData(color: resolved.foreground),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: resolved.foreground),
                        child: trailing,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The one action a snack bar is allowed to carry.
///
/// A ghost button at `sm`, tinted by the bar rather than by the palette: a
/// primary fill inside a coloured bar reads as a second bar.
class DSSnackBarAction extends StatelessWidget {
  const DSSnackBarAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = DefaultTextStyle.of(context).style.color;
    return DSButton(
      label: label,
      variant: DSButtonVariant.ghost,
      size: DSButtonSize.sm,
      onPressed: onPressed,
      style: DSButtonStyle(labelColor: foreground),
    );
  }
}

/// Shows [message] over the current screen, above whatever is pinned there.
///
/// Fires the haptic for [tone] on the way in. The bar is placed from
/// [DSBottomInsets], so it clears a pinned action bar, a bottom navigation bar
/// and the floating action button rather than landing on any of them.
///
/// A second call replaces the bar on screen rather than stacking under it:
/// two snack bars are two things the user cannot read at once.
void showDSSnackBar(
  BuildContext context, {
  required String message,
  DSTone tone = DSTone.neutral,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
  DSSnackBarStyle? style,
}) {
  switch (tone) {
    case DSTone.success:
      AppHaptics.success();
    case DSTone.error:
      AppHaptics.error();
    case DSTone.warning:
      AppHaptics.warning();
    case DSTone.info:
    case DSTone.neutral:
      AppHaptics.light();
  }

  _DSSnackBarHost.of(context).show(
    _SnackRequest(
      message: message,
      tone: tone,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      style: style,
      insets: DSBottomInsets.of(context),
      placement: DSSnackBarStyle.resolve(
        context,
        tone: tone,
        own: style,
      ).placement!,
    ),
  );
}

/// Removes the snack bar on screen, if there is one.
void hideDSSnackBar(BuildContext context) =>
    _DSSnackBarHost.maybeOf(context)?.dismiss();

@immutable
class _SnackRequest {
  const _SnackRequest({
    required this.message,
    required this.tone,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.style,
    required this.insets,
    required this.placement,
  });

  final String message;
  final DSTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration? duration;
  final DSSnackBarStyle? style;
  final DSBottomInsets insets;
  final DSSnackBarPlacement placement;
}

/// The one place a snack bar is presented from.
///
/// An `OverlayEntry` rather than a route, which is the opposite of what
/// `docs/plans/17-ds-overlay.plan.md` asks of every other surface in the kit,
/// and deliberately: a route takes focus, answers the back button and blocks
/// what is under it, and a snack bar must do none of the three. `ui_lint`'s
/// `raw-overlay-entry` rule names this file beside `ds_overlay.dart` for that
/// reason, so the exception is a line in a lint file rather than a judgement
/// made again at every call site.
class _DSSnackBarHost {
  _DSSnackBarHost._(this._overlay);

  final OverlayState _overlay;
  final GlobalKey<_SnackScaffoldState> _key = GlobalKey<_SnackScaffoldState>();
  OverlayEntry? _entry;

  static final Map<OverlayState, _DSSnackBarHost> _hosts =
      <OverlayState, _DSSnackBarHost>{};

  static _DSSnackBarHost of(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    return _hosts.putIfAbsent(overlay, () => _DSSnackBarHost._(overlay));
  }

  static _DSSnackBarHost? maybeOf(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    return overlay == null ? null : _hosts[overlay];
  }

  void show(_SnackRequest request) {
    if (_entry == null) {
      final entry = OverlayEntry(
        builder: (_) => _SnackScaffold(key: _key, onEmpty: _remove),
      );
      _entry = entry;
      _overlay.insert(entry);
      // The host is built on the frame after the insert, so the first request
      // is handed over once it exists rather than dropped.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _key.currentState?.show(request),
      );
      return;
    }
    _key.currentState?.show(request);
  }

  void dismiss() => _key.currentState?.dismiss();

  void _remove() {
    _entry?.remove();
    _entry = null;
    _hosts.remove(_overlay);
  }
}

class _SnackScaffold extends StatefulWidget {
  const _SnackScaffold({super.key, required this.onEmpty});

  final VoidCallback onEmpty;

  @override
  State<_SnackScaffold> createState() => _SnackScaffoldState();
}

class _SnackScaffoldState extends State<_SnackScaffold>
    with SingleTickerProviderStateMixin {
  _SnackRequest? _current;
  late final AnimationController _controller;
  Timer? _timer;
  final FocusScopeNode _actionScope = FocusScopeNode(debugLabel: 'snack');
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _actionScope.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = context.design.motion.normal;
    _controller.reverseDuration = context.design.motion.fast;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _actionScope.removeListener(_onFocusChanged);
    _actionScope.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // The timer pauses while the action has focus. An action that vanishes
    // under the user's hand is worse than no action.
    _held = _actionScope.hasFocus;
    if (_held) {
      _timer?.cancel();
    } else {
      _restartTimer();
    }
  }

  void show(_SnackRequest request) {
    setState(() => _current = request);
    _controller.forward();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    final request = _current;
    if (request == null || _held) return;
    // A screen reader is reading this message aloud, which takes longer than
    // reading it. Both platforms ask for the timer to wait; the kit's own
    // reduced-motion and semantics settings live in the same place.
    if (SemanticsBinding.instance.semanticsEnabled) return;
    final duration =
        request.duration ??
        DSSnackBarStyle.resolve(
          context,
          tone: request.tone,
          hasAction: request.actionLabel != null,
          own: request.style,
        ).duration!;
    _timer = Timer(duration, dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    if (_current == null) return;
    _controller.reverse().whenComplete(() {
      if (!mounted) return;
      setState(() => _current = null);
      widget.onEmpty();
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = _current;
    if (request == null) return const SizedBox.shrink();

    final motion = context.design.motion;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: motion.enter,
      reverseCurve: motion.exit,
    );
    final bottom = request.placement == DSSnackBarPlacement.bottom;

    final bar = DSSnackBar(
      // Keyed by the message so a replacement cross-fades rather than
      // mutating the bar on screen under the reader's eyes.
      key: ValueKey<String>(request.message),
      message: request.message,
      tone: request.tone,
      icon: request.icon,
      actionLabel: request.actionLabel,
      onAction: request.onAction == null
          ? null
          : () {
              dismiss();
              request.onAction!();
            },
      style: request.style,
    );

    // The one gap the bar keeps from whatever it rests above — the home
    // indicator on a bare screen, the nav bar on a crowded one.
    final margin = DSSnackBarStyle.resolve(
      context,
      tone: request.tone,
      hasAction: request.actionLabel != null,
      own: request.style,
    ).margin!.resolve(Directionality.of(context));

    return Positioned(
      left: 0,
      right: 0,
      // No `SafeArea` here. `snackOffset` already clears the home indicator,
      // and wrapping the bar in one as well counted it twice: on an iPhone the
      // bar rested 68 points off the edge, reading as adrift in the content
      // rather than as arriving at the bottom of the screen.
      bottom: bottom ? request.insets.snackOffset + margin.bottom : null,
      top: bottom ? null : MediaQuery.viewPaddingOf(context).top + margin.top,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: margin.left),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: reduced ? Offset.zero : Offset(0, bottom ? 0.6 : -0.6),
                end: Offset.zero,
              ).animate(curved),
              child: Dismissible(
                key: ValueKey<String>('dismiss-${request.message}'),
                direction: DismissDirection.horizontal,
                // The finger is tracked even under reduced motion: a swipe
                // that does not follow the hand reads as a broken gesture
                // rather than as a calmer one.
                dismissThresholds: const {DismissDirection.horizontal: 0.4},
                onDismissed: (_) {
                  setState(() => _current = null);
                  _timer?.cancel();
                  widget.onEmpty();
                },
                child: FocusScope(
                  node: _actionScope,
                  // Never focus-stealing: a transient message that moves
                  // focus interrupts whatever the user was doing.
                  autofocus: false,
                  child: Semantics(liveRegion: true, child: bar),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
