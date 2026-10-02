// ds-tier: 2 — molecule

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_segmented_button.dart';

/// A segmented button for selecting Light / System / Dark theme mode.
///
/// Eliminates duplication of the ThemeMode picker pattern across screens.
///
/// The compact form is icon-only, and the name it announces is a `tooltip`
/// rather than an empty visible label. Passing `label: ''` was how this
/// shipped three unnamed cells in a control whose whole job is to say which
/// of three things is chosen; a segment with no label now has to carry a
/// tooltip or it asserts.
class DSThemeModePicker extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;
  final bool showLabels;

  /// Forwarded to the [DSSegmentedButton] underneath.
  ///
  /// This picker has no appearance of its own — it is a composition, so it
  /// gets no style object of its own either. What it must not do is *swallow*
  /// the one belonging to the control it builds: a component that hides its
  /// child's style is a hole in the chain, and the caller's only way out is a
  /// `Theme` two layers wider than they wanted.
  final DSSegmentedButtonStyle? style;

  const DSThemeModePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.showLabels = true,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return DSSegmentedButton<ThemeMode>(
      segments: [
        for (final (ThemeMode mode, String name, IconData icon) in const [
          (ThemeMode.light, 'Light', Icons.light_mode),
          (ThemeMode.system, 'System', Icons.settings_suggest),
          (ThemeMode.dark, 'Dark', Icons.dark_mode),
        ])
          DSSegment<ThemeMode>(
            value: mode,
            label: showLabels ? name : null,
            tooltip: name,
            icon: icon,
          ),
      ],
      selected: value,
      onChanged: onChanged,
      // Labelled = standalone and equal-width; icon-only = compact, in a
      // settings row's trailing slot where three words would not fit.
      sizing: showLabels ? DSSegmentedSizing.equal : DSSegmentedSizing.content,
      style: style,
    );
  }
}
