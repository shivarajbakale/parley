import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/app.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/services/parley/fake_parley_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parley's first run: the Setup sequence replaces the template's welcome
/// and tour. `onboarding_complete` is the one flag; the router sends every
/// location to `/setup` until it is set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pump(
    WidgetTester tester,
    FakeParleyBridge bridge, {
    bool setupDone = false,
  }) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': setupDone});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        parleyBridgeProvider.overrideWithValue(bridge),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RocketshipApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('a fresh install walks all six steps and lands on Overview', (
    tester,
  ) async {
    final bridge = FakeParleyBridge();
    final container = await pump(tester, bridge);

    expect(find.text('Talk, and it types — in any app'), findsOneWidget);
    await tapText(tester, 'Get started');

    // Key: rejected first, then accepted.
    expect(find.text('Your Groq key'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, 'gsk_bad_key_123');
    await tester.pumpAndSettle();
    await tapText(tester, 'Check key');
    expect(find.text('Invalid API Key'), findsOneWidget);
    expect(find.text('Your Groq key'), findsOneWidget);
    await tester.enterText(
      find.byType(EditableText).first,
      'gsk_good_key_1234',
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'Check key');

    // Microphone: granting it advances on its own.
    expect(find.text('Microphone'), findsOneWidget);
    await tapText(tester, 'Allow microphone');

    // Accessibility: opens system settings, then the grant arrives as an
    // event and the step advances on its own.
    expect(find.text('Turn on Parley in Accessibility'), findsOneWidget);
    await tapText(tester, 'Open Accessibility settings');
    expect(bridge.openedSettings, [SystemSettingsTarget.accessibility]);
    bridge.simulate((await bridge.getStatus()).copyWith(serviceBound: true));
    await tester.pumpAndSettle();
    expect(find.text('Keep Parley running'), findsOneWidget);

    // Battery is advice, not a gate.
    await tapText(tester, 'Not now');
    expect(find.text('Try it'), findsOneWidget);
    await tapText(tester, 'Skip for now');

    expect(find.text('Ready'), findsOneWidget);
    expect(container.read(settingsProvider).onboardingComplete, isTrue);
  });

  testWidgets('Back keeps a typed key', (tester) async {
    await pump(tester, FakeParleyBridge());
    await tapText(tester, 'Get started');
    await tester.enterText(find.byType(EditableText).first, 'gsk_typed_12345');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Talk, and it types — in any app'), findsOneWidget);
    await tapText(tester, 'Get started');
    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(field.controller.text, 'gsk_typed_12345');
  });

  testWidgets('a returning user with grants in place resumes at the gap', (
    tester,
  ) async {
    final bridge = FakeParleyBridge(
      status: const ParleyStatus(groqKeySet: true, micGranted: true),
    );
    await pump(tester, bridge);
    expect(find.text('Turn on Parley in Accessibility'), findsOneWidget);
  });

  testWidgets('a finished setup never shows Setup again on its own', (
    tester,
  ) async {
    await pump(tester, FakeParleyBridge.ready(), setupDone: true);
    expect(find.text('Set up Parley'), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
  });
}
