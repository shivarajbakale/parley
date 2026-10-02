import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/catalog/structure_shared_widgets.dart';

final dsThemeModePickerDemo = DSComponentDemo(
  name: 'DSThemeModePicker',
  summary: 'Light / System / Dark, already wired to the labels and icons.',
  stories: [
    DSStory(
      title: 'With labels',
      note: 'The full control, for the appearance screen it belongs to.',
      builder: (context) => const ThemeModeDemo(),
    ),
    DSStory(
      title: 'Icons only',
      note:
          'showLabels: false when it sits in the trailing slot of a '
          'settings row.',
      builder: (context) => const ThemeModeDemo(showLabels: false),
    ),
  ],
);
