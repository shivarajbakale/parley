import 'package:parley_android/services/purchases/purchase_models.dart';
import 'package:parley_android/services/purchases/purchases_service.dart';

/// In-memory [PurchasesService] so the paywall and `pro` gating work without
/// store credentials. A "purchase" simply flips the [kProEntitlement] on for
/// the rest of the session.
///
/// Delete this once `purchases_flutter` (RevenueCat) is wired; only
/// `ServiceConfig.createPurchasesService` references it.
class MockPurchasesService implements PurchasesService {
  final Set<String> _active = {};
  static const _latency = Duration(milliseconds: 700);

  static const _offering = Offering(
    id: 'default',
    packages: [
      PurchasePackage(
        id: 'monthly',
        priceString: r'$4.99',
        title: 'Monthly',
        description: 'Billed every month. Cancel anytime.',
        period: 'month',
      ),
      PurchasePackage(
        id: 'annual',
        priceString: r'$29.99',
        title: 'Annual',
        description: 'Billed yearly — best value, ~50% off.',
        period: 'year',
        highlighted: true,
      ),
      PurchasePackage(
        id: 'lifetime',
        priceString: r'$79.99',
        title: 'Lifetime',
        description: 'One-time purchase. Yours forever.',
        period: 'lifetime',
      ),
    ],
  );

  @override
  Future<List<Offering>> offerings() async {
    await Future<void>.delayed(_latency);
    return const [_offering];
  }

  @override
  Future<Set<String>> purchase(PurchasePackage package) async {
    await Future<void>.delayed(_latency);
    _active.add(kProEntitlement);
    return Set.unmodifiable(_active);
  }

  @override
  Future<Set<String>> restore() async {
    await Future<void>.delayed(_latency);
    return Set.unmodifiable(_active);
  }

  @override
  Future<Set<String>> activeEntitlements() async => Set.unmodifiable(_active);

  @override
  Future<void> setUserId(String? userId) async {}
}
