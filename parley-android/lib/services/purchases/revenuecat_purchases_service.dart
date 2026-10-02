import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:parley_android/services/purchases/purchase_models.dart';
import 'package:parley_android/services/purchases/purchases_service.dart';

/// Real [PurchasesService] backed by RevenueCat. Activated by `ServiceConfig`
/// when `Env.hasRevenueCat` is true (`REVENUECAT_API_KEY` via `--dart-define`).
/// `main.dart` calls `Purchases.configure` first.
///
/// IMPORTANT: name your RevenueCat entitlement `pro` (== [kProEntitlement]) so
/// `isProProvider` lights up. Configure products in App Store Connect / Play
/// Console + RevenueCat. Returns are re-derived from `getCustomerInfo()` so
/// this is robust across purchases_flutter return-type changes.
class RevenueCatPurchasesService implements PurchasesService {
  @override
  Future<List<Offering>> offerings() async {
    final offerings = await rc.Purchases.getOfferings();
    return offerings.all.values
        .map(
          (o) => Offering(
            id: o.identifier,
            packages: o.availablePackages
                .map(
                  (p) => PurchasePackage(
                    id: p.identifier,
                    priceString: p.storeProduct.priceString,
                    title: p.storeProduct.title,
                    description: p.storeProduct.description,
                    period: _period(p.packageType),
                    highlighted: p.packageType == rc.PackageType.annual,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Future<Set<String>> purchase(PurchasePackage package) async {
    try {
      final offerings = await rc.Purchases.getOfferings();
      final rcPackage = offerings.all.values
          .expand((o) => o.availablePackages)
          .firstWhere((p) => p.identifier == package.id);
      final result = await rc.Purchases.purchase(
        rc.PurchaseParams.package(rcPackage),
      );
      return result.customerInfo.entitlements.active.keys.toSet();
    } on PlatformException catch (e) {
      final code = rc.PurchasesErrorHelper.getErrorCode(e);
      if (code == rc.PurchasesErrorCode.purchaseCancelledError) {
        throw const PurchaseCancelledException();
      }
      throw PurchaseFailedException(e.message ?? 'Purchase failed.');
    }
  }

  @override
  Future<Set<String>> restore() async {
    await rc.Purchases.restorePurchases();
    return activeEntitlements();
  }

  @override
  Future<Set<String>> activeEntitlements() async {
    final info = await rc.Purchases.getCustomerInfo();
    return info.entitlements.active.keys.toSet();
  }

  @override
  Future<void> setUserId(String? userId) async {
    if (userId == null) {
      await rc.Purchases.logOut();
    } else {
      await rc.Purchases.logIn(userId);
    }
  }

  String _period(rc.PackageType type) => switch (type) {
    rc.PackageType.monthly => 'month',
    rc.PackageType.annual => 'year',
    rc.PackageType.weekly => 'week',
    rc.PackageType.lifetime => 'lifetime',
    _ => 'plan',
  };
}
