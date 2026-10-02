// ui-lint: allow model-imports-flutter — ThemeMode is a Flutter value enum with no pure-Dart equivalent; nothing
// here touches a widget or a binding, which is what the rule protects.
import 'package:flutter/material.dart';

/// Cross-cutting user preferences persisted via SharedPreferences.
///
/// Extend with your own fields, then update [SettingsNotifier] in
/// `lib/providers/settings_provider.dart` to load/save them. Keep this
/// model immutable — mutations go through `copyWith`.
class AppSettings {
  final ThemeMode themeMode;
  final bool hapticFeedback;
  final bool confirmBeforeDelete;

  /// Whether the user has finished (or skipped) the first-run onboarding.
  /// The router shows onboarding until this is true.
  final bool onboardingComplete;

  /// Whether the user has been introduced to the app — i.e. seen the welcome
  /// screen — on this device. Distinct from [onboardingComplete]: the
  /// welcome is *introduction*, the tour is *orientation*, and a returning
  /// user who finished the tour should not see the welcome any more than
  /// they should see the tour again.
  ///
  /// The router shows `/welcome` only when this is false. Both the page's
  /// primary action and its ghost secondary flip this to true on tap — the
  /// welcome is one-shot, regardless of which branch the user took.
  final bool welcomeSeen;

  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.hapticFeedback = true,
    this.confirmBeforeDelete = true,
    this.onboardingComplete = false,
    this.welcomeSeen = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? hapticFeedback,
    bool? confirmBeforeDelete,
    bool? onboardingComplete,
    bool? welcomeSeen,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      confirmBeforeDelete: confirmBeforeDelete ?? this.confirmBeforeDelete,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      welcomeSeen: welcomeSeen ?? this.welcomeSeen,
    );
  }
}
