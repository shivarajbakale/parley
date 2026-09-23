import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parley_android/models/app_settings.dart';
import 'package:parley_android/theme/app_haptics.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;

  static const _kThemeMode = 'theme_mode';
  static const _kHapticFeedback = 'haptic_feedback';
  static const _kConfirmBeforeDelete = 'confirm_before_delete';
  static const _kOnboardingComplete = 'onboarding_complete';
  static const _kWelcomeSeen = 'welcome_seen';

  SettingsNotifier(this._prefs) : super(_load(_prefs)) {
    // Sync the global haptics gate so design-system components honour the
    // user's saved preference from the first frame.
    AppHaptics.enabled = state.hapticFeedback;
  }

  static AppSettings _load(SharedPreferences prefs) {
    return AppSettings(
      themeMode: _parseThemeMode(prefs.getString(_kThemeMode)),
      hapticFeedback: prefs.getBool(_kHapticFeedback) ?? true,
      confirmBeforeDelete: prefs.getBool(_kConfirmBeforeDelete) ?? true,
      onboardingComplete: prefs.getBool(_kOnboardingComplete) ?? false,
      welcomeSeen: prefs.getBool(_kWelcomeSeen) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_kThemeMode, mode.name);
  }

  Future<void> setHapticFeedback(bool value) async {
    state = state.copyWith(hapticFeedback: value);
    AppHaptics.enabled = value;
    await _prefs.setBool(_kHapticFeedback, value);
  }

  Future<void> setConfirmBeforeDelete(bool value) async {
    state = state.copyWith(confirmBeforeDelete: value);
    await _prefs.setBool(_kConfirmBeforeDelete, value);
  }

  /// Marks first-run onboarding as done. The router redirect reacts and moves
  /// the user on to the auth flow / home.
  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingComplete: true);
    await _prefs.setBool(_kOnboardingComplete, true);
  }

  /// Marks the welcome screen as seen. The router redirect reacts and skips
  /// `/welcome` on the next cold launch.
  ///
  /// Distinct from [completeOnboarding] because they answer different
  /// questions: the welcome is *introduction* (have you been introduced to
  /// the app?), the tour is *orientation* (have you read the tour?). A
  /// returning user who finished the tour should not see the welcome again,
  /// and a user who tapped "I already have an account" was by definition
  /// introduced the first time — both branches of `/welcome` flip this flag.
  Future<void> markWelcomeSeen() async {
    if (state.welcomeSeen) return;
    state = state.copyWith(welcomeSeen: true);
    await _prefs.setBool(_kWelcomeSeen, true);
  }

  static ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }
}

/// Must be overridden in `main.dart` with the actual [SharedPreferences]
/// instance via [ProviderScope.overrides].
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
