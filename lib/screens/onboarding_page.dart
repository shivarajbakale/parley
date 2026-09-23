import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/screens/onboarding_art.dart';

/// The three stops of the template's tour.
///
/// Public so the gates and the gallery read the same sequence the app shows:
/// `test/_screens.dart` mounts one surface per stop, and a story in the
/// catalog shows the component that draws them.
///
/// **Replace all three.** Each stop should be a thing the app *does* rather
/// than a quality it has, and the last one should hand over to something —
/// see `.claude/skills/add-tour/SKILL.md`.
final List<DSTourStop> onboardingStops = <DSTourStop>[
  DSTourStop(
    art: (bool active) => OnboardingListArt(active: active),
    headline: 'Welcome aboard',
    // Short on purpose. A slide's body has to fit beside its picture at 2.0x
    // text on a 320pt phone, and `ui-probe`'s `dual-axis` rule fails the tour
    // the moment it does not — see `.claude/skills/add-tour/SKILL.md`.
    body:
        'Everything you keep lives in one list. Replace this slide with what '
        'your app is for.',
  ),
  DSTourStop(
    art: (bool active) => OnboardingDetailArt(active: active),
    headline: 'Built to ship',
    body:
        'Auth, payments and analytics are wired in behind a mock you can flip '
        'to live in one place.',
  ),
  DSTourStop(
    art: (bool active) => OnboardingSetupArt(active: active),
    headline: 'Yours to make',
    body:
        'Sign in and the blanks fill in with your own details. Everything '
        'here is a pattern you own.',
  ),
];

/// First-run tour — the **Sequence** archetype
/// (`docs/principles/screen-archetypes.md`). Shown by the router until
/// `settings.onboardingComplete`.
///
/// Three stops, each doing one job: `brand`, then `trust`, then `activation`.
/// Naming the job is the cut a page count lets you skip — a fourth stop is
/// only worth its swipe if it does something none of these three do.
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key, this.initialStop = 0});

  /// Which stop to open on. Exists for the gates: `test/_screens.dart`
  /// registers one surface per stop, because a paged flow the probe only ever
  /// sees the first page of is a flow whose other pages are measured by
  /// nothing and pictured by nothing.
  final int initialStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> finish() async {
      await ref.read(settingsProvider.notifier).completeOnboarding();
      if (!context.mounted) return;
      // Replayed from Settings, this was pushed over the app and the redirect
      // will not move us off `?demo=1`, so the tour has to close itself. On a
      // cold launch there is nothing underneath and the router takes over.
      //
      // `Navigator`, not go_router's `context.pop()`: it pops a pushed
      // GoRoute the same way, and it does not assert when the tour is mounted
      // without a router — which is how every gate mounts it.
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    }

    return DSTour(
      stops: onboardingStops,
      initialStop: initialStop,
      onFinish: finish,
      // Kept, and it is a real decision. Dropping Skip is only honest when the
      // last stop hands over to something the user has to do anyway — this one
      // hands over to sign-in, which they can reach without reading three
      // slides.
      onSkip: finish,
      finishLabel: 'Get started',
    );
  }
}
