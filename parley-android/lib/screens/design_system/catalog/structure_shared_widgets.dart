import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// A bordered, bounded stage for the parts that expect to sit at the top of a
/// screen rather than inside one.
///
/// Shared by the [DSComponentDemo] stories for `DSPage`, `DSFormPage`,
/// `DSPageHeader` and `DSHero` — split out of `structure_stories.dart` when
/// that file was broken into one file per component.
class StoryStage extends StatelessWidget {
  final Widget child;

  const StoryStage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final schemePalette = context.palette;
    return Container(
      // No fixed height: the subject decides. This stage held the page header
      // at 180 points, and the header wants 248 at a doubled text scale — so
      // the story showed a clipped header, which is a picture of something
      // the component does not do.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.radiusOf(AppShape.tile)),
        border: Border.all(color: schemePalette.borderSoft),
      ),
      child: child,
    );
  }
}

/// The interactive `DSThemeModePicker`, local to the gallery.
///
/// Shared by the [DSComponentDemo] stories for `DSSettingsSection` (in its
/// trailing slot) and `DSThemeModePicker` itself.
class ThemeModeDemo extends StatefulWidget {
  final bool showLabels;

  const ThemeModeDemo({super.key, this.showLabels = true});

  @override
  State<ThemeModeDemo> createState() => _ThemeModeDemoState();
}

class _ThemeModeDemoState extends State<ThemeModeDemo> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return DSThemeModePicker(
      value: _mode,
      showLabels: widget.showLabels,
      // Local, so the gallery can be read without repainting the app. The real
      // one writes through `settingsProvider` — see the Settings tab.
      onChanged: (mode) => setState(() => _mode = mode),
    );
  }
}
