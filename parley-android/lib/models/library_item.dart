// ui-lint: allow model-imports-flutter — the icon map is IconData keyed by a JSON-safe string, deliberately, so an
// icon survives serialisation and a deep link. No widget, no binding.
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'library_item.freezed.dart';
part 'library_item.g.dart';

/// The one demo domain model, and the boilerplate's worked example of a
/// freezed + json_serializable DTO: immutable, with `copyWith`, value
/// equality, and JSON in/out generated for free. Copy this shape for your own
/// API models, then run `make gen`.
///
/// The same model is served by the mock backend (`/api/library`), decoded by
/// [LibraryRepository], rendered by the Library tab, and re-read by the detail
/// route — so one model demonstrates the whole vertical slice instead of a
/// scatter of unrelated toy examples.
///
/// (Hand-written models like `AppSettings` are still fine for trivial cases;
/// reach for freezed when a model has several fields or needs JSON.)
@freezed
abstract class LibraryItem with _$LibraryItem {
  const LibraryItem._();

  const factory LibraryItem({
    required String id,
    required String title,
    required String subtitle,

    /// A longer blurb shown on the detail screen.
    required String detail,

    /// Icon *key*, not an [IconData] — icons have to survive JSON and a deep
    /// link, and a codepoint is neither stable nor tree-shakeable. Resolved
    /// through [libraryIcons] by [icon].
    @Default('star') String iconName,

    /// Which shelf this belongs to. The Library's filter strip is built from
    /// the distinct values present in the data, so adding a category is a
    /// data change and not a screen change.
    @Default('Guides') String category,

    /// How long the guide takes to read, in minutes.
    ///
    /// Defaulted rather than required: a backend that does not send it still
    /// decodes, and the detail screen says "Length not recorded" instead of
    /// drawing a zero as though it were a fact.
    @Default(0) int minutes,

    /// How far this reader has got, 0 to 1.
    ///
    /// The reader's own state rather than the item's, and it lives here for
    /// the same reason the demo has one model: a template that splits the
    /// subject from the reader's place in it needs two repositories to show
    /// one screen. A real app with a separate progress service reads it into
    /// the same field.
    @Default(0) double progress,
  }) = _LibraryItem;

  factory LibraryItem.fromJson(Map<String, dynamic> json) =>
      _$LibraryItemFromJson(json);

  /// The resolved icon for [iconName], falling back to a neutral glyph so an
  /// unknown key from the backend degrades instead of crashing.
  IconData get icon => libraryIcons[iconName] ?? Icons.star_outline;
}

/// The icon keys the backend may send. Keeping the set explicit (rather than
/// looking codepoints up dynamically) is what lets Flutter tree-shake icons.
const libraryIcons = <String, IconData>{
  'rocket': Icons.rocket_launch_outlined,
  'palette': Icons.palette_outlined,
  'lock': Icons.lock_outline,
  'insights': Icons.insights_outlined,
  'layers': Icons.view_agenda_outlined,
  'vibration': Icons.vibration_outlined,
  'star': Icons.star_outline,
};

/// The seed contents of the demo Library. The mock backend serves these over
/// `/api/library`, and the detail route (`/library/detail/:index`) indexes into
/// them so a cold-start deep link still renders. Replace with your own domain.
const demoLibraryItems = <LibraryItem>[
  LibraryItem(
    id: 'getting-started',
    category: 'Guides',
    title: 'Getting Started',
    subtitle: 'Set up your first feature slice',
    detail:
        'Run the add-feature skill to scaffold a full slice — model, Dio client, '
        'Riverpod state, screen, route, and a test — the way this app is built.',
    iconName: 'rocket',
    minutes: 6,
    progress: 1.0,
  ),
  LibraryItem(
    id: 'design-system',
    category: 'Design',
    title: 'Design System',
    subtitle: 'Material 3 components, one editorial theme',
    detail:
        'Every DS component wraps a stock Material 3 widget and applies the '
        'theme — ink primary, terracotta accent, Satoshi type. Nothing is '
        'reimplemented, so accessibility and platform behaviour come for free.',
    iconName: 'palette',
    minutes: 12,
    progress: 0.4,
  ),
  LibraryItem(
    id: 'auth-paywall',
    category: 'Modules',
    title: 'Auth & Paywall',
    subtitle: 'Pre-wired modules behind a mock',
    detail:
        'Auth (with gated routing), subscriptions, analytics, and crash '
        'reporting ship pre-built behind a mock/console default. Swap to a real '
        'backend in one place.',
    iconName: 'lock',
    minutes: 9,
    progress: 0.0,
  ),
  LibraryItem(
    id: 'analytics',
    category: 'Modules',
    title: 'Analytics',
    subtitle: 'Console adapter, swap in one place',
    detail:
        'Every meaningful action is instrumented against a service interface. '
        'The console adapter logs locally; point it at your provider when ready.',
    iconName: 'insights',
    minutes: 15,
    progress: 0.75,
  ),
  LibraryItem(
    id: 'skeleton-loading',
    category: 'Design',
    title: 'Skeleton Loading',
    subtitle: 'This list — skeletonizer while it loads',
    detail:
        'The loading state is the real widget tree rendered as bones by the '
        'skeletonizer package, so it can never drift out of shape with the '
        'content. Pull down to replay it.',
    iconName: 'layers',
    minutes: 8,
    progress: 0.2,
  ),
  LibraryItem(
    id: 'haptics',
    category: 'Design',
    title: 'Haptics',
    subtitle: 'Tactile feedback that honours settings',
    detail:
        'AppHaptics gives every commit a tactile response, gated by the user\'s '
        'Haptic feedback setting. Feel it on a physical device.',
    iconName: 'vibration',
    minutes: 11,
    progress: 0.0,
  ),
];
