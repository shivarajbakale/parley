import 'package:flutter/foundation.dart';

/// Product analytics seam.
///
/// The boilerplate ships [ConsoleAnalytics] so events are visible in the
/// debug console with zero setup. Swap in a real implementation (PostHog,
/// Amplitude, Firebase Analytics, Segment) by adding a class that implements
/// this interface and returning it from `ServiceConfig.createAnalytics()`.
/// Nothing else in the app changes — screens depend on this interface, never
/// on a concrete SDK.
abstract interface class Analytics {
  /// Records that the user viewed a screen.
  void screen(String name, {Map<String, Object?>? properties});

  /// Records a discrete product event ("paywall_viewed", "item_created").
  void event(String name, {Map<String, Object?>? properties});

  /// Associates subsequent events with a user (call after sign-in).
  void identify(String userId, {Map<String, Object?>? traits});

  /// Clears the associated user (call on sign-out).
  void reset();
}

/// Default implementation: prints structured events with `debugPrint`.
///
/// In release builds `debugPrint` is a no-op, so this is safe to ship as the
/// fallback. Replace it with a real backend before launch.
class ConsoleAnalytics implements Analytics {
  const ConsoleAnalytics();

  @override
  void screen(String name, {Map<String, Object?>? properties}) =>
      _log('screen', name, properties);

  @override
  void event(String name, {Map<String, Object?>? properties}) =>
      _log('event', name, properties);

  @override
  void identify(String userId, {Map<String, Object?>? traits}) =>
      _log('identify', userId, traits);

  @override
  void reset() => _log('reset', '-', null);

  void _log(String kind, String name, Map<String, Object?>? props) {
    final suffix = (props == null || props.isEmpty) ? '' : ' $props';
    debugPrint('[analytics] $kind: $name$suffix');
  }
}

/// Drops every call. Useful in tests or when analytics must be disabled.
class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  void screen(String name, {Map<String, Object?>? properties}) {}

  @override
  void event(String name, {Map<String, Object?>? properties}) {}

  @override
  void identify(String userId, {Map<String, Object?>? traits}) {}

  @override
  void reset() {}
}
