import 'package:flutter/material.dart';

/// One usage of one component, as it would appear inside a real screen.
///
/// A story is deliberately a builder rather than a widget: several of them are
/// stateful (a switch that flips, a tab bar with a controller), and a builder
/// means the gallery can rebuild one story without rebuilding the page.
class DSStory {
  /// What this usage is, in the words someone would search for — "Loading",
  /// "Destructive", "Full width".
  final String title;

  /// The one line a reader needs to choose *this* usage over the one above it.
  /// Not what the widget is; when to reach for this configuration of it.
  final String note;

  final WidgetBuilder builder;

  /// Whether this story's widget owns the page gutter itself.
  ///
  /// A full-bleed component — [DSListTile] and everything built on it, the
  /// headers, the app bars — insets its *content* to `space.pageGutter` and
  /// runs its divider, press highlight and selection fill to the edge. Handed
  /// the story frame's own gutter on top of that, it renders one whole gutter
  /// deeper than the note above it, which is the defect
  /// `test/probe/debt.dart` recorded as the stage paying the gutter twice.
  ///
  /// Null defers to [DSComponentDemo.fullBleed], which is where this is
  /// usually set: whether a component owns its gutter is a fact about the
  /// component, not about one usage of it. Set it here only for the story
  /// that departs from its demo — a full-bleed row shown inside a card.
  final bool? fullBleed;

  const DSStory({
    required this.title,
    required this.note,
    required this.builder,
    this.fullBleed,
  });
}

/// One component, with every usage the gallery knows how to show.
///
/// [summary] is a one-line orientation, not the selection guidance — that
/// lives in `docs/references/design-system-reference-llms.txt`, which is
/// generated from the source and gated by `make check`. Two copies of the same
/// prose would be one copy and one stale copy.
class DSComponentDemo {
  final String name;
  final String summary;
  final List<DSStory> stories;

  /// Whether this component insets its own content to the page gutter.
  ///
  /// The default for every story in [stories]; see [DSStory.fullBleed] for
  /// what it buys and when to override one story of the set.
  final bool fullBleed;

  const DSComponentDemo({
    required this.name,
    required this.summary,
    required this.stories,
    this.fullBleed = false,
  });
}

/// A category of the kit, in the same grouping the generated reference uses —
/// so a component is in the same place in both, and neither has to be read
/// twice.
class DSCatalogCategory {
  final String name;
  final IconData icon;
  final List<DSComponentDemo> components;

  const DSCatalogCategory({
    required this.name,
    required this.icon,
    required this.components,
  });
}
