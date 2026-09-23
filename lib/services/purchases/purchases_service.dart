import 'package:parley_android/services/purchases/purchase_models.dart';

/// In-app-purchase / subscription seam.
///
/// The boilerplate ships [MockPurchasesService] so the paywall, purchase
/// flow, and `pro` gating all work without store credentials. To go live,
/// add `purchases_flutter` (RevenueCat) and implement this interface:
///
/// - [offerings] → `Purchases.getOfferings()`
/// - [purchase]  → `Purchases.purchasePackage(pkg)`
/// - [restore]   → `Purchases.restorePurchases()`
/// - [activeEntitlements] → read `CustomerInfo.entitlements.active`
///
/// Then return it from `ServiceConfig.createPurchasesService()`. The paywall
/// UI and `isProProvider` never reference the SDK directly.
abstract interface class PurchasesService {
  /// Loads the offerings to render on the paywall.
  Future<List<Offering>> offerings();

  /// Buys a package. Returns the set of entitlement ids now active.
  /// Throws [PurchaseCancelledException] if the user dismisses the sheet.
  Future<Set<String>> purchase(PurchasePackage package);

  /// Restores prior purchases (App Store requirement). Returns active ids.
  Future<Set<String>> restore();

  /// Current active entitlement ids — called on launch to hydrate state.
  Future<Set<String>> activeEntitlements();

  /// Associates purchases with a user id (call after sign-in).
  Future<void> setUserId(String? userId);
}

/// Thrown when the user backs out of the native purchase sheet. The UI
/// should treat this as a no-op, not an error toast.
class PurchaseCancelledException implements Exception {
  const PurchaseCancelledException();
  @override
  String toString() => 'PurchaseCancelledException';
}

/// Thrown when a purchase fails for any other reason.
class PurchaseFailedException implements Exception {
  final String message;
  const PurchaseFailedException([
    this.message = 'Purchase failed. Please try again.',
  ]);
  @override
  String toString() => 'PurchaseFailedException: $message';
}
