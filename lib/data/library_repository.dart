import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/data/dio_client.dart';
import 'package:parley_android/models/library_item.dart';
import 'package:parley_android/providers/database_provider.dart';

/// The reference repository: one endpoint, decoded into the domain model,
/// with Dio errors mapped to the app's typed exceptions by [dioCall].
///
/// Copy this shape for your own feature — a repository per domain, taking the
/// shared [Dio] and returning models, never raw maps.
class LibraryRepository {
  const LibraryRepository(this._dio);

  final Dio _dio;

  Future<List<LibraryItem>> fetchItems() => dioCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/library');
    final data = (response.data?['data'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return [for (final json in data) LibraryItem.fromJson(json)];
  });
}

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(dioProvider)),
);

/// The Library tab's state. A [FutureProvider] gives the UI an [AsyncValue] for
/// free, so `loading` / `error` / `data` are all handled in one `switch` —
/// `ref.invalidate(libraryItemsProvider)` re-fetches (pull-to-refresh).
final libraryItemsProvider = FutureProvider<List<LibraryItem>>(
  (ref) => ref.watch(libraryRepositoryProvider).fetchItems(),
);

/// The demo's locally removed items, by id.
///
/// A real app deletes through the repository. What is being demonstrated is
/// the *interaction* — a swipe that takes a row away, an undo that puts it
/// back, and a second way to reach the same action for the reader who cannot
/// swipe — so the state lives here rather than inside the list screen. Two
/// screens act on it: the swipe on the Library row, and "Remove from library"
/// on the detail page the chevron leads to. A `Set` in one screen's `State`
/// could only ever be reached from that screen, which is how a destructive
/// action ends up available by gesture only.
class RemovedLibraryItems extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void remove(String id) => state = {...state, id};

  void restore(String id) => state = {
    for (final removed in state)
      if (removed != id) removed,
  };
}

final removedLibraryItemsProvider =
    NotifierProvider<RemovedLibraryItems, Set<String>>(RemovedLibraryItems.new);
