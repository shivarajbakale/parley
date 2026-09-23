import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:parley_android/data/mock/mock_store.dart';

/// Artificial latency added to every mock response so loading states are
/// visible in the UI while developing.
const Duration _mockLatency = Duration(milliseconds: 900);

/// Registers HTTP routes on [adapter] that resolve against [store].
///
/// Replace the example routes below with the endpoints your app needs.
/// Patterns to copy:
///   * `adapter.onGet('/api/foo', ...)`       — collection
///   * `adapter.onGet(RegExp(r'^/api/foo/[^/]+\$'), ...)` — by-id
///   * `adapter.onPost('/api/foo', ..., data: Matchers.any)` — create
void registerMockRoutes(DioAdapter adapter, MockStore store) {
  adapter.onGet(
    '/api/ping',
    (server) => server.replyCallbackAsync(200, (_) async {
      return {'ok': true, 'time': DateTime.now().toIso8601String()};
    }, delay: _mockLatency),
  );

  // The demo collection behind the Library tab. Serves the same
  // `LibraryItem` JSON a real backend would.
  adapter.onGet(
    '/api/library',
    (server) => server.replyCallbackAsync(200, (_) async {
      final items = store.library.values.toList();
      return {
        'data': [for (final item in items) item.toJson()],
        'meta': {'total': items.length},
      };
    }, delay: _mockLatency),
  );

  // The Home tab's summary. Derived from the same store the Library reads, so
  // the two screens cannot disagree about how many things exist — a demo
  // where the home screen counts nine and the next tab lists three teaches
  // the reader that the screens are unrelated.
  adapter.onGet(
    '/api/dashboard',
    (server) => server.replyCallbackAsync(200, (_) async {
      final items = store.library.values;
      return {
        'itemCount': items.length,
        'categoryCount': {for (final item in items) item.category}.length,
        'completedCount': items
            .where((item) => store.completed.contains(item.id))
            .length,
        // Derived from the same store for the same reason the counts are: a
        // chart that disagrees with the number above it teaches the reader
        // that neither is real.
        'itemsByCategory': <String, int>{
          for (final item in items)
            item.category: items
                .where((i) => i.category == item.category)
                .length,
        },
      };
    }, delay: _mockLatency),
  );
}
