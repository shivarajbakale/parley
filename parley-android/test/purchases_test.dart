import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/providers/purchases_provider.dart';
import 'package:parley_android/services/purchases/purchase_models.dart';
import 'package:parley_android/services/purchases/purchases_service.dart';

/// A seam fake that fails every call — the pattern for testing error paths:
/// override the service provider with a fake, assert the notifier's error state.
class _FailingPurchasesService implements PurchasesService {
  @override
  Future<List<Offering>> offerings() async => throw Exception('network down');
  @override
  Future<Set<String>> activeEntitlements() async => const {};
  @override
  Future<Set<String>> purchase(PurchasePackage package) async =>
      throw Exception('network down');
  @override
  Future<Set<String>> restore() async => throw Exception('network down');
  @override
  Future<void> setUserId(String? userId) async {}
}

/// Verifies the paywall entitlement flow against the mock purchases service.
void main() {
  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('starts without the pro entitlement', () async {
    final container = makeContainer();
    await Future<void>.delayed(Duration.zero); // let hydrate() settle
    expect(container.read(isProProvider), isFalse);
  });

  test('loadOfferings exposes the offering packages', () async {
    final container = makeContainer();
    await container.read(purchasesProvider.notifier).loadOfferings();
    final offerings = container.read(purchasesProvider).offerings;
    expect(offerings, isNotEmpty);
    expect(offerings.first.packages, isNotEmpty);
  });

  test('purchasing a package unlocks pro', () async {
    final container = makeContainer();
    await container.read(purchasesProvider.notifier).loadOfferings();
    final pkg = container
        .read(purchasesProvider)
        .offerings
        .first
        .packages
        .first;

    final entitled = await container
        .read(purchasesProvider.notifier)
        .purchase(pkg);

    expect(entitled, isTrue);
    expect(container.read(isProProvider), isTrue);
  });

  test(
    'loadOfferings failure sets an error and leaves the paywall empty',
    () async {
      final container = ProviderContainer(
        overrides: [
          purchasesServiceProvider.overrideWithValue(
            _FailingPurchasesService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(purchasesProvider.notifier).loadOfferings();
      final state = container.read(purchasesProvider);

      expect(state.offerings, isEmpty);
      expect(
        state.error,
        isNotNull,
      ); // surfaced by the paywall's error fallback
      expect(container.read(isProProvider), isFalse);
    },
  );
}
