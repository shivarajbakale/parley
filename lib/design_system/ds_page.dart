// ds-tier: 4 — template

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_ground.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_bottom_insets.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_page_header.dart';
import 'package:parley_android/design_system/ds_section_header.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The rhythm of a page, at every layer of the resolution chain.
///
/// Four gaps and a ground. They are the numbers a screen used to pick for
/// itself: the space above a section, the smaller space above the first one,
/// the space under a section's label, and the space under the last thing on
/// the page. Twenty-seven screens picked them twenty-seven times.
@immutable
class DSPageStyle extends DSComponentStyle<DSPageStyle> {
  const DSPageStyle({
    this.gutter,
    this.headerGap,
    this.sectionGap,
    this.firstSectionGap,
    this.sectionTitleGap,
    this.trailingGap,
    this.background,
  });

  /// How far a page's reading edge stays from the edge of the screen.
  ///
  /// Resolved rather than read straight from the spec so that a page can be
  /// made wider or narrower as a whole — a tablet layout, a dense mode — with
  /// one override instead of an edit at every section.
  final double? gutter;

  /// The space between a header that does *not* scroll and the first thing
  /// under it.
  ///
  /// [DSFormPage]'s number, and the only one of these [DSPage] never needs:
  /// its header is a sliver, so [firstSectionGap] is the gap under it and the
  /// break has already been provided by the header sliding away. A fixed
  /// header ends in a rule, and a field's outline ring set tight under a
  /// hairline reads as part of the header rather than as the first question.
  /// The four screens that built that shape by hand chose `sm`, `md` and `lg`.
  final double? headerGap;

  /// The space above a section, which is what separates it from the one
  /// before it.
  final double? sectionGap;

  /// The space above the *first* section. Smaller: the header above it has
  /// already provided the break that a gap provides between two sections, and
  /// at the full [sectionGap] the page opens on a hole.
  final double? firstSectionGap;

  /// The space between a section's label and its content.
  final double? sectionTitleGap;

  /// The space under the last section, before whatever is pinned to the
  /// bottom of the screen. A list whose last row ends exactly at the action
  /// bar reads as a list that has been cut off.
  final double? trailingGap;

  /// The page's ground. Null takes the scaffold's.
  final Color? background;

  @override
  DSPageStyle merge(DSPageStyle? other) {
    if (other == null) return this;
    return DSPageStyle(
      gutter: other.gutter ?? gutter,
      headerGap: other.headerGap ?? headerGap,
      sectionGap: other.sectionGap ?? sectionGap,
      firstSectionGap: other.firstSectionGap ?? firstSectionGap,
      sectionTitleGap: other.sectionTitleGap ?? sectionTitleGap,
      trailingGap: other.trailingGap ?? trailingGap,
      background: other.background ?? background,
    );
  }

  @override
  DSPageStyle copyWith({
    double? gutter,
    double? headerGap,
    double? sectionGap,
    double? firstSectionGap,
    double? sectionTitleGap,
    double? trailingGap,
    Color? background,
  }) => DSPageStyle(
    gutter: gutter ?? this.gutter,
    headerGap: headerGap ?? this.headerGap,
    sectionGap: sectionGap ?? this.sectionGap,
    firstSectionGap: firstSectionGap ?? this.firstSectionGap,
    sectionTitleGap: sectionTitleGap ?? this.sectionTitleGap,
    trailingGap: trailingGap ?? this.trailingGap,
    background: background ?? this.background,
  );

  @override
  DSPageStyle lerp(DSPageStyle? other, double t) {
    if (other == null) return this;
    return DSPageStyle(
      gutter: lerpDouble(gutter, other.gutter, t),
      headerGap: lerpDouble(headerGap, other.headerGap, t),
      sectionGap: lerpDouble(sectionGap, other.sectionGap, t),
      firstSectionGap: lerpDouble(firstSectionGap, other.firstSectionGap, t),
      sectionTitleGap: lerpDouble(sectionTitleGap, other.sectionTitleGap, t),
      trailingGap: lerpDouble(trailingGap, other.trailingGap, t),
      background: Color.lerp(background, other.background, t),
    );
  }

  static DSPageStyle resolve(BuildContext context, [DSPageStyle? own]) {
    return resolveStyle(
      context: context,
      specDefaults: DSPageStyle(
        gutter: context.design.space.pageGutter,
        headerGap: context.design.space.md,
        sectionGap: context.design.space.xl,
        firstSectionGap: context.design.space.xs,
        sectionTitleGap: context.design.space.md,
        trailingGap: context.design.space.xl,
      ),
      own: own,
    );
  }
}

/// The app's page scaffold: a header, a scroll, and the clearance under both.
///
/// The kit has named this component in its own documentation for months
/// without shipping it. `tool/ui_lint.dart`'s catalog rule, `ui_probe`'s
/// `gutter` rule and the `add-component` skill all say some version of "only
/// [DSPage], `DSFormPage` or `DSGutter` may apply `space.pageGutter`" — while
/// twenty-seven screens spelled the gutter by hand seventy-three times, and
/// ten screens carrying a floating action button or a pinned action bar had no
/// [DSBottomInsetsHost] above them at all, so the bar could not report its
/// height, the content under it was never cleared, and `DSFab.hideOnScroll`
/// read a [DSScrollRetreat] that nothing published.
///
/// What this owns, and what it deliberately does not:
///
///   * **The header.** Which one is still a decision, and it is made by
///     picking a constructor: the default is [DSPageHeader.compactSliver] for
///     a screen whose header is a word, [DSPage.headline] is
///     [DSPageHeader.sliver] for a screen whose header is its own headline.
///     `ui_lint`'s `header-earns-its-height` rule is the sentence that
///     separates them, and this component does not re-litigate it.
///   * **The bottom.** It installs [DSBottomInsetsHost], so the action bar,
///     the navigation bar and the button can see each other, and it ends the
///     scroll with the clearance they add up to. No screen has to know a
///     height.
///   * **Not the gutter.** The page does not pad its slivers, because a list
///     and a card want different things from the same number: [DSPageSection]
///     insets a box, and a row component ([DSListTile]) insets its *content*
///     while its ink runs to the edge. One `EdgeInsets` at the page level
///     cannot be both, and trying was how the audit found reading edges at 16,
///     33 and 48 points on one screen.
///
/// **Use when** a screen is a title over scrolling content — which is nearly
/// every screen. **Instead:** a bare `Scaffold` when the screen has no header
/// and no scroll at all (a splash, a full-bleed player); [DSPage.surface] when
/// it has a header but its body manages its own space.
class DSPage extends StatelessWidget {
  /// The ordinary page: a compact bar carrying one word, over a scroll.
  const DSPage({
    super.key,
    required this.title,
    required this.slivers,
    this.leading,
    this.actions,
    this.floatingAction,
    this.footer,
    this.style,
  }) : eyebrow = null,
       subtitle = null,
       below = null,
       background = null,
       surface = null,
       _headline = false;

  /// The editorial page: the title is the page's own headline, set large and
  /// collapsing as the content passes under it.
  const DSPage.headline({
    super.key,
    required this.title,
    required this.slivers,
    this.eyebrow,
    this.subtitle,
    this.below,
    this.background,
    this.leading,
    this.actions,
    this.floatingAction,
    this.footer,
    this.style,
  }) : surface = null,
       _headline = true;

  /// A page whose body is a single non-scrolling surface that manages its own
  /// space — a map, a camera frame, a canvas. Same header as the scrolling
  /// page; only the body differs.
  const DSPage.surface({
    super.key,
    required this.title,
    required Widget child,
    this.leading,
    this.actions,
    this.floatingAction,
    this.footer,
    this.style,
  }) : surface = child,
       slivers = const <Widget>[],
       eyebrow = null,
       subtitle = null,
       below = null,
       background = null,
       _headline = false;

  final String title;

  /// The small tracked line above an editorial title. [DSPage.headline] only.
  final String? eyebrow;

  /// One supporting line under an editorial title. [DSPage.headline] only.
  final String? subtitle;

  /// Chrome that belongs to the header rather than to the content — a search
  /// field, a tab bar. It stays with the header when the header pins.
  final Widget? below;

  /// A picture behind an editorial header. [DSPage.headline] only.
  final Widget? background;

  /// Replaces the automatic back button. Leave null on a root tab.
  final Widget? leading;

  /// The header's trailing controls. A `DSHeaderActions`, or a single button.
  final Widget? actions;

  /// Page content, as slivers.
  ///
  /// Slivers rather than a box: the page scrolls once, and a page that nests
  /// a `ListView` inside this one takes a second viewport's worth of height
  /// and strands its content above a fixed void.
  final List<Widget> slivers;

  /// Set by [DSPage.surface]; mutually exclusive with [slivers].
  final Widget? surface;

  final Widget? floatingAction;

  /// Pinned below the scroll — a `DSPinnedActionBar` holding the primary
  /// action of a long form. It reports its own height, so the content above
  /// clears it without the screen being told the number.
  final Widget? footer;

  final DSPageStyle? style;

  final bool _headline;

  @override
  Widget build(BuildContext context) {
    final resolved = DSPageStyle.resolve(context, style);

    return DSGround(
      child: DSBottomInsetsHost(
        child: Scaffold(
          backgroundColor: resolved.background,
          // The scroll runs behind the pinned bar, and the trailing clearance
          // below is what stops the last row ending underneath it.
          //
          // The two screens that installed the host before this component
          // existed disagreed about exactly this: `login_page` extended its body
          // and padded by the insets, `form_page` did neither and let the
          // Scaffold cut the body off at the bar's top edge. Cutting it off is
          // the wrong half — a list that stops dead against an opaque band gives
          // the reader no sign anything is behind it, and a bar with any
          // translucency has nothing to blur. A surface page is the exception:
          // its body does not scroll, so passing under the bar would simply hide
          // part of it.
          extendBody: surface == null,
          // Read below the host, so the trailing clearance and anything else in
          // the body sees the heights the bars report. A read taken above it
          // gets the fallback insets and is wrong by exactly the bar it was
          // asking about.
          body: Builder(
            builder: (context) => surface == null
                ? CustomScrollView(
                    slivers: <Widget>[
                      _header(),
                      ...slivers,
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              DSBottomInsets.of(context).scrollClearance +
                              (resolved.trailingGap ?? 0),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: <Widget>[
                      _header(),
                      Expanded(child: surface!),
                    ],
                  ),
          ),
          floatingActionButton: floatingAction,
          bottomNavigationBar: footer,
        ),
      ),
    );
  }

  Widget _header() {
    if (surface != null) {
      return DSPageHeader(
        title: title,
        leading: leading,
        actions: actions,
        below: below,
      );
    }
    if (_headline) {
      return DSPageHeader.sliver(
        title: title,
        eyebrow: eyebrow,
        subtitle: subtitle,
        leading: leading,
        actions: actions,
        below: below,
        background: background,
      );
    }
    return DSPageHeader.compactSliver(
      title: title,
      leading: leading,
      actions: actions,
      below: below,
    );
  }
}

/// One block of box content on a [DSPage]: the page gutter, the gap above it,
/// and — when it has one — its label, aligned to the same gutter as the
/// content beneath.
///
/// This and [DSGutter] are the only two places a page's horizontal inset is
/// spelled. Children must not add their own: a `DSCard` inside one of these
/// takes the full section width, and a card that adds a margin starts one
/// gutter further in than the rows beside it.
///
/// **Use when** a page needs a block of box content — a card, a form, a
/// paragraph, a grid — with or without a label over it. **Instead:**
/// [DSPageSectionHeader] when the body is a sliver rather than a box, because
/// a list inside a `SliverToBoxAdapter` is a list that builds all of itself at
/// once; [DSGutter] when the block needs the inset but not the rhythm.
class DSPageSection extends StatelessWidget {
  const DSPageSection({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.actionLabel,
    this.onAction,
    this.first = false,
    this.style,
  });

  final Widget child;

  /// The section's label, rendered above the content.
  final String? title;

  /// Trailing widget for the label row.
  final Widget? trailing;

  /// A text action on the label row — "See all".
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The first section under the page header takes the smaller gap. See
  /// [DSPageStyle.firstSectionGap].
  final bool first;

  final DSPageStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSPageStyle.resolve(context, style);
    final gutter = resolved.gutter ?? 0;
    final label = title;

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          gutter,
          first ? (resolved.firstSectionGap ?? 0) : (resolved.sectionGap ?? 0),
          gutter,
          0,
        ),
        child: DSGutter.markApplied(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (label != null) ...<Widget>[
                DSSectionHeader(
                  label: label,
                  trailing: trailing,
                  actionLabel: actionLabel,
                  onAction: onAction,
                ),
                SizedBox(height: resolved.sectionTitleGap),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// A section's label on its own, for when its body is a sliver rather than a
/// box.
///
/// Same gutter and same rhythm as [DSPageSection]. It exists because the
/// alternative — putting a `SliverList` inside a [DSPageSection] — needs a
/// `SliverToBoxAdapter`, which builds every row of the list in one pass and
/// gives up the laziness that made it a sliver.
///
/// **Use when** the block under the label is a list. **Instead:**
/// [DSPageSection] when it is a box.
class DSPageSectionHeader extends StatelessWidget {
  const DSPageSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.actionLabel,
    this.onAction,
    this.size = DSSectionHeaderSize.md,
    this.first = false,
    this.style,
  });

  final String title;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;
  final DSSectionHeaderSize size;
  final bool first;
  final DSPageStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSPageStyle.resolve(context, style);
    final gutter = resolved.gutter ?? 0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          gutter,
          first ? (resolved.firstSectionGap ?? 0) : (resolved.sectionGap ?? 0),
          gutter,
          resolved.sectionTitleGap ?? 0,
        ),
        child: DSSectionHeader(
          label: title,
          trailing: trailing,
          actionLabel: actionLabel,
          onAction: onAction,
          size: size,
        ),
      ),
    );
  }
}

/// The page gutter, and nothing else.
///
/// The inset without the rhythm, for the cases [DSPageSection] does not fit:
/// a sliver that has to stay a sliver ([DSGutter.sliver] wraps it in a
/// `SliverPadding`), or a box inside another component that already owns its
/// vertical space.
///
/// **Use when** something needs the page's reading edge and supplies its own
/// vertical rhythm. **Instead:** [DSPageSection], which is this plus the gap
/// above it and the label over it — reach for this one only when that rhythm
/// belongs to something else.
class DSGutter extends StatelessWidget {
  const DSGutter({super.key, required this.child, this.style})
    : _sliver = false;

  /// The sliver form. A `SliverList` keeps its laziness and gets the inset.
  ///
  /// Sliver or box is a placement detail rather than a component, which is the
  /// same call [DSPageHeader] makes for the same reason.
  const DSGutter.sliver({super.key, required Widget sliver, this.style})
    : child = sliver,
      _sliver = true;

  final Widget child;
  final DSPageStyle? style;

  final bool _sliver;

  /// The resolved page gutter, as a number.
  ///
  /// For the one place a widget cannot be wrapped: a scroll view's own
  /// `padding`, which takes an `EdgeInsets` and not a child. Reading it here
  /// rather than from `context.design.space.pageGutter` is what keeps a
  /// [DSPageStyle] override — a wider page on a tablet — true of the scroller
  /// as well as of everything inside it.
  static double of(BuildContext context) =>
      DSPageStyle.resolve(context).gutter ?? 0;

  /// The gutter this widget still has to apply: the page's, or zero when
  /// something above it has already applied one. See [DSGutterScope].
  static double pending(BuildContext context, [DSPageStyle? style]) =>
      DSGutterScope.applied(context)
      ? 0
      : (DSPageStyle.resolve(context, style).gutter ?? 0);

  /// Wraps [child] so everything inside it reads a [pending] gutter of zero.
  static Widget markApplied({required Widget child}) =>
      DSGutterScope(child: child);

  @override
  Widget build(BuildContext context) {
    final resolved = DSPageStyle.resolve(context, style);
    final padding = EdgeInsets.symmetric(horizontal: resolved.gutter ?? 0);
    // The marker goes *outside* the padding in both forms. An
    // `InheritedWidget` builds no render object of its own — it hands its
    // child's up to the parent — so it can wrap a sliver without stopping it
    // being one, and a `SliverPadding` cannot take a box widget between it and
    // its sliver.
    if (_sliver) {
      return DSGutterScope(
        child: SliverPadding(padding: padding, sliver: child),
      );
    }
    return DSGutterScope(
      child: Padding(padding: padding, child: child),
    );
  }
}
