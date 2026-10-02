import 'package:flutter/foundation.dart';

/// Crash / error-reporting seam.
///
/// The boilerplate ships [ConsoleCrashReporter] so uncaught errors are
/// printed in debug with zero setup. Swap in Sentry (`sentry_flutter`) or
/// Crashlytics (`firebase_crashlytics`) by implementing this interface and
/// returning it from `ServiceConfig.createCrashReporter()`. `main.dart`
/// already routes `FlutterError.onError` and the root zone's uncaught errors
/// here, so wiring a real backend captures everything automatically.
abstract interface class CrashReporter {
  /// Reports a caught or uncaught error with its stack trace.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal,
    Map<String, Object?>? context,
  });

  /// Adds a breadcrumb / log line that accompanies the next reported error.
  void log(String message);

  /// Tags subsequent reports with a user id (call after sign-in; pass null
  /// on sign-out).
  void setUser(String? userId);
}

/// Default implementation: prints errors with `debugPrint`.
class ConsoleCrashReporter implements CrashReporter {
  const ConsoleCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    Map<String, Object?>? context,
  }) async {
    final tag = fatal ? 'FATAL' : 'error';
    debugPrint('[crash] $tag: $error');
    if (context != null && context.isNotEmpty) {
      debugPrint('[crash] context: $context');
    }
    if (stack != null) debugPrint('[crash] $stack');
  }

  @override
  void log(String message) => debugPrint('[crash] breadcrumb: $message');

  @override
  void setUser(String? userId) => debugPrint('[crash] user: ${userId ?? '-'}');
}
