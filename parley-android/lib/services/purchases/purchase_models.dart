/// The entitlement that unlocks paid features. One string keeps gating
/// trivial: `ref.watch(isProProvider)`. Add more ids if you sell tiers.
const String kProEntitlement = 'pro';

/// A purchasable plan inside an [Offering]. Maps onto a RevenueCat
/// `Package` / StoreKit `Product` / Play `ProductDetails`.
class PurchasePackage {
  final String id;

  /// Store-localized price, e.g. "$4.99". Always display this, never a raw
  /// number — the store formats currency per region.
  final String priceString;

  final String title;
  final String description;

  /// Billing period label for the UI ("month", "year", "lifetime").
  final String period;

  /// Marketing flag so the UI can badge the best-value plan.
  final bool highlighted;

  const PurchasePackage({
    required this.id,
    required this.priceString,
    required this.title,
    required this.description,
    required this.period,
    this.highlighted = false,
  });
}

/// A set of packages presented together on the paywall. RevenueCat calls
/// this the "current offering".
class Offering {
  final String id;
  final List<PurchasePackage> packages;
  const Offering({required this.id, required this.packages});
}
