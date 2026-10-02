// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_illustration.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/design_system/ds_well.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The layout the three status states share.
///
/// One style class for the empty state and the error state on purpose: they
/// occupy the same rectangle at the same moment in a screen's life, and a user
/// moves between them. Designing them separately is how they end up at three
/// vertical alignments, which is visible as a jump the moment a retry
/// succeeds. A shared class makes that structural rather than a review
/// comment.
@immutable
class DSStatusStyle extends DSComponentStyle<DSStatusStyle> {
  const DSStatusStyle({
    this.wellSize,
    this.iconGap,
    this.titleGap,
    this.actionGap,
    this.titleStyle,
    this.messageStyle,
    this.detailsStyle,
    this.messageMaxWidth,
    this.alignment,
    this.padding,
    this.actionVariant,
  });

  final DSWellSize? wellSize;

  /// Icon to title, title to message, message to action. Three gaps rather
  /// than one, because the title belongs to the icon and the action does not.
  final double? iconGap;
  final double? titleGap;
  final double? actionGap;

  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final TextStyle? detailsStyle;

  /// A message wider than this stops being read and starts being skimmed.
  final double? messageMaxWidth;

  final MainAxisAlignment? alignment;
  final EdgeInsetsGeometry? padding;
  final DSButtonVariant? actionVariant;

  @override
  DSStatusStyle merge(DSStatusStyle? other) {
    if (other == null) return this;
    return DSStatusStyle(
      wellSize: other.wellSize ?? wellSize,
      iconGap: other.iconGap ?? iconGap,
      titleGap: other.titleGap ?? titleGap,
      actionGap: other.actionGap ?? actionGap,
      titleStyle: other.titleStyle ?? titleStyle,
      messageStyle: other.messageStyle ?? messageStyle,
      detailsStyle: other.detailsStyle ?? detailsStyle,
      messageMaxWidth: other.messageMaxWidth ?? messageMaxWidth,
      alignment: other.alignment ?? alignment,
      padding: other.padding ?? padding,
      actionVariant: other.actionVariant ?? actionVariant,
    );
  }

  @override
  DSStatusStyle copyWith({
    DSWellSize? wellSize,
    double? iconGap,
    double? titleGap,
    double? actionGap,
    TextStyle? titleStyle,
    TextStyle? messageStyle,
    TextStyle? detailsStyle,
    double? messageMaxWidth,
    MainAxisAlignment? alignment,
    EdgeInsetsGeometry? padding,
    DSButtonVariant? actionVariant,
  }) => DSStatusStyle(
    wellSize: wellSize ?? this.wellSize,
    iconGap: iconGap ?? this.iconGap,
    titleGap: titleGap ?? this.titleGap,
    actionGap: actionGap ?? this.actionGap,
    titleStyle: titleStyle ?? this.titleStyle,
    messageStyle: messageStyle ?? this.messageStyle,
    detailsStyle: detailsStyle ?? this.detailsStyle,
    messageMaxWidth: messageMaxWidth ?? this.messageMaxWidth,
    alignment: alignment ?? this.alignment,
    padding: padding ?? this.padding,
    actionVariant: actionVariant ?? this.actionVariant,
  );

  @override
  DSStatusStyle lerp(DSStatusStyle? other, double t) {
    if (other == null) return this;
    return DSStatusStyle(
      // Three enum fields with no midpoint.
      wellSize: t < 0.5 ? wellSize : other.wellSize,
      alignment: t < 0.5 ? alignment : other.alignment,
      actionVariant: t < 0.5 ? actionVariant : other.actionVariant,
      iconGap: lerpDouble(iconGap, other.iconGap, t),
      titleGap: lerpDouble(titleGap, other.titleGap, t),
      actionGap: lerpDouble(actionGap, other.actionGap, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      messageStyle: TextStyle.lerp(messageStyle, other.messageStyle, t),
      detailsStyle: TextStyle.lerp(detailsStyle, other.detailsStyle, t),
      messageMaxWidth: lerpDouble(messageMaxWidth, other.messageMaxWidth, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
    );
  }

  static DSStatusStyle resolve(BuildContext context, [DSStatusStyle? own]) {
    final design = context.design;
    final space = design.space;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return resolveStyle(
      context: context,
      specDefaults: DSStatusStyle(
        wellSize: DSWellSize.lg,
        iconGap: space.lg,
        titleGap: space.xs,
        actionGap: space.lg,
        titleStyle: text.titleMedium?.copyWith(
          color: palette.foreground,
          fontWeight: context.design.type.emphasisWeight,
        ),
        // `textSecondary`, not the hairline colour. Both the glyph and the
        // message used to be drawn in `outline` — the dimmest thing in the
        // palette that is still visible — so body copy in the one place a
        // user most needs to read it failed contrast on every surface.
        messageStyle: DSTextRole.bodySupport.styleOf(context),
        detailsStyle: text.bodySmall?.copyWith(color: palette.mutedForeground),
        messageMaxWidth: design.component.overlayMaxWidth,
        alignment: MainAxisAlignment.center,
        padding: space.pagePadding,
        actionVariant: DSButtonVariant.secondary,
      ),
      own: own,
    );
  }
}

/// The shared body of an empty state and an error state.
///
/// Private, and the reason the two cannot drift: one column, one alignment,
/// one set of gaps. The icon well sits at the same offset in both, which is
/// what stops the retry-succeeds jump.
class _StatusBody extends StatefulWidget {
  const _StatusBody({
    required this.title,
    required this.announcement,
    this.message,
    this.icon,
    this.tone = DSTone.neutral,
    this.iconSlot,
    this.titleSlot,
    this.messageSlot,
    this.action,
    this.secondary,
    this.details,
    this.style,
  });

  final String title;

  /// What a screen reader is told when this state appears. A sighted user sees
  /// the state change; without this a screen reader user gets silence.
  final String announcement;

  final String? message;
  final IconData? icon;
  final DSTone tone;
  final Widget? iconSlot;
  final Widget? titleSlot;
  final Widget? messageSlot;
  final Widget? action;
  final Widget? secondary;
  final Widget? details;
  final DSStatusStyle? style;

  @override
  State<_StatusBody> createState() => _StatusBodyState();
}

class _StatusBodyState extends State<_StatusBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        widget.announcement,
        Directionality.of(context),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSStatusStyle.resolve(context, widget.style);
    return Center(
      child: Padding(
        padding: resolved.padding!,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resolved.messageMaxWidth!),
          child: Column(
            mainAxisAlignment: resolved.alignment!,
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.iconSlot ??
                  DSWell(
                    icon: widget.icon,
                    tone: widget.tone,
                    size: resolved.wellSize!,
                  ),
              SizedBox(height: resolved.iconGap),
              Semantics(
                header: true,
                child:
                    widget.titleSlot ??
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: resolved.titleStyle,
                    ),
              ),
              if (widget.messageSlot != null || widget.message != null) ...[
                SizedBox(height: resolved.titleGap),
                widget.messageSlot ??
                    Text(
                      widget.message!,
                      textAlign: TextAlign.center,
                      style: resolved.messageStyle,
                    ),
              ],
              if (widget.action != null) ...[
                SizedBox(height: resolved.actionGap),
                widget.action!,
              ],
              if (widget.secondary != null) ...[
                SizedBox(height: resolved.titleGap),
                widget.secondary!,
              ],
              if (widget.details != null) ...[
                SizedBox(height: resolved.actionGap),
                widget.details!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Nothing to show — and which kind of nothing.
///
/// See `docs/plans/29-ds-status-states.plan.md`. **Use when** the list is
/// legitimately empty. **Instead:** [DSErrorState] when something failed,
/// `DSSkeleton` while it is still coming, `DSMessage` for a condition beside
/// content that *is* shown.
///
/// Empty is not one state. Nothing yet invites the action; nothing found
/// offers to clear the filter; nothing left is a positive. The three
/// constructors name them so a caller picks rather than improvising.
class DSEmptyState extends StatelessWidget {
  const DSEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.illustration,
    this.illustrationSize = DSIllustrationSize.medium,
    this.tone = DSTone.neutral,
    this.actionLabel,
    this.onAction,
    this.iconSlot,
    this.titleSlot,
    this.messageSlot,
    this.action,
    this.secondary,
    this.style,
  }) : _query = null,
       assert(
         illustration == null || icon == null,
         'an empty state with both an illustration and a glyph has two '
         'answers to what its art is — pass one',
       );

  /// A search or filter returned nothing. The query is quoted, and the way
  /// out is offered rather than left to be guessed.
  const DSEmptyState.noResults({
    super.key,
    required String query,
    this.message,
    this.actionLabel = 'Clear filters',
    this.onAction,
    this.iconSlot,
    this.titleSlot,
    this.messageSlot,
    this.action,
    this.secondary,
    this.style,
  }) : _query = query,
       // Interpolated in `build` rather than here, so the constructor stays
       // const and a story can hold one without rebuilding it every frame.
       title = '',
       icon = Icons.search_off_outlined,
       illustration = null,
       illustrationSize = DSIllustrationSize.medium,
       tone = DSTone.neutral;

  /// A queue the user finished. A positive, not a failure.
  const DSEmptyState.done({
    super.key,
    this.title = 'All done',
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconSlot,
    this.titleSlot,
    this.messageSlot,
    this.action,
    this.secondary,
    this.style,
  }) : _query = null,
       icon = Icons.check_circle_outline,
       illustration = null,
       illustrationSize = DSIllustrationSize.medium,
       tone = DSTone.success;

  final String title;
  final String? message;

  /// The glyph in the well. Null falls back to the inbox, which is what an
  /// empty state means when the caller has not said otherwise.
  final IconData? icon;

  /// Opts into the illustration tier — a drawn scene instead of the glyph.
  ///
  /// The expensive answer is opted into rather than defaulted to, because a
  /// drawing above every empty filter result is noise. Reach for it on the
  /// screens that happen once: first run, onboarding, a permission ask.
  final DSIllustrationKind? illustration;

  final DSIllustrationSize illustrationSize;

  final DSTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The query [DSEmptyState.noResults] quotes.
  final String? _query;
  final Widget? iconSlot;
  final Widget? titleSlot;
  final Widget? messageSlot;
  final Widget? action;
  final Widget? secondary;
  final DSStatusStyle? style;

  @override
  Widget build(BuildContext context) {
    final shown = _query == null ? title : 'No matches for “$_query”';
    return _StatusBody(
      title: shown,
      announcement: shown,
      message: message,
      icon: icon ?? Icons.inbox_outlined,
      tone: tone,
      iconSlot:
          iconSlot ??
          (illustration == null
              ? null
              : DSIllustration(
                  kind: illustration!,
                  size: illustrationSize,
                  tone: tone,
                )),
      titleSlot: titleSlot,
      messageSlot: messageSlot,
      action:
          action ??
          (actionLabel == null || onAction == null
              ? null
              : DSStatusAction(label: actionLabel!, onPressed: onAction!)),
      secondary: secondary,
      style: style,
    );
  }
}

/// Something failed, and what to do about it.
///
/// New in plan 29 — and not a new idea: `ds_skeleton.dart`'s doc comment has
/// been documenting the kit's canonical async pattern with `DSErrorState` in
/// the error branch since before it existed anywhere in the tree. The branch
/// that decides whether a user retries or leaves had no component, so every
/// screen invented one and no two agreed.
///
/// **The retry is the content.** A message a user cannot act on is a dead
/// end, so the action is primary rather than an afterthought. The technical
/// string is available and not shown: a support conversation needs the real
/// error and a user does not.
class DSErrorState extends StatelessWidget {
  const DSErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.detailsText,
    this.icon = Icons.error_outline,
    this.actionLabel = 'Try again',
    this.onRetry,
    this.iconSlot,
    this.titleSlot,
    this.messageSlot,
    this.action,
    this.secondary,
    this.details,
    this.style,
  });

  final String title;
  final String? message;

  /// Collapsed by default, expands in place, and is selectable so it can be
  /// pasted into a support message.
  final String? detailsText;

  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onRetry;
  final Widget? iconSlot;
  final Widget? titleSlot;
  final Widget? messageSlot;
  final Widget? action;
  final Widget? secondary;
  final Widget? details;
  final DSStatusStyle? style;

  @override
  Widget build(BuildContext context) => _StatusBody(
    title: title,
    announcement: title,
    message: message,
    icon: icon,
    tone: DSTone.error,
    iconSlot: iconSlot,
    titleSlot: titleSlot,
    messageSlot: messageSlot,
    action:
        action ??
        (actionLabel == null || onRetry == null
            ? null
            : DSStatusAction(label: actionLabel!, onPressed: onRetry!)),
    secondary: secondary,
    details:
        details ??
        (detailsText == null ? null : DSErrorDetails(text: detailsText!)),
    style: style,
  );
}

/// The technical string, behind a disclosure.
// ds-tier: 1 — atom — The expandable technical detail under an error state.
class DSErrorDetails extends StatefulWidget {
  const DSErrorDetails({super.key, required this.text});

  final String text;

  @override
  State<DSErrorDetails> createState() => _DSErrorDetailsState();
}

class _DSErrorDetailsState extends State<DSErrorDetails> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final resolved = DSStatusStyle.resolve(context);
    final motion = context.design.motion;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Merged, not stacked: `expanded` on a wrapper and the label on the
        // button underneath is two nodes, and the one a screen reader stops
        // at is the one with no words in it.
        MergeSemantics(
          child: Semantics(
            expanded: _open,
            child: DSButton(
              label: _open ? 'Hide details' : 'Show details',
              variant: DSButtonVariant.ghost,
              size: DSButtonSize.sm,
              onPressed: () => setState(() => _open = !_open),
            ),
          ),
        ),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : motion.scaled(motion.normal),
          curve: motion.standard,
          child: _open
              ? Padding(
                  padding: EdgeInsets.only(top: context.design.space.xs),
                  child: SelectableText(
                    widget.text,
                    textAlign: TextAlign.center,
                    style: resolved.detailsStyle,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// The one action a status state carries.
class DSStatusAction extends StatelessWidget {
  const DSStatusAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final resolved = DSStatusStyle.resolve(context);
    return DSButton(
      label: label,
      variant: resolved.actionVariant!,
      onPressed: onPressed,
    );
  }
}
