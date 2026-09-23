import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/services/observability/analytics.dart';
import 'package:parley_android/services/observability/crash_reporter.dart';
import 'package:parley_android/services/service_config.dart';

/// Product analytics. Inject a fake in tests by overriding this provider.
final analyticsProvider = Provider<Analytics>((ref) {
  return ServiceConfig.createAnalytics();
});

/// Crash reporter. `main.dart` overrides this with the same instance it wired
/// into `FlutterError.onError`, so app-surfaced and uncaught errors share one
/// reporter.
final crashReporterProvider = Provider<CrashReporter>((ref) {
  return ServiceConfig.createCrashReporter();
});
