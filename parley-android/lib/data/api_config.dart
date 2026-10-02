import 'package:parley_android/config/env.dart';

/// REST configuration. Values now come from [Env] (flavor + `--dart-define`)
/// so dev/staging/prod differ without code edits. This class stays as the
/// stable seam the data layer reads.
class ApiConfig {
  ApiConfig._();

  /// Base URL for the REST API. Per-flavor default, overridable with
  /// `--dart-define=API_BASE_URL=…`. See [Env.apiBaseUrl].
  static String get baseUrl => Env.apiBaseUrl;

  /// When true, HTTP requests are answered from the in-memory mock store.
  /// Mocks by default in dev; flip per build with `--dart-define=USE_MOCK=…`.
  static bool get useMockBackend => Env.useMockBackend;
}
