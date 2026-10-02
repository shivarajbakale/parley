import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/data/dio_client.dart';
import 'package:parley_android/models/dashboard_summary.dart';
import 'package:parley_android/providers/database_provider.dart';

/// The home screen's data, on the same shape as [LibraryRepository].
///
/// It exists so the first screen the user sees has something that can be
/// late, and something that can fail. A screen watching a synchronous
/// provider cannot demonstrate a loading state or an error state, and a
/// boilerplate whose home screen skips both teaches the reader that skipping
/// both is normal.
class DashboardRepository {
  const DashboardRepository(this._dio);

  final Dio _dio;

  Future<DashboardSummary> fetchSummary() => dioCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/dashboard');
    return DashboardSummary.fromJson(response.data ?? const {});
  });
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(dioProvider)),
);

/// The Home tab's state. Like `libraryItemsProvider`, a [FutureProvider] so
/// the UI gets `loading` / `error` / `data` as one `switch`, and
/// `ref.invalidate` is the whole of pull-to-refresh.
final dashboardSummaryProvider = FutureProvider<DashboardSummary>(
  (ref) => ref.watch(dashboardRepositoryProvider).fetchSummary(),
);
