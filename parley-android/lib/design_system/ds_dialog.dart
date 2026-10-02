// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_overlay.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_platform.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

// A dialog takes the platform shape and sits at the floating level of the
// surface ladder, but it is deliberately NOT glass.
//
// The route owns its semantics — `namesRoute` on the title, `scopesRoute` on
// the surface, the title association a screen reader reads. Wrapping the
// surface to blur what is behind would either cost those or blur the whole
// barrier, because the blur would have to fill the screen and centre the
// surface inside itself. Losing announced semantics to gain a material is the
// wrong trade, and `docs/principles/accessibility.md` says so first.

/// What is allowed to dismiss a dialog other than one of its actions.
enum DSDialogDismiss {
  /// A tap on the scrim, plus back and Escape. The default.
  barrier,

  /// The barrier, plus a downward drag — the case the deleted
  /// `DSAnimatedModal` was serving.
  drag,

  /// Nothing. An action is the only way out.
  none,
}

/// How a dialog's actions are laid out.
enum DSDialogActionsLayout {
  /// A row while they fit, stacked when they do not. The default, and the
  /// only one that is correct at every text scale without a caller thinking
  /// about it.
  auto,

  /// Always a row.
  row,

  /// Always stacked. On Apple this is the HIG alert layout: the order is
  /// reversed so the confirming action sits above cancel, and cancel takes
  /// the default focus. Opt in when a dialog wants that shape; `auto` rows
  /// on every platform.
  stack,

  /// A row with the first action pinned to the leading edge.
  spread,
}

/// [DSDialog]'s appearance, as data.
@immutable
class DSDialogStyle extends DSComponentStyle<DSDialogStyle> {
  const DSDialogStyle({
    this.padding,
    this.wellSize,
    this.wellShape,
    this.iconSize,
    this.titleStyle,
    this.bodyStyle,
    this.titleAlign,
    this.bodyAlign,
    this.actionGap,
    this.actionsLayout,
    this.showIcon,
  });

  final EdgeInsetsGeometry? padding;
  final double? wellSize;
  final BoxShape? wellShape;
  final double? iconSize;
  final TextStyle? titleStyle;
  final TextStyle? bodyStyle;
  final TextAlign? titleAlign;

  /// Null resolves to centred, and to start-aligned past three lines.
  /// Centred paragraphs are readable at two lines and hostile at six.
  final TextAlign? bodyAlign;

  final double? actionGap;
  final DSDialogActionsLayout? actionsLayout;
  final bool? showIcon;

  @override
  DSDialogStyle merge(DSDialogStyle? other) {
    if (other == null) return this;
    return DSDialogStyle(
      padding: other.padding ?? padding,
      wellSize: other.wellSize ?? wellSize,
      wellShape: other.wellShape ?? wellShape,
      iconSize: other.iconSize ?? iconSize,
      titleStyle: other.titleStyle ?? titleStyle,
      bodyStyle: other.bodyStyle ?? bodyStyle,
      titleAlign: other.titleAlign ?? titleAlign,
      bodyAlign: other.bodyAlign ?? bodyAlign,
      actionGap: other.actionGap ?? actionGap,
      actionsLayout: other.actionsLayout ?? actionsLayout,
      showIcon: other.showIcon ?? showIcon,
    );
  }

  @override
  DSDialogStyle copyWith({
    EdgeInsetsGeometry? padding,
    double? wellSize,
    BoxShape? wellShape,
    double? iconSize,
    TextStyle? titleStyle,
    TextStyle? bodyStyle,
    TextAlign? titleAlign,
    TextAlign? bodyAlign,
    double? actionGap,
    DSDialogActionsLayout? actionsLayout,
    bool? showIcon,
  }) => DSDialogStyle(
    padding: padding ?? this.padding,
    wellSize: wellSize ?? this.wellSize,
    wellShape: wellShape ?? this.wellShape,
    iconSize: iconSize ?? this.iconSize,
    titleStyle: titleStyle ?? this.titleStyle,
    bodyStyle: bodyStyle ?? this.bodyStyle,
    titleAlign: titleAlign ?? this.titleAlign,
    bodyAlign: bodyAlign ?? this.bodyAlign,
    actionGap: actionGap ?? this.actionGap,
    actionsLayout: actionsLayout ?? this.actionsLayout,
    showIcon: showIcon ?? this.showIcon,
  );

  @override
  DSDialogStyle lerp(DSDialogStyle? other, double t) {
    if (other == null) return this;
    return DSDialogStyle(
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      wellSize: lerpDouble(wellSize, other.wellSize, t),
      wellShape: t < 0.5 ? wellShape : other.wellShape,
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      bodyStyle: TextStyle.lerp(bodyStyle, other.bodyStyle, t),
      titleAlign: t < 0.5 ? titleAlign : other.titleAlign,
      bodyAlign: t < 0.5 ? bodyAlign : other.bodyAlign,
      actionGap: lerpDouble(actionGap, other.actionGap, t),
      actionsLayout: t < 0.5 ? actionsLayout : other.actionsLayout,
      showIcon: t < 0.5 ? showIcon : other.showIcon,
    );
  }

  static DSDialogStyle resolve(BuildContext context, [DSDialogStyle? own]) {
    final design = context.design;
    final type = Theme.of(context).textTheme;

    final specDefaults = DSDialogStyle(
      padding: EdgeInsets.all(design.space.lg),
      wellSize: design.component.iconWellSize,
      wellShape: BoxShape.circle,
      iconSize: design.component.iconSize,
      titleStyle: type.titleMedium,
      bodyStyle: DSTextRole.body.styleOf(context),
      titleAlign: TextAlign.center,
      actionGap: design.space.sm,
      actionsLayout: DSDialogActionsLayout.auto,
      showIcon: true,
    );

    return resolveStyle<DSDialogStyle>(
      context: context,
      specDefaults: specDefaults,
      own: own,
    );
  }
}

/// The tinted well behind a dialog's glyph.
///
/// A component rather than a `Container` at one call site, so
/// `ComponentSpec.iconWellSize` finally reaches the surface that names it —
/// the same disconnected seam `DSListTile`'s well had.
// ds-tier: 1 — atom — The glyph above a dialog's title.
class DSDialogIcon extends StatelessWidget {
  const DSDialogIcon({super.key, this.icon, this.tone, this.style});

  final IconData? icon;
  final DSTone? tone;
  final DSDialogStyle? style;

  /// The glyph that names a *kind* of message when the caller names none.
  static IconData defaultIconFor(DSTone tone) => switch (tone) {
    DSTone.neutral => Icons.info_outline,
    DSTone.info => Icons.info_outline,
    DSTone.success => Icons.check_circle_outline,
    DSTone.warning => Icons.warning_amber,
    DSTone.error => Icons.error_outline,
  };

  /// The well's fill and the glyph that reads on it, from the palette rather
  /// than from an alpha computed at a call site. The old `alpha: 0.1` was a
  /// number that held in one theme and nothing checked the other.
  static (Color fill, Color on) wellColorsFor(BuildContext context, DSTone t) {
    final palette = context.palette;
    return switch (t) {
      DSTone.neutral => (palette.secondary, palette.secondaryForeground),
      DSTone.info => (palette.tint(palette.primary), palette.primary),
      DSTone.success => (palette.tint(palette.success), palette.success),
      DSTone.warning => (palette.tint(palette.warning), palette.warning),
      DSTone.error => (palette.tint(palette.destructive), palette.destructive),
    };
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSDialogStyle.resolve(context, style);
    final effectiveTone = tone ?? DSScope.toneOf(context) ?? DSTone.neutral;
    final (fill, on) = wellColorsFor(context, effectiveTone);

    // Decorative: the tone is carried by the title's words. A glyph that is
    // the only thing saying "this is dangerous" says it to nobody using a
    // screen reader, and to nobody who cannot separate the two hues.
    return ExcludeSemantics(
      child: Container(
        width: resolved.wellSize,
        height: resolved.wellSize,
        decoration: BoxDecoration(color: fill, shape: resolved.wellShape!),
        child: Icon(
          icon ?? defaultIconFor(effectiveTone),
          color: on,
          size: resolved.iconSize,
        ),
      ),
    );
  }
}

/// A dialog's actions, as a group rather than as a list.
///
/// Takes `List<Widget>`, never `List<DSButton>`: a button behind a
/// `Consumer`, or wrapped in a `Tooltip`, is still an action.
///
/// **Order is a platform fact, and this is the one place it is stated.** The
/// caller always writes `[cancel, confirm]`. Material puts the confirming
/// action on the trailing edge of a row; Apple stacks, with the confirming
/// action separated above and cancel last and default. The dialog this
/// replaces stacked confirm above cancel on both platforms, which is neither
/// convention.
class DSDialogActions extends StatelessWidget {
  const DSDialogActions({
    super.key,
    required this.children,
    this.layout = DSDialogActionsLayout.auto,
    this.style,
  });

  final List<Widget> children;
  final DSDialogActionsLayout layout;
  final DSDialogStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSDialogStyle.resolve(context, style);
    final gap = resolved.actionGap!;

    // `auto` rows on both platforms. The Apple HIG stack survives only as an
    // explicit `DSDialogActionsLayout.stack` opt-in for the caller that wants
    // it — two buttons that fit on one row is a UX call, not a platform one.
    //
    // Under that opt-in, and only there, Apple reverses the order so the
    // confirming action sits above cancel and cancel becomes the default
    // focus. Everywhere else the caller's own order is the group's order.
    final ordered =
        layout == DSDialogActionsLayout.stack && AppPlatform.isApple(context)
        ? children.reversed.toList()
        : children;

    final Widget group = switch (layout) {
      DSDialogActionsLayout.stack => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            ordered[i],
          ],
        ],
      ),
      DSDialogActionsLayout.spread => Row(
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) const Spacer(),
            ordered[i],
          ],
        ],
      ),
      DSDialogActionsLayout.row => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            ordered[i],
          ],
        ],
      ),
      // `OverflowBar` is Material's own answer to this exact question: lay
      // them out in a row, and when the row does not fit, stack them. Two
      // long labels at text scale 2.0 stack rather than truncate, which is
      // what a hand-written `Row` cannot promise.
      DSDialogActionsLayout.auto => OverflowBar(
        alignment: MainAxisAlignment.end,
        spacing: gap,
        overflowSpacing: gap,
        overflowAlignment: OverflowBarAlignment.end,
        children: ordered,
      ),
    };

    return DSScope.merge(context, size: DSSize.md, child: group);
  }
}

/// A surface that interrupts, states one thing, and requires a decision
/// before the task continues.
class DSDialog extends StatelessWidget {
  const DSDialog({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.content,
    this.actions,
    this.titleSlot,
    this.tone = DSTone.neutral,
    this.style,
  }) : assert(
         title.length > 0,
         'A dialog without a title has no accessible name: the route is '
         'announced by its title, and "dialog" is not one.',
       );

  final String title;

  /// The short form. [content] is the general one — a checkbox, a list, a
  /// field, a diff — and the reason this component stopped taking only a
  /// `String message`.
  final String? message;

  final Widget? icon;
  final Widget? content;
  final Widget? actions;
  final Widget? titleSlot;
  final DSTone tone;
  final DSDialogStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSDialogStyle.resolve(context, style);
    final design = context.design;
    final palette = context.palette;

    final body = content ?? (message == null ? null : Text(message!));

    // Past three lines the paragraph starts at the leading edge. A dialog
    // long enough to have six centred lines is usually a sheet, but where it
    // is not, the alignment should not make it worse.
    final bodyAlign =
        resolved.bodyAlign ??
        ((message?.length ?? 0) > 160 ? TextAlign.start : TextAlign.center);

    return DSScope.merge(
      context,
      tone: tone,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: DSOverlaySurface(
          presentation: DSOverlayPresentation.dialog,
          showDragHandle: false,
          style: const DSOverlayStyle(),
          child: Padding(
            padding: resolved.padding!,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (resolved.showIcon! && icon != null) ...[
                  Center(child: icon!),
                  SizedBox(height: design.space.md),
                ],
                Semantics(
                  namesRoute: true,
                  header: true,
                  child:
                      titleSlot ??
                      Text(
                        title,
                        style: resolved.titleStyle,
                        textAlign: resolved.titleAlign,
                      ),
                ),
                if (body != null) ...[
                  SizedBox(height: design.space.xs),
                  DefaultTextStyle.merge(
                    style: resolved.bodyStyle?.copyWith(
                      color: palette.mutedForeground,
                    ),
                    textAlign: bodyAlign,
                    child: body,
                  ),
                ],
                if (actions != null) ...[
                  SizedBox(height: design.space.lg),
                  actions!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Presents a dialog and returns whatever it pops.
///
/// `Future<T?>`, not `Future<bool?>`: a dialog that asks which folder, or
/// collects a name before deleting, or offers three options, was not
/// expressible before and is the general case.
Future<T?> showDSDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  Widget? actions,
  IconData? icon,
  DSTone tone = DSTone.neutral,
  DSDialogDismiss dismissible = DSDialogDismiss.barrier,
  DSDialogStyle? style,
}) => showDSOverlay<T>(
  context: context,
  presentation: DSOverlayPresentation.dialog,
  barrierDismissible: dismissible != DSDialogDismiss.none,
  enableDrag: dismissible == DSDialogDismiss.drag,
  // Deliberately no drag by default even though the route supplies one: a
  // dialog demands a decision, and a surface that can be flung away is not
  // demanding one.
  exitOverride: dismissible == DSDialogDismiss.drag
      ? DSOverlayExit.down
      : DSOverlayExit.none,
  semanticLabel: title,
  builder: (context) => DSDialog(
    title: title,
    message: message,
    content: content,
    actions: actions,
    tone: tone,
    icon: DSDialogIcon(icon: icon, tone: tone),
    style: style,
  ),
);

/// The common case, kept short: two actions and a yes-or-no answer.
///
/// [destructive] is a named boolean rather than `tone: DSTone.error` because
/// it changes the default focus as well as the colour — the destructive
/// action is *not* focused, which is the rule both platforms state and which
/// a tone value would not lead a reader to expect.
Future<bool?> showDSConfirm({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData? icon,
  DSTone tone = DSTone.neutral,
  bool destructive = false,
  Future<void> Function()? onConfirm,
}) {
  final effectiveTone = destructive ? DSTone.error : tone;
  return showDSOverlay<bool>(
    context: context,
    presentation: DSOverlayPresentation.dialog,
    barrierDismissible: true,
    enableDrag: false,
    exitOverride: DSOverlayExit.none,
    semanticLabel: title,
    builder: (context) => _DSConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      tone: effectiveTone,
      destructive: destructive,
      onConfirm: onConfirm,
    ),
  );
}

/// The two-action dialog, including what happens while the answer is still
/// being acted on.
class _DSConfirmDialog extends StatefulWidget {
  const _DSConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.icon,
    required this.tone,
    required this.destructive,
    required this.onConfirm,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;
  final DSTone tone;
  final bool destructive;
  final Future<void> Function()? onConfirm;

  @override
  State<_DSConfirmDialog> createState() => _DSConfirmDialogState();
}

class _DSConfirmDialogState extends State<_DSConfirmDialog> {
  bool _pending = false;

  Future<void> _confirm() async {
    final work = widget.onConfirm;
    if (work == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _pending = true);
    // The scrim locks while the work is in flight. A dialog that vanishes
    // under a stray tap mid-request leaves the user with no idea whether the
    // thing happened.
    setDSOverlayBarrierDismissible(context, false);
    try {
      await work();
    } finally {
      if (mounted) {
        setDSOverlayBarrierDismissible(context, true);
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancel = DSButton(
      label: widget.cancelLabel,
      variant: DSButtonVariant.ghost,
      // `autofocus` on cancel is the destructive rule, encoded: the
      // dangerous action must not be one Return away.
      autofocus: widget.destructive,
      onPressed: _pending ? null : () => Navigator.of(context).pop(false),
    );
    final confirm = DSButton(
      label: widget.confirmLabel,
      variant: widget.destructive
          ? DSButtonVariant.destructive
          : DSButtonVariant.primary,
      autofocus: !widget.destructive,
      loading: _pending,
      onPressed: _pending ? null : _confirm,
    );

    return DSDialog(
      title: widget.title,
      message: widget.message,
      tone: widget.tone,
      icon: DSDialogIcon(icon: widget.icon, tone: widget.tone),
      actions: DSDialogActions(children: [cancel, confirm]),
    );
  }
}
