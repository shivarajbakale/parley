import 'package:flutter/material.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The two Aurora faces the role table does not reach on its own.
///
/// `DSTextRole` picks a step and a family by what a string *is*; Parley adds
/// two things a string can be that the template never had. The user's own
/// words — a transcript, an edit instruction — are set in the display serif,
/// italic, so they never read as interface. And figures are set in Geist
/// Mono, because a serif display face at emphasis weight is a synthesised
/// bold. Both start from a role's step so they grow with the reader's text
/// scale exactly as that role does.
abstract final class ParleyType {
  static const monoFamily = 'Geist Mono';

  /// A transcript or an instruction, as a quotation.
  static TextStyle voice(BuildContext context, {bool large = false}) {
    final text = Theme.of(context).textTheme;
    final base =
        (large ? text.headlineSmall : text.titleLarge) ?? const TextStyle();
    return base.copyWith(
      fontFamily: context.design.type.displayFamily,
      fontStyle: FontStyle.italic,
      fontWeight: context.design.type.bodyWeight,
      height: 1.3,
      letterSpacing: 0,
    );
  }

  /// A transcript in a list row: the serif upright, at row size.
  static TextStyle voiceRow(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    return base.copyWith(
      fontFamily: context.design.type.displayFamily,
      fontWeight: context.design.type.bodyWeight,
      fontSize: (base.fontSize ?? 16) * 1.12,
      height: 1.3,
      letterSpacing: 0,
    );
  }

  /// A figure in a stat tile or a counter.
  static TextStyle figure(BuildContext context) {
    final base =
        Theme.of(context).textTheme.headlineMedium ?? const TextStyle();
    return base.copyWith(
      fontFamily: monoFamily,
      fontWeight: context.design.type.labelWeight,
      letterSpacing: -0.8,
    ).tabular;
  }

  /// A small mono label — a timer, a step counter.
  static TextStyle mono(BuildContext context) {
    final base = Theme.of(context).textTheme.labelMedium ?? const TextStyle();
    return base.copyWith(
      fontFamily: monoFamily,
      fontWeight: context.design.type.bodyWeight,
      letterSpacing: 0,
    ).tabular;
  }
}
