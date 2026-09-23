/// Barrel for the integration seams. Each seam is an interface with a
/// mock/console default; swap to a real backend in `service_config.dart`.
///
/// See `docs/MODULES.md` for the per-seam go-live checklist.
library;

export 'service_config.dart';
export 'auth/auth_models.dart';
export 'auth/auth_service.dart';
export 'auth/token_store.dart';
export 'observability/analytics.dart';
export 'observability/crash_reporter.dart';
export 'purchases/purchase_models.dart';
export 'purchases/purchases_service.dart';
