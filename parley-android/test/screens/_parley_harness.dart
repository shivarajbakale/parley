import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/services/parley/fake_parley_bridge.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The clock the Parley screen tests read "Today" and times against.
final DateTime parleyTestNow = DateTime(2026, 9, 24, 10, 1);

/// Mounts one Parley screen over [bridge] on a 390x844 phone, in the dark
/// theme the app opens in.
Future<void> pumpParley(
  WidgetTester tester,
  Widget screen, {
  FakeParleyBridge? bridge,
  ThemeMode mode = ThemeMode.dark,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'onboarding_complete': true});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        parleyBridgeProvider.overrideWithValue(
          bridge ?? FakeParleyBridge.ready(now: parleyTestNow),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
