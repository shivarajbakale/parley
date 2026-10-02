// ds-tier: 2 — molecule

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;
import 'package:parley_android/design_system/ds_page_header_style.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/theme/app_materials.dart';
import 'package:parley_android/theme/app_platform.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Editorial large-title app bar for top-level pages.
///
/// The collapsing half of [DSPageHeader]: `DSPageHeader.sliver` is the name to
/// use, and this is the implementation it builds. The two are kept as one
/// vocabulary — title, eyebrow, actions, `below` — because the kit previously
/// shipped two components that each claimed to be the page's header and
/// disagreed in their own doc comments about what one is.
///
/// This is where the two platforms genuinely diverge, so the widget does too:
///
/// - **Android** — [SliverAppBar.large], Material's own collapsing large-title
///   bar, on a tonal chrome surface. It already handles the scroll-under
///   transition, the pinned collapsed state and the title's semantics, and
///   re-implementing that would be a hand-roll of exactly the kind `ui_lint`
///   exists to stop.
/// - **Apple** — a glass bar. `SliverAppBar.large` builds its own
///   `flexibleSpace` and only when the caller passes none, so a glass surface
///   there means supplying the `flexibleSpace`, which means supplying the
///   collapsing title too. [FlexibleSpaceBar] is Material's own machinery for
///   that, and the collapse it produces — large title shrinking to the bar —
///   is the iOS behaviour anyway.
///
/// Both branches change chrome, not structure: same title, same actions, same
/// sliver contract. See `docs/principles/platform-adaptivity.md`. An eyebrow
/// is the one thing that moves both branches onto the flexible-space path,
/// because Material's large bar renders its own title and has nowhere to put a
/// line above it.
///
/// Use as the first sliver inside a [CustomScrollView]:
/// ```dart
/// CustomScrollView(
///   slivers: [
///     const DSPageHeader.sliver(title: 'Library'),
///     // … other slivers
///   ],
/// )
/// ```
///
/// Section labels belong *in* the content (see `DSSectionHeader`), not stacked
/// under the title — a second header line below a large title reads as chrome
/// and costs a row of the first screenful. An [eyebrow] is the exception the
/// plan makes for the editorial case, and the reference entry says what it is
/// for.
class DSLargeAppBar extends StatelessWidget {
  final String title;

  /// How many lines the expanded title may use before it is cut.
  ///
  /// One for a page whose title is a *name* — "Library", "Settings" — which is
  /// every top-level destination. Two for a page whose title is *content*: an
  /// article, a post, a thread. A 60-character headline set on one line is
  /// ellipsised at the width of a phone, and an ellipsised headline is the
  /// defect the `clipped-text` probe rule fails, not a layout that fits.
  ///
  /// The bar grows by a line to hold it, and by another for an [eyebrow], so
  /// neither is drawn through the leading button. Bounded at 2: a third line
  /// of title is an article's opening paragraph wearing the bar's type.
  final int titleMaxLines;

  final String? eyebrow;

  /// One supporting line under the title.
  ///
  /// This is the sentence a screen used to render in an intro widget directly
  /// below the bar — which meant the page had two headline levels, the bar's
  /// and the content's, and neither was clearly the page's name. Bounded at
  /// two lines: a third is a paragraph, and the page has a body for that.
  final String? subtitle;

  final Widget? leading;
  final List<Widget>? actions;

  /// Pinned under the title: a tab bar, a search bar, a segmented control.
  final Widget? below;

  final Widget? background;
  final bool pinned;
  final bool floating;
  final DSPageHeaderStyle? style;

  const DSLargeAppBar({
    super.key,
    required this.title,
    this.titleMaxLines = 1,
    this.eyebrow,
    this.subtitle,
    this.leading,
    this.actions,
    this.below,
    this.background,
    this.pinned = true,
    this.floating = false,
    this.style,
  }) : assert(
         titleMaxLines >= 1 && titleMaxLines <= 2,
         'One line for a name, two for a headline. A third is a paragraph in '
         'the bar\'s type, and the page has a body for that.',
       );

  /// How tall the expanded bar has to be to hold what is in it.
  ///
  /// The spec's `headerExpandedHeight` is the floor, not the answer.
  /// [FlexibleSpaceBar] anchors its title block to the bottom of the bar and
  /// scales it by [_expandedTitleScale], so the block's painted height is a
  /// fact about the string, the width and the text scale — and whatever is
  /// left above it is the room the leading button has. A block taller than
  /// that remainder is drawn *through* the button, which is how a back chevron
  /// came to sit across an eyebrow.
  ///
  /// Measured with a [TextPainter] at the width `FlexibleSpaceBar` will use
  /// (the bar's width less the title padding, divided by the scale), so the
  /// number of lines counted here is the number painted rather than an
  /// assumption that a title fits on one.
  double _expandedHeight(
    BuildContext context,
    DSPageHeaderStyle resolved,
    double width,
  ) {
    final space = context.design.space;
    final scaler = MediaQuery.textScalerOf(context);
    final double layoutWidth = math.max(
      48,
      (width - space.pageGutter * 2) / _expandedTitleScale,
    );

    double block(String text, TextStyle? style, int maxLines) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: maxLines,
        ellipsis: '\u2026',
      )..layout(maxWidth: layoutWidth);
      final double height = painter.height;
      painter.dispose();
      return height;
    }

    // The style the title is *painted* in, which is the whole point of a
    // measurement. This read `theme.textTheme.titleLarge` — the style
    // FlexibleSpaceBar installs on whatever it is handed — and that was true
    // for exactly as long as the title was a bare `Text` accepting it. The
    // moment the title took `resolved.titleStyle`, the bar was reserving room
    // for a 20.4pt block and painting a 24.4pt one, so at a doubled text
    // scale a two-line title lost its last word to an ellipsis in a box that
    // was never asked to hold it.
    double content = block(title, resolved.titleStyle, titleMaxLines);
    if (eyebrow != null) {
      content += block(
        AppTypography.eyebrowCase(context, eyebrow!),
        resolved.eyebrowStyle,
        1,
      );
    }
    if (subtitle != null) {
      content += space.xs + block(subtitle!, resolved.subtitleStyle, 2);
    }
    content = content * _expandedTitleScale + space.md;

    return math.max(
      resolved.expandedHeight ?? 0,
      (resolved.toolbarHeight ?? kToolbarHeight) + content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSPageHeaderStyle.resolve(context, style);
    final space = context.design.space;
    final component = context.design.component;
    final material = AppMaterials.chrome(context);
    // Whether anything will occupy the start of the bar. Not the same
    // question as `leading != null`: [SliverAppBar] implies a leading button
    // by itself — a [DrawerButton] when the enclosing [Scaffold] has a drawer,
    // otherwise a back button on any route that can be popped. Either way a
    // screen that passes no leading still has one, and the title has to travel
    // out of its way exactly as if it had been passed in. Reading `leading`
    // alone drew the collapsed title straight through that button.
    final hasLeading =
        leading != null ||
        (Scaffold.maybeOf(context)?.hasDrawer ?? false) ||
        (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);

    final PreferredSizeWidget? bottom = below == null
        ? null
        : PreferredSize(
            preferredSize: Size.fromHeight(component.tabHeight),
            child: below!,
          );

    // The page's title is the route's accessible name. Neither header
    // component set one, so a screen reader announced every route by its
    // first focusable control.
    // `namesRoute` only: the heading comes with [DSTextRole.pageTitle], and
    // setting it here too nested one header inside another.
    //
    // The role is what this title was missing. It used to be a bare `Text`,
    // so it took `AppBarTheme.titleTextStyle` — Material's `titleLarge`,
    // 20.4pt with no emphasis — while the third branch of [DSPageHeader],
    // the fixed header, drew the same string from `resolved.titleStyle` at
    // 24.4pt with the emphasis weight. One component, one string, two sizes,
    // and a `DSPageHeaderStyle(titleStyle:)` override that reached one of
    // them.
    final Widget titleText = Semantics(
      namesRoute: true,
      child: DSText(
        title,
        role: DSTextRole.pageTitle,
        maxLines: titleMaxLines,
        style: DSTextStyle(
          textStyle: resolved.titleStyle,
          color: resolved.titleColor,
        ),
      ),
    );

    if (!AppPlatform.isApple(context) &&
        eyebrow == null &&
        subtitle == null &&
        titleMaxLines == 1) {
      return SliverAppBar.large(
        pinned: pinned,
        floating: floating,
        expandedHeight: resolved.expandedHeight,
        // Transparent until something is under it. A bar that paints its
        // chrome at rest draws a band across the top of a page that has not
        // been scrolled — a header's worth of tinted surface holding one word,
        // which
        // is the single largest block of a first screenful and reads as empty
        // space rather than as chrome. Material resolves this against
        // `scrolledUnder`, which is the same signal it uses for the elevation
        // it would otherwise apply.
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? material.tint
              : Colors.transparent,
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: leading,
        actions: actions,
        bottom: bottom,
        // Material's own large bar insets its expanded title by 16
        // (`_LargeScrollUnderFlexibleConfig.expandedTitlePadding`), which is
        // its default gutter and not necessarily this app's. Left alone, every
        // Android screen drew its large title eight points left of the content
        // under it — the `gutter` probe rule found it on every screen at once.
        // The remainder is added here rather than by restyling the bar,
        // because the rest of that config is Material's contract and this is
        // the only number in it that belongs to the page.
        title: Padding(
          padding: EdgeInsetsDirectional.only(
            start: math.max(0, space.pageGutter - _materialTitleInset),
          ),
          child: titleText,
        ),
      );
    }

    // Measured, not assumed. `FlexibleSpaceBar` lays its title out at the
    // bar's width divided by `expandedTitleScale` and then scales the result
    // up, anchoring it to the bottom — so the block's painted height is a fact
    // about the string, the width and the text scale, and the spec's floor
    // was only ever enough for one short line. An eyebrow, a second title line or a
    // 1.3x text scale each pushed the block up through the leading button,
    // which is how a back chevron came to be drawn across the word
    // ENGINEERING. `SliverLayoutBuilder` is what makes the width knowable
    // here: a sliver has no width until it is laid out.
    return SliverLayoutBuilder(
      builder: (BuildContext context, SliverConstraints constraints) => _bar(
        context,
        resolved,
        constraints.crossAxisExtent,
        hasLeading,
        bottom,
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    DSPageHeaderStyle resolved,
    double width,
    bool hasLeading,
    PreferredSizeWidget? bottom,
  ) {
    final space = context.design.space;
    final material = AppMaterials.chrome(context);

    // Built per frame rather than once, because how many lines the title may
    // take is a function of how far the bar has collapsed. The box the title
    // shrinks into is one toolbar row: a title still asking for two lines
    // there overflows it, and the second line is the one the collapse was
    // always going to take. It goes at the same 40% mark the eyebrow and the
    // subtitle fade on, so the block loses its lines in one movement.
    Widget titleTextIn(BuildContext context) => Semantics(
      namesRoute: true,
      child: DSText(
        title,
        role: DSTextRole.pageTitle,
        maxLines: _collapseOf(context) >= 0.4 ? 1 : titleMaxLines,
        style: DSTextStyle(
          textStyle: resolved.titleStyle,
          color: resolved.titleColor,
        ),
      ),
    );

    return SliverAppBar(
      pinned: pinned,
      floating: floating,
      expandedHeight: _expandedHeight(context, resolved, width),
      backgroundColor: AppPlatform.isApple(context)
          ? Colors.transparent
          : WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.scrolledUnder)
                  ? material.tint
                  : Colors.transparent,
            ),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      actions: actions,
      bottom: bottom,
      // A Builder so the settings the SliverAppBar hands its flexible space
      // are readable here: FlexibleSpaceBarSettings carries the current and
      // maximum extent, which is the only way to know how far collapsed the
      // bar is at build time.
      flexibleSpace: Builder(
        builder: (context) => _GlassBehindTitle(
          // The glass fades in as the bar collapses, and is not built at all
          // while the bar is fully open. A bar that paints its material at
          // rest draws a band across the top of an unscrolled page — a
          // header's worth of tinted surface holding one word, the largest
          // single block of the first screenful, and it reads as empty space
          // rather than as chrome. Glass has something to composite only once
          // content is behind it; before that it is a tint with a story.
          collapse: AppPlatform.isApple(context) ? _collapseOf(context) : 0,
          material: material,
          child: FlexibleSpaceBar(
            background: background,
            // Explicit, because the default (1.5) is a size decision and this
            // bar has one. See [_expandedTitleScale] — the same constant the
            // expanded-height measurement uses, so the two cannot drift.
            expandedTitleScale: _expandedTitleScale,
            // Explicitly not centred. FlexibleSpaceBar takes its default from
            // the AppBar theme, which centres titles on iOS — correct for a
            // compact bar and wrong for a large one, where the whole point is a
            // title that starts on the content's left edge and shrinks into the
            // bar. Left unset, the Apple branch centres the large title and the
            // Material branch does not, which is a difference in structure
            // rather than in chrome.
            centerTitle: false,
            // Flush with the page gutter when expanded, so the large title
            // sits on the same vertical line as the content under it — and
            // travelling to the leading's width as it collapses, so it does
            // not end up drawn over the back button. Material's own large bar
            // gets this for free by rendering two titles and cross-fading
            // them; the glass branch has to supply its own flexible space, so
            // it has to supply this too.
            titlePadding: EdgeInsetsDirectional.only(
              // `pageGutter`, not `space.lg`: the large title is the top of
              // the page's text column, so it starts where the column starts.
              // Read as its own step, the two drifted apart the moment the
              // gutter changed, and the title sat eight points right of every
              // word under it.
              start: !hasLeading
                  ? space.pageGutter
                  : lerpDouble(
                      space.pageGutter,
                      resolved.collapsedTitleStart!,
                      _collapseOf(context),
                    )!,
              bottom: space.md,
            ),
            title: (eyebrow == null && subtitle == null)
                ? titleTextIn(context)
                : MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The eyebrow goes early. A two-line title collapsing
                        // into a one-line bar has to lose a line somewhere,
                        // and losing it in the first 40% of the travel is less
                        // distracting than losing it at the end.
                        if (eyebrow != null)
                          _FadingLine(
                            t: (1 - _collapseOf(context) / 0.4).clamp(0, 1),
                            child: Text(
                              AppTypography.eyebrowCase(context, eyebrow!),
                              style: resolved.eyebrowStyle,
                            ),
                          ),
                        titleTextIn(context),
                        // And the subtitle goes with it, for the same reason
                        // and on the same curve: the collapsed bar is one
                        // line, and what it keeps is the title.
                        if (subtitle != null)
                          _FadingLine(
                            t: (1 - _collapseOf(context) / 0.4).clamp(0, 1),
                            child: Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: resolved.subtitleStyle,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// A line of the title block that gives its height back as it fades.
///
/// [Opacity] alone kept the row's height, so a collapsing bar carried an
/// invisible eyebrow and subtitle into a box one toolbar tall and the column
/// overflowed it by the height of everything it was no longer painting. The
/// height factor releases exactly the space the fade stopped using, on the
/// same curve, so the block shrinks into the bar rather than being clipped by
/// it.
class _FadingLine extends StatelessWidget {
  const _FadingLine({required this.t, required this.child});

  /// 1 when the line is fully painted, 0 when it is gone.
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.topStart,
      heightFactor: t,
      child: Opacity(opacity: t, child: child),
    );
  }
}

/// What Material's own large app bar insets its expanded title by, from
/// `_LargeScrollUnderFlexibleConfig.expandedTitlePadding` in `app_bar.dart`.
/// Private there, so it is named here and used in one place.
const double _materialTitleInset = 16;

/// How much bigger the expanded large title is than the collapsed one.
///
/// [FlexibleSpaceBar.expandedTitleScale] defaults to 1.5, and this bar used to
/// take it. That put the expanded title at 1.5x `titleLarge` — 33pt — which is
/// two steps above the largest headline any screen body uses, for a word the
/// user already knows because they tapped the tab that says it. It is passed
/// explicitly now, at 1.25, so the open bar costs the first screenful a line
/// rather than a block.
///
/// This is also the number that lands the two platform branches on the same
/// size. Material's `SliverAppBar.large` sets its own expanded style rather
/// than scaling, so the glass branch is the only one with a scale to choose;
/// at 1.25 it lands within a point of what Material renders.
///
/// The title is laid out at the bar's width divided by this and painted at
/// this multiple of the result, so it is in the height maths twice — see
/// [DSLargeAppBar._expandedHeight].
const double _expandedTitleScale = 1.25;

/// The bar's material, faded in behind [child] by how far the bar has closed.
///
/// Separate from the title so the title never fades with it: a large title at
/// 30% opacity on the way down is the failure this arrangement avoids.
class _GlassBehindTitle extends StatelessWidget {
  const _GlassBehindTitle({
    required this.collapse,
    required this.material,
    required this.child,
  });

  final double collapse;
  final AppMaterial material;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (collapse <= 0) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Opacity(
            opacity: collapse,
            child: AppChromeSurface(
              shape: AppShape.bar,
              material: material,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// How far the enclosing [SliverAppBar] is collapsed, 0 (expanded) to 1.
///
/// Returns 0 when there are no settings to read, which is the case in a plain
/// widget test that builds the bar outside a scroll view — the expanded value
/// is the safe one to be wrong about.
double _collapseOf(BuildContext context) {
  final settings = context
      .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
  if (settings == null) return 0;
  final travel = settings.maxExtent - settings.minExtent;
  if (travel <= 0) return 0;
  return (1 - (settings.currentExtent - settings.minExtent) / travel).clamp(
    0.0,
    1.0,
  );
}
