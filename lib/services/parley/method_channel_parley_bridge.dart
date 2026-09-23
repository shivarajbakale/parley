import 'package:flutter/services.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/services/parley/parley_bridge.dart';

/// [ParleyBridge] over the `parley/bridge` and `parley/events` channels that
/// `MainActivity` registers. Shapes: `docs/plans/bridge-contract.md`.
class MethodChannelParleyBridge implements ParleyBridge {
  MethodChannelParleyBridge({
    MethodChannel channel = const MethodChannel('parley/bridge'),
    EventChannel events = const EventChannel('parley/events'),
  }) : _channel = channel,
       _events = events;

  final MethodChannel _channel;
  final EventChannel _events;

  late final Stream<Map<Object?, Object?>> _eventStream = _events
      .receiveBroadcastStream()
      .where((e) => e is Map)
      .cast<Map<Object?, Object?>>()
      .asBroadcastStream();

  Future<Map<Object?, Object?>> _map(String method, [Object? args]) async =>
      (await _channel.invokeMapMethod<Object?, Object?>(method, args)) ??
      const {};

  @override
  Future<ParleyStatus> getStatus() async =>
      ParleyStatus.fromMap(await _map('getStatus'));

  @override
  Future<ParleyStatus> setPaused(bool paused) async =>
      ParleyStatus.fromMap(await _map('setPaused', {'paused': paused}));

  @override
  Future<void> openSystemSettings(SystemSettingsTarget target) => _channel
      .invokeMethod<void>('openSystemSettings', {'target': target.name});

  @override
  Future<bool> requestMicPermission() async =>
      await _channel.invokeMethod<bool>('requestMicPermission') ?? false;

  @override
  Future<KeyCheck> verifyKey(String provider, String key) async {
    final result = await _map('verifyKey', {'provider': provider, 'key': key});
    return result['ok'] == true
        ? const KeyCheck(ok: true)
        : KeyCheck(
            ok: false,
            errors: {provider: result['message'] as String? ?? 'Key rejected'},
          );
  }

  @override
  Future<KeyCheck> setKeys({String? groq, String? minimax}) async =>
      KeyCheck.fromMap(
        await _map('setKeys', {
          if (groq != null) 'groq': groq,
          if (minimax != null) 'minimax': minimax,
        }),
      );

  @override
  Future<ParleyConfig> getConfig() async =>
      ParleyConfig.fromMap(await _map('getConfig'));

  @override
  Future<ParleyConfig> setConfig(String key, Object? value) async =>
      ParleyConfig.fromMap(
        await _map('setConfig', {'key': key, 'value': value}),
      );

  @override
  Future<UsageSummary> getUsageSummary() async =>
      UsageSummary.fromMap(await _map('getUsageSummary'));

  @override
  Future<List<HistoryEntry>> listHistory({
    int offset = 0,
    int limit = 50,
    String? query,
    HistoryFilter filter = HistoryFilter.all,
  }) async {
    final rows =
        await _channel.invokeListMethod<Object?>('listHistory', {
          'offset': offset,
          'limit': limit,
          'query': (query == null || query.isEmpty) ? null : query,
          'filter': filter.name,
        }) ??
        const [];
    return [
      for (final row in rows.whereType<Map<Object?, Object?>>())
        HistoryEntry.fromMap(row),
    ];
  }

  @override
  Future<HistoryEntry?> getHistoryEntry(int id) async {
    final row = await _channel.invokeMapMethod<Object?, Object?>(
      'getHistoryEntry',
      {'id': id},
    );
    return row == null ? null : HistoryEntry.fromMap(row);
  }

  @override
  Future<int> deleteHistory({int? id}) async =>
      await _channel.invokeMethod<int>('deleteHistory', {'id': id}) ?? 0;

  @override
  Future<int> restoreHistory(HistoryEntry entry) async =>
      await _channel.invokeMethod<int>('restoreHistory', {
        'entry': entry.toMap(),
      }) ??
      entry.id;

  @override
  Stream<ParleyStatus> get statusChanges => _eventStream
      .where((e) => e['type'] == 'status' && e['status'] is Map)
      .map((e) => ParleyStatus.fromMap(e['status']! as Map<Object?, Object?>));

  @override
  Stream<HistoryEntry> get historyAdded => _eventStream
      .where((e) => e['type'] == 'history' && e['entry'] is Map)
      .map((e) => HistoryEntry.fromMap(e['entry']! as Map<Object?, Object?>));
}
