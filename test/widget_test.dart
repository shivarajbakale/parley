import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/app.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/services/parley/fake_parley_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot(
    WidgetTester tester, {
    required bool setupDone,
    required FakeParleyBridge bridge,
  }) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': setupDone});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          parleyBridgeProvider.overrideWithValue(bridge),
        ],
        child: const RocketshipApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('App smoke test — a finished setup boots to a ready Overview', (
    tester,
  ) async {
    await boot(tester, setupDone: true, bridge: FakeParleyBridge.ready());

    expect(find.text('Parley'), findsWidgets);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('History'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('a first launch boots into Setup', (tester) async {
    await boot(tester, setupDone: false, bridge: FakeParleyBridge());

    expect(find.text('Set up Parley'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('with the service off, Overview says so and offers the fix', (
    tester,
  ) async {
    final bridge = FakeParleyBridge(
      status: const ParleyStatus(micGranted: true, groqKeySet: true),
    );
    await boot(tester, setupDone: true, bridge: bridge);

    expect(find.text('Off'), findsOneWidget);
    await tester.tap(find.text('Open Accessibility settings'));
    await tester.pumpAndSettle();
    expect(bridge.openedSettings, [SystemSettingsTarget.accessibility]);
  });
}
