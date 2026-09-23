import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parley_android/app.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/services/auth/auth_models.dart';
import 'package:parley_android/services/auth/token_store.dart';

/// A pre-seeded token store so the app boots straight past the auth gate into
/// the home screen. Tests that exercise the unauthenticated flow seed an empty
/// store instead (see auth/auth_flow_test.dart).
InMemoryTokenStore _authenticatedStore() => InMemoryTokenStore(
  const AuthSession(
    user: AuthUser(
      id: 'usr_test',
      email: 'test@rocketship.dev',
      displayName: 'Test User',
    ),
    accessToken: 'test_token',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'App smoke test — boots through the auth gate to the home screen',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            tokenStoreProvider.overrideWithValue(_authenticatedStore()),
          ],
          child: const RocketshipApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rocketship'), findsWidgets);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
    },
  );

  testWidgets('Unauthenticated boot shows the sign-in screen', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
        child: const RocketshipApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });
}
