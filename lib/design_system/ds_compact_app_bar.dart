// ds-tier: 2 — molecule

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_page_header_style.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/theme/app_materials.dart';
import 'package:parley_android/theme/app_platform.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The navigation-bar half of [DSPageHeader]: `DSPageHeader.compactSliver` is
/// the name to use, and this is what it builds.
///
/// Its own file rather than a constructor on `DSLargeAppBar`, because "large
/// app bar, compact" is the contradiction that produced two competing header
/// components the last time. The two forms share a vocabulary — title,
/// leading, actions, `below` — and differ in exactly one thing: whether the
/// bar carries the page's headline or the nav bar's label.
///
/// **Use when** the header has nothing to say beyond the screen's name.
/// **Instead:** [DSLargeAppBar] when the header carries the page's own
/// headline — a subtitle, an eyebrow, a tab strip. `tool/ui_lint.dart`'s
/// `header-earns-its-height` rule is that sentence as a gate.
class DSCompactAppBar extends StatelessWidget {
  const DSCompactAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.below,
    this.style,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  /// Pinned under the title: a tab bar, a segmented control. Fixed at
  /// `component.tabHeight`, same as the large bar's.
  final Widget? below;

  final DSPageHeaderStyle? style;

  @override
  Widget build(BuildContext context) {
    // Whether content is behind the bar is a fact about this sliver's own
    // geometry, and `SliverLayoutBuilder` is what makes it readable: a pinned
    // sliver at a nonzero scroll offset, or one a preceding sliver overlaps,
    // has content under it. It is the same question `SliverAppBar` answers for
    // its own `WidgetState.scrolledUnder`, asked the same way.
    //
    // Not `ScrollNotificationObserver`. That is what Material's `AppBar` uses,
    // and it was the first implementation here — but the observer the enclosing
    // `Scaffold` installs sits above the app shell's `PageView`, so a page's
    // own scroll notification bubbles through the PageView's viewport and
    // arrives at a nonzero depth. `defaultScrollNotificationPredicate`
    // discards it, and every top-level destination rendered its header
    // transparent forever with the hero card sliding through the title.
    return SliverLayoutBuilder(
      builder: (context, constraints) => _bar(
        context,
        scrolledUnder: constraints.scrollOffset > 0 || constraints.overlap > 0,
      ),
    );
  }

  Widget _bar(BuildContext context, {required bool scrolledUnder}) {
    final resolved = DSPageHeaderStyle.resolve(context, style);
    final space = context.design.space;
    final component = context.design.component;
    final material = AppMaterials.chrome(context);

    // Not the same question as `leading != null`: SliverAppBar implies a
    // leading button by itself — a DrawerButton when the enclosing Scaffold
    // has a drawer, otherwise a back button on any route that can be popped.
    final hasLeading =
        leading != null ||
        (Scaffold.maybeOf(context)?.hasDrawer ?? false) ||
        (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);

    // The same line the large bar's collapsed title lands on, so a push from
    // an expanded header to a compact one does not move the title sideways.
    final double titleStart = hasLeading
        ? math.max(0, resolved.collapsedTitleStart! - component.leadingSlotSize)
        : space.pageGutter;

    return SliverAppBar(
      pinned: true,
      toolbarHeight: resolved.compactHeight!,
      leading: leading,
      leadingWidth: component.leadingSlotSize,
      // Zero, because the inset is computed above against the same token the
      // large bar uses. Left to AppBar's default the two headers would put
      // their titles on different vertical lines.
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsetsDirectional.only(start: titleStart),
        // `namesRoute` only: the heading is [DSTextRole.screenTitle]'s own,
        // and setting it here as well nested one header inside another.
        //
        // The role carries the one line, the ellipsis and the scale ceiling;
        // the step comes from the style, because a toolbar title is a smaller
        // number than the page title the other two branches draw. It used to
        // be a bare `Text` taking `AppBarTheme.titleTextStyle`, which is the
        // same step but reachable only by restyling Material's bar for the
        // whole app.
        child: Semantics(
          namesRoute: true,
          child: DSText(
            title,
            role: DSTextRole.screenTitle,
            style: DSTextStyle(textStyle: resolved.compactTitleStyle),
          ),
        ),
      ),
      actions: actions,
      bottom: below == null
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(component.tabHeight),
              child: below!,
            ),
      // Transparent until something is under it — the same rule the large bar
      // follows. A bar that paints its chrome at rest draws a band across the
      // top of an unscrolled page.
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
      flexibleSpace: AppPlatform.isApple(context)
          ? _GlassWhenScrolledUnder(
              material: material,
              scrolledUnder: scrolledUnder,
            )
          : null,
    );
  }
}

/// The Apple branch's glass, faded in once content is behind the bar.
///
/// It cannot reuse the large bar's `_GlassBehindTitle`: that fade is driven by
/// how far the bar has collapsed, and a bar with no expanded height has no
/// travel to read — the collapse is 0 forever. The signal here is the sliver's
/// own scroll geometry, read by the `SliverLayoutBuilder` above.
class _GlassWhenScrolledUnder extends StatelessWidget {
  const _GlassWhenScrolledUnder({
    required this.material,
    required this.scrolledUnder,
  });

  final AppMaterial material;
  final bool scrolledUnder;

  @override
  Widget build(BuildContext context) {
    final motion = context.design.motion;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: scrolledUnder ? 1 : 0,
        duration: motion.scaled(motion.fast),
        curve: motion.standard,
        child: AppChromeSurface(
          shape: AppShape.bar,
          material: material,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
