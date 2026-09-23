import 'package:parley_android/screens/design_system/catalog/action_stories.dart';
import 'package:parley_android/screens/design_system/catalog/foundation_stories.dart';
import 'package:parley_android/screens/design_system/catalog/input_stories.dart';
import 'package:parley_android/screens/design_system/catalog/navigation_stories.dart';
import 'package:parley_android/screens/design_system/catalog/overlay_stories.dart';
import 'package:parley_android/screens/design_system/catalog/state_stories.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/catalog/structure_stories.dart';
import 'package:parley_android/screens/design_system/catalog/surface_stories.dart';

export 'package:parley_android/screens/design_system/catalog/story.dart';

/// Every component in `lib/design_system/`, with the usages worth seeing side
/// by side.
///
/// The categories and their order match
/// `docs/references/design-system-reference-llms.txt`, so a component sits in
/// the same place in the gallery as in the reference — and
/// `test/screens/design_system_gallery_test.dart` fails if the two ever hold
/// different sets of components. That test is what stops this file becoming a
/// list of the widgets somebody remembered.
final designSystemCatalog = <DSCatalogCategory>[
  foundationCategory,
  actionCategory,
  inputCategory,
  navigationCategory,
  overlayCategory,
  surfaceCategory,
  structureCategory,
  stateCategory,
];

/// Every component in the catalog, flattened, in category order.
final catalogComponents = <DSComponentDemo>[
  for (final category in designSystemCatalog) ...category.components,
];

final Map<String, DSComponentDemo> _byName = {
  for (final component in catalogComponents) component.name: component,
};

/// The component a route’s `:name` parameter refers to, or null when the path
/// names something the kit does not ship.
DSComponentDemo? componentDemoNamed(String name) => _byName[name];

/// The category a component belongs to, for the eyebrow on its page.
String categoryOf(DSComponentDemo component) => designSystemCatalog
    .firstWhere((category) => category.components.contains(component))
    .name;
