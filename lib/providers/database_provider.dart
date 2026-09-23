import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/data/api_config.dart';
import 'package:parley_android/data/dio_client.dart';
import 'package:parley_android/data/local/app_database.dart';

/// Single shared [Dio] instance. When [ApiConfig.useMockBackend] is true,
/// a [DioAdapter] is attached and the routes from `data/mock/mock_routes.dart`
/// resolve from the in-memory [MockStore]. Flip [ApiConfig.useMockBackend]
/// to false to hit the real backend at [ApiConfig.baseUrl].
final dioProvider = Provider<Dio>((ref) {
  final dio = buildDio(mock: ApiConfig.useMockBackend);
  ref.onDispose(dio.close);
  return dio;
});

/// Shared offline [AppDatabase] (Drift). Override in tests with an in-memory
/// executor. Read it for local/offline persistence; see docs/MODULES.md.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
