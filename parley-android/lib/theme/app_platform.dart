import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Which side of the platform divide a build is rendering for.
///
/// Two sides, not seven targets. Chrome, geometry and motion differ between
/// Apple's platforms and everything else; nothing in this app needs to tell
/// Windows from Linux.
enum AppPlatformSide {
  /// iOS and macOS: Liquid Glass chrome, continuous corners, ease curves.
  apple,

  /// Android and every other target, including the web: tonal chrome,
  /// circular corners at the larger Material 3 radii, spring physics.
  material,
}

/// The one place the app asks what platform it is on.
///
/// See `docs/principles/platform-adaptivity.md`. The rule that file states:
/// branch for chrome, geometry and motion; never for structure, content or
/// behaviour. This class exists so that branch is a single greppable call
/// rather than `Platform.isIOS` scattered through the widget tree.
///
/// Everything here reads [ThemeData.platform] rather than `dart:io`. That
/// matters twice: `dart:io` does not compile for web, and it reports the
/// *device* rather than the *theme*, so it ignores a `TargetPlatform`
/// override — which is exactly the seam every widget test and every golden
/// uses to render both sides on one machine.
abstract final class AppPlatform {
  /// The side [context]'s theme is rendering for.
  static AppPlatformSide sideOf(BuildContext context) {
    // A browser is not an operating system. Safari on a Mac reports
    // `TargetPlatform.macOS`, and a superellipse in a browser window is a
    // costume rather than a native detail.
    if (kIsWeb) return AppPlatformSide.material;
    return sideOfTarget(Theme.of(context).platform);
  }

  /// The side a given [TargetPlatform] belongs to.
  ///
  /// Pure, so a test can check the mapping without pumping a widget.
  static AppPlatformSide sideOfTarget(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppPlatformSide.apple;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return AppPlatformSide.material;
    }
  }

  /// Whether this build should look like an Apple platform.
  static bool isApple(BuildContext context) =>
      sideOf(context) == AppPlatformSide.apple;

  /// Pick one of two values by platform.
  ///
  /// ```dart
  /// final blur = AppPlatform.select(context, cupertino: 24.0, material: 0.0);
  /// ```
  ///
  /// Both arms are evaluated, so keep them cheap — a shape, a colour, a
  /// number. Anything expensive belongs behind [isApple] and an `if`.
  static T select<T>(
    BuildContext context, {
    required T cupertino,
    required T material,
  }) => isApple(context) ? cupertino : material;

  // There is deliberately no `minTapTarget` here any more. It returned 44 on
  // Apple and 48 on Material, and `ComponentSpec.minTapTarget` returned 48
  // regardless — so the most safety-critical dimension in a touch interface
  // had two answers depending on which file you were reading. The spec is the
  // one that survived: it is where an identity can change the number, and 48
  // clears both vendor floors.
}
