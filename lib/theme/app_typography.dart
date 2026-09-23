import 'package:flutter/material.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The three type treatments that are not a role in the scale.
///
/// Everything with a name in `TextTheme` — display through label — is built by
/// [TypeSpec] and reached through `Theme.of(context).textTheme`. This file is
/// only for the treatments that sit *on top of* a role: an eyebrow is
/// `labelSmall` uppercased and opened up, a section header is `titleSmall` at
/// the emphasis weight, and tabular figures are a font feature rather than a
/// style.
///
/// It used to hold a second, complete 15-role `TextTheme` with hand-typed
/// sizes. Nothing imported it — `DesignSpec.themeFor` builds the live theme
/// from `TypeSpec` — so two hundred lines of a scale the app does not use sat
/// in the file anyone opens looking for the app's typography, describing sizes
/// and weights that were not the ones on screen. It is deleted. If you want to
/// know what type this app sets, read [TypeSpec].
abstract final class AppTypography {
  /// Section header — `titleSmall` at the weight that marks emphasis.
  ///
  /// Takes a context rather than a `TextTheme` so the weight comes from the
  /// spec: `FontWeight.bold` here was a literal that happened to be right, and
  /// an identity that sets a lighter emphasis step could not override it.
  static TextStyle? sectionHeader(BuildContext context) => Theme.of(context)
      .textTheme
      .titleSmall
      ?.copyWith(fontWeight: context.design.type.emphasisWeight);

  /// An eyebrow's text, cased the way the identity asks.
  ///
  /// [TypeSpec.eyebrowUppercase] is the knob, and every call site used to
  /// call `toUpperCase()` itself — so an identity that wanted sentence-case
  /// eyebrows could set the field and watch nothing happen.
  static String eyebrowCase(BuildContext context, String text) =>
      context.design.type.eyebrowUppercase ? text.toUpperCase() : text;

  /// Editorial eyebrow — the small tracked line above a title
  /// ("FRIDAY · MAY 16", "OVERDUE", "INBOX"). Pass the string through
  /// [eyebrowCase] rather than casing it at the call site.
  ///
  /// Built from `labelSmall` and the spec's own eyebrow tracking rather than
  /// from a hand-typed 11pt. The literal version did not move when the scale
  /// moved, so at a raised base size the eyebrow stayed where it was and the
  /// gap to the title it labelled grew by two points.
  static TextStyle? eyebrow(BuildContext context) {
    final type = context.design.type;
    return Theme.of(context).textTheme.labelSmall?.copyWith(
      color: context.palette.mutedForeground,
      letterSpacing: type.eyebrowTracking,
    );
  }
}

/// Tabular figures, so numeric runs (counts, percentages, dates) align in a
/// monospaced grid without affecting the letters beside them. Safe on any
/// style that renders digits.
///
/// A getter rather than the static function it replaces, because the styles
/// that need it are nearly all nullable steps off a `TextTheme` and Dart's
/// null-shorting carries through the whole selector chain:
/// `text.labelMedium?.copyWith(color: x).tabular` is null exactly when the
/// step is. The static took a non-null [TextStyle], so twelve call sites in
/// the kit wrote the font feature out by hand instead — the same decision,
/// spelled two ways, in the file that exists to hold it once.
extension DSTabularFigures on TextStyle {
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
