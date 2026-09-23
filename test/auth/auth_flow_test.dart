import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/services/auth/token_store.dart';

/// Exercises the auth state machine end-to-end against the mock service.
void main() {
  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(InMemoryTokenStore())],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Forces the notifier to construct (so its async restore() starts), then
  /// waits for the boot status to resolve away from `unknown`.
  Future<void> settleBoot(ProviderContainer container) async {
    container.read(authProvider.notifier);
    for (
      var i = 0;
      i < 50 && container.read(authProvider).status == AuthStatus.unknown;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('starts unauthenticated when the token store is empty', () async {
    final container = makeContainer();
    await settleBoot(container);
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
  });

  test('sign-in with the demo account authenticates the session', () async {
    final container = makeContainer();
    final ok = await container
        .read(authProvider.notifier)
        .signIn(email: 'demo@rocketship.dev', password: 'password');

    expect(ok, isTrue);
    final state = container.read(authProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.session?.user.email, 'demo@rocketship.dev');
    expect(container.read(currentUserProvider), isNotNull);
  });

  test('wrong password leaves the user signed out with an error', () async {
    final container = makeContainer();
    final ok = await container
        .read(authProvider.notifier)
        .signIn(email: 'demo@rocketship.dev', password: 'wrong');

    expect(ok, isFalse);
    final state = container.read(authProvider);
    expect(state.isAuthenticated, isFalse);
    expect(state.error, isNotNull);
  });

  test('sign-up registers and authenticates a new account', () async {
    final container = makeContainer();
    final ok = await container
        .read(authProvider.notifier)
        .signUp(
          email: 'new.user@example.com',
          password: 'longenough',
          displayName: 'New User',
        );

    expect(ok, isTrue);
    expect(container.read(authProvider).isAuthenticated, isTrue);
  });

  test('sign-out returns to the unauthenticated state', () async {
    final container = makeContainer();
    await container
        .read(authProvider.notifier)
        .signIn(email: 'demo@rocketship.dev', password: 'password');
    expect(container.read(authProvider).isAuthenticated, isTrue);

    await container.read(authProvider.notifier).signOut();
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
  });

  test('the session persists to the token store across a cold start', () async {
    final store = InMemoryTokenStore();
    final first = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(store)],
    );
    await first
        .read(authProvider.notifier)
        .signIn(email: 'demo@rocketship.dev', password: 'password');
    first.dispose();

    // New container, same store == a fresh launch.
    final second = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(store)],
    );
    addTearDown(second.dispose);
    await settleBoot(second);
    expect(second.read(authProvider).isAuthenticated, isTrue);
  });
}
