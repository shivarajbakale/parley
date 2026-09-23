/// Compile-time environment configuration.
///
/// Plug-and-play: every value has a sensible default, so the app runs with no
/// flags. Select a flavor and override values at build/run time with
/// `--dart-define` (or `--dart-define-from-file=env/prod.json`):
///
///   flutter run --dart-define=ENV=staging
///   flutter build apk --dart-define=ENV=prod --dart-define=API_BASE_URL=https://api.acme.com
///
/// `String.fromEnvironment` is const, so these resolve at compile time and
/// tree-shake — no runtime config file to ship or leak. Secrets still don't
/// belong in source; pass them via --dart-define from CI secrets.
enum AppFlavor { dev, staging, prod }

abstract final class Env {
  Env._();

  static const String _raw = String.fromEnvironment('ENV', defaultValue: 'dev');

  static AppFlavor get flavor => switch (_raw) {
    'prod' => AppFlavor.prod,
    'staging' => AppFlavor.staging,
    _ => AppFlavor.dev,
  };

  static bool get isProd => flavor == AppFlavor.prod;
  static bool get isDev => flavor == AppFlavor.dev;

  /// REST base URL. Override with `--dart-define=API_BASE_URL=…`; otherwise a
  /// per-flavor default is used.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    return switch (flavor) {
      AppFlavor.prod => 'https://api.example.com',
      AppFlavor.staging => 'https://staging-api.example.com',
      // Android emulator: use 10.0.2.2. Physical device: `adb reverse
      // tcp:3000 tcp:3000` so localhost on the device reaches your machine.
      AppFlavor.dev => 'http://localhost:3000',
    };
  }

  /// Whether to answer HTTP from the in-memory mock store.
  /// `--dart-define=USE_MOCK=true|false` wins; otherwise mocks only in dev.
  static bool get useMockBackend {
    const override = String.fromEnvironment('USE_MOCK');
    if (override == 'true') return true;
    if (override == 'false') return false;
    return flavor == AppFlavor.dev;
  }

  /// A short label for debug banners / about screens, e.g. "STAGING".
  static String get label => switch (flavor) {
    AppFlavor.prod => 'PROD',
    AppFlavor.staging => 'STAGING',
    AppFlavor.dev => 'DEV',
  };

  // ── Backend selection ──
  // Provide these via --dart-define (from CI secrets) to flip a seam from its
  // mock to the real SDK. Absent → the mock/console default keeps running, so
  // the boilerplate works offline out of the box.

  /// Supabase project URL. With [supabaseAnonKey], activates SupabaseAuthService.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// True when both Supabase values are present.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// RevenueCat public SDK key. Present → activates RevenueCatPurchasesService.
  static const String revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
  );

  static bool get hasRevenueCat => revenueCatApiKey.isNotEmpty;
}
