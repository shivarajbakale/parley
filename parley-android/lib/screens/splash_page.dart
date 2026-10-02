import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_progress_indicator.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Shown while the persisted session is restored on cold start. The router's
/// redirect replaces it with the auth flow or the home screen as soon as auth
/// status resolves (and replays any pending deep link).
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final schemePalette = context.palette;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rocket_launch_rounded,
              size: context.design.component.glyphHero,
              color: schemePalette.primary,
            ),
            SizedBox(height: context.design.space.xl),
            SizedBox(
              width: context.design.component.iconSizeInline,
              height: context.design.component.iconSizeInline,
              child: const DSProgressIndicator.circular(),
            ),
          ],
        ),
      ),
    );
  }
}
