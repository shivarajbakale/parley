import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/providers/observability_provider.dart';
import 'package:parley_android/services/purchases/purchase_models.dart';
import 'package:parley_android/services/purchases/purchases_service.dart';
import 'package:parley_android/services/service_config.dart';

final purchasesServiceProvider = Provider<PurchasesService>((ref) {
  return ServiceConfig.createPurchasesService();
});

class PurchasesState {
  final Set<String> entitlements;
  final List<Offering> offerings;
  final bool loadingOfferings;
  final bool purchasing;
  final String? error;

  const PurchasesState({
    this.entitlements = const {},
    this.offerings = const [],
    this.loadingOfferings = false,
    this.purchasing = false,
    this.error,
  });

  bool get isPro => entitlements.contains(kProEntitlement);

  PurchasesState copyWith({
    Set<String>? entitlements,
    List<Offering>? offerings,
    bool? loadingOfferings,
    bool? purchasing,
    Object? error = _sentinel,
  }) {
    return PurchasesState(
      entitlements: entitlements ?? this.entitlements,
      offerings: offerings ?? this.offerings,
      loadingOfferings: loadingOfferings ?? this.loadingOfferings,
      purchasing: purchasing ?? this.purchasing,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

class PurchasesNotifier extends StateNotifier<PurchasesState> {
  final Ref _ref;
  PurchasesService get _service => _ref.read(purchasesServiceProvider);

  PurchasesNotifier(this._ref) : super(const PurchasesState()) {
    hydrate();
  }

  /// Loads active entitlements on launch so gating is correct immediately.
  Future<void> hydrate() async {
    final active = await _service.activeEntitlements();
    state = state.copyWith(entitlements: active);
  }

  /// Loads the offerings to show on the paywall.
  Future<void> loadOfferings() async {
    state = state.copyWith(loadingOfferings: true, error: null);
    try {
      final offerings = await _service.offerings();
      state = state.copyWith(offerings: offerings, loadingOfferings: false);
    } catch (error, stack) {
      _ref.read(crashReporterProvider).recordError(error, stack);
      state = state.copyWith(
        loadingOfferings: false,
        error: 'Could not load plans. Please try again.',
      );
    }
  }

  /// Returns true if the user is now entitled.
  Future<bool> purchase(PurchasePackage package) async {
    state = state.copyWith(purchasing: true, error: null);
    _ref
        .read(analyticsProvider)
        .event('purchase_started', properties: {'package': package.id});
    try {
      final active = await _service.purchase(package);
      state = state.copyWith(entitlements: active, purchasing: false);
      _ref
          .read(analyticsProvider)
          .event('purchase_completed', properties: {'package': package.id});
      return state.isPro;
    } on PurchaseCancelledException {
      state = state.copyWith(purchasing: false);
      return false;
    } catch (error, stack) {
      _ref.read(crashReporterProvider).recordError(error, stack);
      state = state.copyWith(
        purchasing: false,
        error: 'Purchase failed. Please try again.',
      );
      return false;
    }
  }

  /// Restores prior purchases (required by the App Store).
  Future<bool> restore() async {
    state = state.copyWith(purchasing: true, error: null);
    try {
      final active = await _service.restore();
      state = state.copyWith(entitlements: active, purchasing: false);
      return state.isPro;
    } catch (error, stack) {
      _ref.read(crashReporterProvider).recordError(error, stack);
      state = state.copyWith(
        purchasing: false,
        error: 'Could not restore purchases.',
      );
      return false;
    }
  }
}

final purchasesProvider =
    StateNotifierProvider<PurchasesNotifier, PurchasesState>((ref) {
      return PurchasesNotifier(ref);
    });

/// The one-liner most feature code needs: `if (ref.watch(isProProvider)) ...`.
final isProProvider = Provider<bool>((ref) {
  return ref.watch(purchasesProvider).isPro;
});
