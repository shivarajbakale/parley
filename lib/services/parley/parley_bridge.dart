import 'package:parley_android/models/parley.dart';

/// Everything the Flutter screens can ask of the native core.
///
/// One method per entry in `docs/plans/bridge-contract.md`. Screens and
/// providers depend on this interface; `ServiceConfig.createParleyBridge`
/// decides whether they get the platform channel or the in-memory fake.
abstract interface class ParleyBridge {
  Future<ParleyStatus> getStatus();
  Future<ParleyStatus> setPaused(bool paused);
  Future<void> openSystemSettings(SystemSettingsTarget target);
  Future<bool> requestMicPermission();

  /// Checks one key with the provider without saving it.
  Future<KeyCheck> verifyKey(String provider, String key);

  /// Verifies every non-empty key, then saves them all or none. An empty
  /// [minimax] removes the stored MiniMax key.
  Future<KeyCheck> setKeys({String? groq, String? minimax});

  Future<ParleyConfig> getConfig();
  Future<ParleyConfig> setConfig(String key, Object? value);
  Future<UsageSummary> getUsageSummary();

  Future<List<HistoryEntry>> listHistory({
    int offset = 0,
    int limit = 50,
    String? query,
    HistoryFilter filter = HistoryFilter.all,
  });
  Future<HistoryEntry?> getHistoryEntry(int id);

  /// Deletes one entry, or every entry when [id] is null. Returns the count.
  Future<int> deleteHistory({int? id});

  /// Puts a deleted entry back — the undo on the History snack bar.
  Future<int> restoreHistory(HistoryEntry entry);

  /// Status changes pushed by the service.
  Stream<ParleyStatus> get statusChanges;

  /// Each entry the service writes, as it is written.
  Stream<HistoryEntry> get historyAdded;
}
