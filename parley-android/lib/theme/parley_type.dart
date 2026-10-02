import 'package:flutter/material.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The two Aurora faces the role table does not reach on its own.
///
/// `DSTextRole` picks a step and a family by what a string *is*; Parley adds
/// two things a string can be that the template never had. The user's own
/// words — a transcript, an edit instruction — are set in the text face,
/// italic, so they read as quoted speech rather than interface. And figures
/// are set in the rounded display face, heavy: Nunito draws every digit on
/// one advance, so a counter does not jitter as it changes. Both start from a
/// role's step so they grow with the reader's text scale exactly as that
/// role does.
abstract final class ParleyType {
  /// A transcript or an instruction, as a quotation.
  static TextStyle voice(BuildContext context, {bool large = false}) {
    final text = Theme.of(context).textTheme;
    final base =
        (large ? text.headlineSmall : text.titleLarge) ?? const TextStyle();
    return base.copyWith(
      fontFamily: context.design.type.family,
      fontStyle: FontStyle.italic,
      fontWeight: context.design.type.labelWeight,
      height: 1.35,
      letterSpacing: 0,
    );
  }

  /// A transcript in a list row: upright, at row size.
  static TextStyle voiceRow(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    return base.copyWith(
      fontFamily: context.design.type.family,
      fontWeight: context.design.type.labelWeight,
      height: 1.35,
      letterSpacing: 0,
    );
  }

  /// A figure in a stat tile or a counter.
  static TextStyle figure(BuildContext context) {
    final base =
        Theme.of(context).textTheme.headlineMedium ?? const TextStyle();
    return base
        .copyWith(
          fontFamily: context.design.type.displayFamily,
          fontWeight: context.design.type.emphasisWeight,
          letterSpacing: -0.4,
        )
        .tabular;
  }

  /// A small figure label — a timer, a step counter.
  static TextStyle mono(BuildContext context) {
    final base = Theme.of(context).textTheme.labelMedium ?? const TextStyle();
    return base
        .copyWith(
          fontFamily: context.design.type.displayFamily,
          fontWeight: context.design.type.titleWeight,
          letterSpacing: 0,
        )
        .tabular;
  }
}
