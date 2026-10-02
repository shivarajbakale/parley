// ds-tier: 3 — organism

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_compact_app_bar.dart';
import 'package:parley_android/design_system/ds_large_app_bar.dart';
import 'package:parley_android/design_system/ds_page_header_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_section_header.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The screen's own title, fixed or collapsing.
///
/// See `docs/plans/27-ds-headers.plan.md`. There used to be two components
/// here: this one, whose doc comment claimed to "mirror the visual of the
/// expanded state of DSLargeAppBar", and `DSLargeAppBar`, whose doc comment
/// argued *against* the second line this one rendered. Two components claiming
/// to be the same header, disagreeing about what a header is, each documenting
/// the opposite position — so a screen built on a `TabBarView` looked unlike
/// every other screen, and the difference was nobody's decision.
///
/// Sliver or box is a placement detail, not a component: [DSPageHeader.sliver]
/// is the collapsing form for a `CustomScrollView`, and the default
/// constructor is the fixed one for a screen that cannot host slivers at the
/// top level. The vocabulary — title, eyebrow, actions, `below` — is the same
/// in both.
///
/// **The eyebrow is an editorial device** ("Library" over "Your Collection"),
/// not a breadcrumb and not a status line. That is the answer neither doc
/// comment gave.
///
/// **Use when** the screen needs its own title. **Instead:**
/// [DSSectionHeader] for a section within it.
class DSPageHeader extends StatelessWidget {
  const DSPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.leading,
    this.actions,
    this.below,
    this.background,
    this.titleSlot,
    this.eyebrowSlot,
    this.style,
  }) : _sliver = false,
       _compact = false,
       pinned = true,
       floating = false;

  /// The collapsing form, for the first position in a [CustomScrollView].
  const DSPageHeader.sliver({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.leading,
    this.actions,
    this.below,
    this.background,
    this.titleSlot,
    this.eyebrowSlot,
    this.pinned = true,
    this.floating = false,
    this.style,
  }) : _sliver = true,
       _compact = false;

  /// The other half of the decision: a header for a screen whose header is a
  /// word, not the page's own headline. See [DSCompactAppBar]'s doc comment
  /// for the sentence that decides between the two, and `tool/ui_lint.dart`'s
  /// `header-earns-its-height` rule that checks it.
  const DSPageHeader.compactSliver({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.below,
    this.style,
  }) : eyebrow = null,
       subtitle = null,
       background = null,
       titleSlot = null,
       eyebrowSlot = null,
       pinned = true,
       floating = false,
       _sliver = false,
       _compact = true;

  final String title;
  final String? eyebrow;

  /// One supporting line under the title. See `DSLargeAppBar.subtitle`: the
  /// two components share the vocabulary, and this is the field that lets a
  /// screen's real headline live in the header instead of a duplicate intro
  /// widget underneath it.
  final String? subtitle;
  final Widget? leading;
  final Widget? actions;

  /// Pinned under the title and above the content — a search bar, a tab bar, a
  /// segmented control.
  ///
  /// This is the slot the `TabBarView` case actually needed, and the reason
  /// this component was forked from the app bar in the first place.
  final Widget? below;

  final Widget? background;
  final Widget? titleSlot;
  final Widget? eyebrowSlot;
  final bool pinned;
  final bool floating;
  final DSPageHeaderStyle? style;

  final bool _sliver;
  final bool _compact;

  @override
  Widget build(BuildContext context) {
    if (_compact) {
      return DSCompactAppBar(
        title: title,
        leading: leading,
        actions: actions == null ? null : [actions!],
        below: below,
        style: style,
      );
    }

    if (_sliver) {
      return DSLargeAppBar(
        title: title,
        eyebrow: eyebrow,
        subtitle: subtitle,
        leading: leading,
        actions: actions == null ? null : [actions!],
        below: below,
        background: background,
        pinned: pinned,
        floating: floating,
        style: style,
      );
    }

    final resolved = DSPageHeaderStyle.resolve(context, style);
    final component = context.design.component;

    return Material(
      color: resolved.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: resolved.toolbarHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: component.leadingSlotSize,
                    child: leading ?? const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  if (actions != null) actions!,
                ],
              ),
            ),
            Padding(
              padding: resolved.padding!,
              // The eyebrow and the title are one node: a screen reader says
              // "Your Collection, Library" as one heading rather than reading
              // a stray uppercase word and then the title.
              child: MergeSemantics(
                child: Semantics(
                  header: true,
                  namesRoute: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrowSlot != null)
                        eyebrowSlot!
                      else if (eyebrow != null) ...[
                        Text(
                          AppTypography.eyebrowCase(context, eyebrow!),
                          style: resolved.eyebrowStyle,
                        ),
                        SizedBox(height: context.design.space.xs),
                      ],
                      titleSlot ??
                          DSText(
                            title,
                            role: DSTextRole.pageTitle,
                            maxLines: 2,
                            style: DSTextStyle(
                              textStyle: resolved.titleStyle,
                              color: resolved.titleColor,
                            ),
                          ),
                      if (subtitle != null) ...[
                        SizedBox(height: context.design.space.xs),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: resolved.subtitleStyle,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (below != null) below!,
          ],
        ),
      ),
    );
  }
}

/// The toolbar's action group, at the small size a toolbar wants.
class DSHeaderActions extends StatelessWidget {
  const DSHeaderActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DSScope.merge(
    context,
    size: DSSize.sm,
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );
}

/// A section header and the content under it.
///
/// Replaces `DSContentSection`, which had two defects of the same kind: it
/// appended a trailing `xl` gap *below* itself, so a section followed by
/// anything produced a gap the caller never asked for and could not remove;
/// and its default content padding was four points, which is neither the
/// gutter nor zero, so section content sat four points inside everything else
/// on the page. A component owns the space inside it, never the space after
/// it — the same rule the page gutter has a lint for.
class DSSection extends StatelessWidget {
  const DSSection({
    super.key,
    required this.label,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.contentPadding,
    this.size = DSSectionHeaderSize.md,
  });

  final String label;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  /// Zero by default, so the content lines up with everything else on the page
  /// rather than four points inside it.
  final EdgeInsetsGeometry? contentPadding;

  final DSSectionHeaderSize size;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      DSSectionHeader(
        label: label,
        actionLabel: actionLabel,
        onAction: onAction,
        trailing: trailing,
        size: size,
      ),
      Padding(padding: contentPadding ?? EdgeInsets.zero, child: child),
    ],
  );
}
