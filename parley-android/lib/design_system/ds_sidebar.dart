// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_badge.dart';
import 'package:parley_android/design_system/ds_bottom_nav_bar.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_divider.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/design_system/ds_well.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How the sidebar looks, at every layer of the chain.
@immutable
class DSSidebarStyle extends DSComponentStyle<DSSidebarStyle> {
  const DSSidebarStyle({
    this.width,
    this.rowHeight,
    this.headerPadding,
    this.selectedFill,
    this.gap,
  });

  final double? width;
  final double? rowHeight;
  final EdgeInsetsGeometry? headerPadding;
  final Color? selectedFill;
  final double? gap;

  @override
  DSSidebarStyle merge(DSSidebarStyle? other) {
    if (other == null) return this;
    return DSSidebarStyle(
      width: other.width ?? width,
      rowHeight: other.rowHeight ?? rowHeight,
      headerPadding: other.headerPadding ?? headerPadding,
      selectedFill: other.selectedFill ?? selectedFill,
      gap: other.gap ?? gap,
    );
  }

  @override
  DSSidebarStyle copyWith({
    double? width,
    double? rowHeight,
    EdgeInsetsGeometry? headerPadding,
    Color? selectedFill,
    double? gap,
  }) => DSSidebarStyle(
    width: width ?? this.width,
    rowHeight: rowHeight ?? this.rowHeight,
    headerPadding: headerPadding ?? this.headerPadding,
    selectedFill: selectedFill ?? this.selectedFill,
    gap: gap ?? this.gap,
  );

  @override
  DSSidebarStyle lerp(DSSidebarStyle? other, double t) {
    if (other == null) return this;
    return DSSidebarStyle(
      width: lerpDouble(width, other.width, t),
      rowHeight: lerpDouble(rowHeight, other.rowHeight, t),
      headerPadding: EdgeInsetsGeometry.lerp(
        headerPadding,
        other.headerPadding,
        t,
      ),
      selectedFill: Color.lerp(selectedFill, other.selectedFill, t),
      gap: lerpDouble(gap, other.gap, t),
    );
  }

  static DSSidebarStyle resolve(BuildContext context, {DSSidebarStyle? own}) {
    final design = context.design;
    return resolveStyle(
      context: context,
      specDefaults: DSSidebarStyle(
        width: design.component.sidebarWidth,
        rowHeight: design.component.minTapTarget,
        headerPadding: EdgeInsets.all(design.space.md),
        selectedFill: context.palette.secondary,
        gap: design.space.sm,
      ),
      own: own,
    );
  }
}

/// The app's navigation drawer, built on Material 3's [NavigationDrawer].
///
/// A thin wrapper, not a re-implementation. `Scaffold(drawer: DSSidebar(...))`
/// already gives you the edge-swipe-to-open gesture, the animated scrim,
/// swipe-to-dismiss, focus trapping, the back-button dismiss, and the correct
/// semantics on both platforms — all of which a hand-rolled sliding panel has
/// to rebuild and keep correct forever.
///
/// It takes [DSBottomNavItem], the same destination model
/// `DSBottomNavBar` takes (`docs/plans/31-ds-compositions.plan.md`).
/// `DSSidebarDestination` was a second model for the same idea, so an adaptive
/// layout that shows a bar on a phone and a drawer on a tablet had to write
/// its destinations twice and keep the two lists in step. A destination is a
/// destination: write them once, hand them to whichever component the width
/// selects.
///
/// ```dart
/// Scaffold(
///   drawer: DSSidebar(
///     header: const DSSidebarHeader(title: 'Rocketship'),
///     selectedIndex: index,
///     onDestinationSelected: (i) { Navigator.pop(context); switchTab(i); },
///     destinations: destinations,   // the same list the nav bar gets
///   ),
///   body: ...,
/// )
/// ```
class DSSidebar extends StatelessWidget {
  const DSSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.header,
    this.footer,
    this.style,
  }) : assert(
         destinations.length >= 2 && destinations.length <= 12,
         'a sidebar carries 2 to 12 destinations. One is not a choice, and '
         'past a dozen the list is a menu — which is a screen, not a drawer.',
       );

  /// The same objects [DSBottomNavBar] takes.
  final List<DSBottomNavItem> destinations;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Rendered above the destinations — typically a [DSSidebarHeader].
  final Widget? header;

  /// Rendered below the destinations, pinned to the bottom of the drawer.
  final Widget? footer;

  final DSSidebarStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSSidebarStyle.resolve(context, own: style);
    final design = context.design;

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (!destinations[index].enabled) return;
        onDestinationSelected(index);
      },
      indicatorColor: resolved.selectedFill,
      // The list scrolls. Twelve destinations, a header and a footer do not
      // fit a phone in landscape, and the previous column clipped them
      // silently — the one failure mode a drawer has no way to report.
      children: [
        if (header != null) header!,
        for (final destination in destinations)
          NavigationDrawerDestination(
            enabled: destination.enabled,
            icon: destination.iconSlot ?? Icon(destination.icon),
            selectedIcon:
                destination.iconSlot ??
                Icon(destination.selectedIcon ?? destination.icon),
            label: Row(
              // Shrink-wrapped: Material lays the label out under unbounded
              // width constraints, and a flexible child there asserts.
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(destination.label)),
                if (destination.hasBadge) ...[
                  SizedBox(width: resolved.gap),
                  destination.badgeSlot ??
                      (destination.badgeCount != null
                          ? DSDot(count: destination.badgeCount)
                          : const DSDot()),
                ],
              ],
            ),
          ),
        if (footer != null) ...[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: design.space.xl,
              vertical: design.space.sm,
            ),
            child: const DSDivider(),
          ),
          footer!,
        ],
      ],
    );
  }
}

/// Brand header for [DSSidebar] — mark, wordmark, and an optional caption.
///
/// The mark is a [DSWell], not a hand-built circle: a tinted container behind
/// a glyph is one idea, and this file used to be one of the four places that
/// drew it at its own size and its own alpha.
class DSSidebarHeader extends StatelessWidget {
  const DSSidebarHeader({
    super.key,
    required this.title,
    this.caption,
    this.icon = Icons.rocket_launch_rounded,
    this.leading,
  });

  final String title;
  final String? caption;
  final IconData icon;

  /// Replaces the mark — a logo, an avatar, a team's monogram.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final design = context.design;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        design.space.xl,
        design.space.xl,
        design.space.lg,
        design.space.lg,
      ),
      child: Row(
        children: [
          leading ?? DSWell(icon: icon, size: DSWellSize.lg),
          SizedBox(width: design.space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DSTextRole.sectionTitle.styleOf(context)),
                if (caption != null)
                  Text(caption!, style: DSTextRole.caption.styleOf(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
