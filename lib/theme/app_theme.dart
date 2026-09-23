import 'package:flutter/material.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

class AppTheme {
  AppTheme._();

  /// The design this app ships. One value; changing it changes everything.
  ///
  /// Built once rather than per access: a `DesignSpec` grows its palette in
  /// OKLCH at construction, and `lightTheme` is read on every rebuild of the
  /// `MaterialApp`.
  static final DesignSpec spec = DesignSpec.halo();

  static ThemeData get lightTheme => spec.themeFor(Brightness.light);
  static ThemeData get darkTheme => spec.themeFor(Brightness.dark);
}
