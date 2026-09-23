import 'package:parley_android/models/library_item.dart';

/// In-memory backing store for the mock backend. Singleton: one instance
/// is shared across the whole app for the lifetime of the process.
///
/// It holds one collection — the demo Library — so the mock backend, the
/// model, the repository, and the UI all speak about the same thing. Replace
/// it with your domain entities and register matching routes in
/// `mock_routes.dart`.
class MockStore {
  MockStore._();

  static final MockStore instance = MockStore._();

  /// The demo collection, keyed by id and seeded from [demoLibraryItems].
  /// Swap for your real entity map(s).
  final Map<String, LibraryItem> library = {
    for (final item in demoLibraryItems) item.id: item,
  };

  /// Which of [library] the demo user has finished.
  ///
  /// A second collection rather than a field on the item, because "have *I*
  /// read this" is per-user state and the item is not: putting it on the model
  /// is the shortcut that later has to be undone when a second account exists.
  /// The home screen's meter is the count of these over the count of those.
  final Set<String> completed = {'getting-started', 'design-system'};
}
