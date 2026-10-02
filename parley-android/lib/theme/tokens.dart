export 'app_platform.dart';
export 'spec/design_spec.dart';
export 'app_theme.dart';
export 'app_typography.dart';

// `app_materials.dart` is deliberately NOT exported.
//
// Glass belongs to the chrome layer and nowhere else
// (docs/principles/depth-and-materials.md). A barrel export would let any
// widget reach it through `tokens.dart` without ever naming the file, which
// is exactly the bypass `ui_lint`'s `glass-off-chrome` rule exists to catch.
// The chrome components import it directly, by path, on purpose.
