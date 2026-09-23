import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:parley_android/config/env.dart';
import 'package:parley_android/services/auth/auth_service.dart';
import 'package:parley_android/services/auth/mock_auth_service.dart';
import 'package:parley_android/services/auth/supabase_auth_service.dart';
import 'package:parley_android/services/auth/token_store.dart';
import 'package:parley_android/services/observability/analytics.dart';
import 'package:parley_android/services/observability/crash_reporter.dart';
import 'package:parley_android/services/parley/fake_parley_bridge.dart';
import 'package:parley_android/services/parley/method_channel_parley_bridge.dart';
import 'package:parley_android/services/parley/parley_bridge.dart';
import 'package:parley_android/services/purchases/mock_purchases_service.dart';
import 'package:parley_android/services/purchases/purchases_service.dart';
import 'package:parley_android/services/purchases/revenuecat_purchases_service.dart';

/// The single place where each integration seam picks its implementation.
///
/// Everything in `lib/` depends on the *interfaces* (`AuthService`,
/// `PurchasesService`, `Analytics`, `CrashReporter`, `TokenStore`) and reads
/// them through Riverpod providers. Those providers call the factories here.
/// To go from prototype to production you change exactly one method — e.g.
/// `createAuthService` returns a `SupabaseAuthService` instead of the mock —
/// and no screen, provider, or test needs to change.
///
/// This mirrors `ApiConfig.useMockBackend`: mocks by default so a clean clone
/// runs offline, real implementations swapped in per app.
abstract final class ServiceConfig {
  ServiceConfig._();

  /// Product analytics. Swap [ConsoleAnalytics] for PostHog/Amplitude/etc.
  static Analytics createAnalytics() => const ConsoleAnalytics();

  /// Crash reporting. Swap [ConsoleCrashReporter] for Sentry/Crashlytics.
  static CrashReporter createCrashReporter() => const ConsoleCrashReporter();

  /// Where the auth session is persisted. [SecureTokenStore] uses the OS
  /// keychain/keystore; tests override the provider with [InMemoryTokenStore].
  static TokenStore createTokenStore() => SecureTokenStore();

  /// Authentication. Uses Supabase when `Env.hasSupabase` (URL + anon key are
  /// supplied via --dart-define); otherwise the offline mock.
  static AuthService createAuthService(TokenStore tokenStore) =>
      Env.hasSupabase ? SupabaseAuthService() : MockAuthService(tokenStore);

  /// In-app purchases. Uses RevenueCat when `Env.hasRevenueCat`; else the mock.
  static PurchasesService createPurchasesService() =>
      Env.hasRevenueCat ? RevenueCatPurchasesService() : MockPurchasesService();

  /// The native core. The platform channel on Android, where `MainActivity`
  /// registers it; the in-memory fake everywhere else (tests, the probe, a
  /// desktop run). `--dart-define=PARLEY_FAKE=true` forces the fake on a
  /// device, for screenshots without the service.
  static ParleyBridge createParleyBridge() {
    const forceFake = bool.fromEnvironment('PARLEY_FAKE');
    if (!forceFake && !kIsWeb && Platform.isAndroid) {
      return MethodChannelParleyBridge();
    }
    return FakeParleyBridge.ready();
  }
}
