import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_router.dart';

class RocketshipApp extends ConsumerWidget {
  const RocketshipApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider).themeMode;
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Parley',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      // Routing + auth gating + deep links all live in app_router.dart.
      routerConfig: router,
      // The single line that decides what this app looks like.
      //
      // `Design` hands `AppTheme.spec` to every widget below it, and the
      // theme above is built from the same value — so a different spec here
      // changes the colour, type, shape, spacing, elevation, motion, chrome
      // material and component idioms together, and nothing downstream is
      // edited. Sitting inside `builder` rather than around `MaterialApp` is
      // deliberate: below this point a `Theme` exists, which is what
      // `context.palette` reads the ambient brightness from.
      builder: (context, child) => Design(
        spec: AppTheme.spec,
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
      ),
    );
  }
}
