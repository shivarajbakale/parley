import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:parley_android/app.dart';
import 'package:parley_android/config/env.dart';
import 'package:parley_android/providers/observability_provider.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/services/service_config.dart';

void main() async {
  // Build the crash reporter first so it can capture errors during startup.
  // The same instance is handed to the app via a provider override, so
  // FlutterError, uncaught zone errors, and app-surfaced errors all share it.
  final crashReporter = ServiceConfig.createCrashReporter();

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      crashReporter.recordError(details.exception, details.stack, fatal: true);
    };

    // Request the highest refresh rate available (120Hz, 90Hz, etc.).
    // The plugin only ships an Android implementation, so it raises
    // MissingPluginException on iOS — swallow it.
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {}

    // Initialize real backends only when configured (keys via --dart-define).
    // Absent → the mock/console seams run and the app works offline.
    if (Env.hasSupabase) {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        // Supabase renamed the parameter; `anonKey` is deprecated. The
        // --dart-define stays SUPABASE_ANON_KEY, which is what the dashboard
        // and docs/MODULES.md still call it.
        publishableKey: Env.supabaseAnonKey,
      );
    }
    if (Env.hasRevenueCat) {
      await Purchases.configure(PurchasesConfiguration(Env.revenueCatApiKey));
    }

    final prefs = await SharedPreferences.getInstance();

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          crashReporterProvider.overrideWithValue(crashReporter),
        ],
        child: const RocketshipApp(),
      ),
    );
  }, (error, stack) => crashReporter.recordError(error, stack, fatal: true));
}
