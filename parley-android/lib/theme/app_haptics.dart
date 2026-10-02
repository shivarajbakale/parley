import 'package:flutter/services.dart';

/// Centralised haptic feedback that honours the user's "Haptic feedback"
/// setting.
///
/// Design-system components and screens call these semantic helpers instead of
/// [HapticFeedback] directly. A single mutable [enabled] flag gates every call,
/// so the settings toggle actually reaches the whole app without coupling the
/// design system to Riverpod. The flag is synced from `SettingsNotifier`
/// (on load and on change).
///
/// Use the semantic intent, not the raw impact strength:
///   • [selection] — moving between discrete options (tabs, segments, toggles).
///   • [light]     — a minor confirmation (secondary button, chip).
///   • [medium]    — a committed action (primary button, sheet snap, refresh).
///   • [heavy]     — a weighty/rare event (delete confirmed, long-press grab).
///   • [success] / [warning] / [error] — outcome notifications.
abstract final class AppHaptics {
  /// Whether haptics fire. Synced from the user's setting; defaults to on so
  /// the app feels tactile before settings have loaded.
  static bool enabled = true;

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  static void success() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void warning() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void error() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
