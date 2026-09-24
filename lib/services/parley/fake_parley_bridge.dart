import 'dart:async';

import 'package:parley_android/models/parley.dart';
import 'package:parley_android/services/parley/parley_bridge.dart';

/// An in-memory [ParleyBridge] — the offline seam the rest of the template
/// gets from `http_mock_adapter`. Widget tests, goldens, the UI probe and a
/// `flutter run` on a desktop or an emulator without the service all get
/// this, so every screen renders with no native core behind it.
///
/// It keeps the contract's rules rather than just its shapes: keys are
/// verified before they are saved (a key containing `bad` is rejected), only
/// the last four characters come back, and saved time uses the same formula
/// as the native store.
class FakeParleyBridge implements ParleyBridge {
  FakeParleyBridge({
    ParleyStatus status = const ParleyStatus(),
    ParleyConfig config = const ParleyConfig(),
    List<HistoryEntry>? history,
    DateTime? now,
    this.latency = Duration.zero,
  }) : _status = status,
       _config = config,
       _now = now ?? DateTime.now() {
    _history = history ?? seededHistory(_now);
  }

  /// A bridge in the state a finished setup leaves behind.
  factory FakeParleyBridge.ready({
    List<HistoryEntry>? history,
    DateTime? now,
  }) => FakeParleyBridge(
    status: const ParleyStatus(
      serviceBound: true,
      micGranted: true,
      batteryUnrestricted: true,
      groqKeySet: true,
      minimaxKeySet: true,
    ),
    config: const ParleyConfig(groqKeyLast4: 'x7Qa', minimaxKeyLast4: '93fd'),
    history: history,
    now: now,
  );

  final Duration latency;
  final DateTime _now;
  ParleyStatus _status;
  ParleyConfig _config;
  late List<HistoryEntry> _history;

  final _statusController = StreamController<ParleyStatus>.broadcast();
  final _historyController = StreamController<HistoryEntry>.broadcast();

  /// Calls to [openSystemSettings], newest last — tests assert on it.
  final List<SystemSettingsTarget> openedSettings = [];

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  void _emit(ParleyStatus next) {
    if (next == _status) return;
    _status = next;
    _statusController.add(next);
  }

  /// Lets a test or the demo stand in for the system: the user came back from
  /// Accessibility settings having switched Parley on, and so on.
  void simulate(ParleyStatus next) => _emit(next);

  /// Stands in for the service writing a new entry.
  void simulateEntry(HistoryEntry entry) {
    _history = [entry, ..._history];
    _historyController.add(entry);
  }

  @override
  Future<ParleyStatus> getStatus() async {
    await _wait();
    return _status;
  }

  @override
  Future<ParleyStatus> setPaused(bool paused) async {
    await _wait();
    _emit(_status.copyWith(paused: paused));
    return _status;
  }

  @override
  Future<void> openSystemSettings(SystemSettingsTarget target) async {
    openedSettings.add(target);
  }

  @override
  Future<bool> requestMicPermission() async {
    await _wait();
    _emit(_status.copyWith(micGranted: true));
    return true;
  }

  String? _problemWith(String key) {
    if (key.trim().length < 8) return 'That key is too short.';
    if (key.contains('bad')) return 'Invalid API Key';
    return null;
  }

  @override
  Future<KeyCheck> verifyKey(String provider, String key) async {
    await _wait();
    final problem = _problemWith(key);
    return problem == null
        ? const KeyCheck(ok: true)
        : KeyCheck(ok: false, errors: {provider: problem});
  }

  @override
  Future<KeyCheck> setKeys({
    String? groq,
    String? minimax,
    String? deepgram,
  }) async {
    await _wait();
    final errors = <String, String>{
      if (groq != null && groq.isNotEmpty && _problemWith(groq) != null)
        'groq': _problemWith(groq)!,
      if (deepgram != null &&
          deepgram.isNotEmpty &&
          _problemWith(deepgram) != null)
        'deepgram': _problemWith(deepgram)!,
      if (minimax != null &&
          minimax.isNotEmpty &&
          _problemWith(minimax) != null)
        'minimax': _problemWith(minimax)!,
    };
    if (errors.isNotEmpty) return KeyCheck(ok: false, errors: errors);
    String last4(String k) => k.substring(k.length - 4);
    var config = _config;
    var status = _status;
    if (groq != null && groq.isNotEmpty) {
      config = config.withValue('groqKeyLast4', last4(groq));
      status = status.copyWith(groqKeySet: true);
    }
    if (deepgram != null) {
      config = config.withValue(
        'deepgramKeyLast4',
        deepgram.isEmpty ? null : last4(deepgram),
      );
      status = status.copyWith(deepgramKeySet: deepgram.isNotEmpty);
    }
    if (minimax != null) {
      config = config.withValue(
        'minimaxKeyLast4',
        minimax.isEmpty ? null : last4(minimax),
      );
      status = status.copyWith(minimaxKeySet: minimax.isNotEmpty);
    }
    _config = config;
    _emit(status);
    return const KeyCheck(ok: true);
  }

  @override
  Future<ParleyConfig> setTranscriptionProvider(
    TranscriptionProvider provider,
  ) => setConfig('transcriptionProvider', provider.name);

  @override
  Future<ParleyConfig> getConfig() async {
    await _wait();
    return _config;
  }

  @override
  Future<ParleyConfig> setConfig(String key, Object? value) async {
    await _wait();
    _config = _config.withValue(key, value);
    if (key == 'orbEnabled' ||
        key == 'volumeGestureEnabled' ||
        key == 'transcriptionProvider') {
      _emit(
        _status.copyWith(
          orbEnabled: _config.orbEnabled,
          volumeGestureEnabled: _config.volumeGestureEnabled,
          transcriptionProvider: _config.transcriptionProvider,
        ),
      );
    }
    return _config;
  }

  @override
  Future<UsageSummary> getUsageSummary() async {
    await _wait();
    final weekAgo = _now.subtract(const Duration(days: 7));
    final week = _history.where((e) => e.createdAt.isAfter(weekAgo));
    return UsageSummary(
      weekWords: week.fold(0, (sum, e) => sum + e.wordCount),
      weekSavedMs: week.fold(0, (sum, e) => sum + e.savedMs),
      lastEntry: _history.isEmpty ? null : _history.first,
    );
  }

  @override
  Future<List<HistoryEntry>> listHistory({
    int offset = 0,
    int limit = 50,
    String? query,
    HistoryFilter filter = HistoryFilter.all,
  }) async {
    await _wait();
    final q = query?.trim().toLowerCase() ?? '';
    return _history
        .where((e) => e.matches(filter))
        .where(
          (e) =>
              q.isEmpty ||
              e.text.toLowerCase().contains(q) ||
              (e.instruction?.toLowerCase().contains(q) ?? false),
        )
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<HistoryEntry?> getHistoryEntry(int id) async {
    await _wait();
    for (final e in _history) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<int> deleteHistory({int? id}) async {
    await _wait();
    final before = _history.length;
    _history = id == null ? [] : _history.where((e) => e.id != id).toList();
    return before - _history.length;
  }

  @override
  Future<int> restoreHistory(HistoryEntry entry) async {
    await _wait();
    _history = [..._history, entry]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entry.id;
  }

  @override
  Stream<ParleyStatus> get statusChanges => _statusController.stream;

  @override
  Stream<HistoryEntry> get historyAdded => _historyController.stream;

  /// A believable week of use, anchored to [now] so "Today" and "Yesterday"
  /// group headers are stable in goldens.
  static List<HistoryEntry> seededHistory(DateTime now) {
    HistoryEntry dictation(
      int id,
      Duration ago,
      String text,
      String app,
      String package, {
      InsertMethod method = InsertMethod.setText,
    }) {
      final words = HistoryEntry.wordCountOf(text);
      final recordingMs = 1200 + words * 330;
      return HistoryEntry(
        id: id,
        createdAt: now.subtract(ago),
        mode: ParleyMode.dictation,
        text: text,
        appPackage: package,
        appLabel: app,
        insertMethod: method,
        recordingMs: recordingMs,
        wordCount: words,
        savedMs: HistoryEntry.savedMsFor(
          wordCount: words,
          recordingMs: recordingMs,
        ),
      );
    }

    const before =
        'The kitchen tap has been dripping again since last week and honestly '
        'it is getting really annoying because it keeps me up at night.';
    const after =
        'Hi Ravi — the kitchen tap is dripping again. Could someone take a '
        'look this week? Thanks so much.';

    return [
      dictation(
        12,
        const Duration(minutes: 20),
        'Running ten minutes late, start without me.',
        'WhatsApp',
        'com.whatsapp',
      ),
      HistoryEntry(
        id: 11,
        createdAt: now.subtract(const Duration(minutes: 49)),
        mode: ParleyMode.edit,
        text: after,
        instruction: 'Make it friendlier and shorter.',
        beforeText: before,
        appPackage: 'com.google.android.gm',
        appLabel: 'Gmail',
        insertMethod: InsertMethod.setText,
        recordingMs: 2100,
        wordCount: HistoryEntry.wordCountOf(after),
        savedMs: HistoryEntry.savedMsFor(
          wordCount: HistoryEntry.wordCountOf(after),
          recordingMs: 2100,
        ),
      ),
      dictation(
        10,
        const Duration(hours: 1, minutes: 31),
        'Pick up milk, eggs and the dry cleaning on the way home.',
        'Keep',
        'com.google.android.keep',
      ),
      dictation(
        9,
        const Duration(hours: 20),
        'Can we move standup to 10:30 tomorrow?',
        'Chrome',
        'com.android.chrome',
        method: InsertMethod.clipboardOnly,
      ),
      dictation(
        8,
        const Duration(hours: 26),
        'Happy birthday! Hope the trip is amazing and the weather holds up.',
        'Messages',
        'com.google.android.apps.messaging',
      ),
      dictation(
        7,
        const Duration(days: 2, hours: 3),
        'I have pushed the fix for the login bug, it should be in the next '
            'build. Let me know if you still see the spinner.',
        'Slack',
        'com.Slack',
        method: InsertMethod.paste,
      ),
      dictation(
        6,
        const Duration(days: 3, hours: 5),
        'Table for four at eight on Friday, please. Outside if possible.',
        'WhatsApp',
        'com.whatsapp',
      ),
      dictation(
        5,
        const Duration(days: 5),
        'Reminder to renew the car insurance before the fifteenth.',
        'Keep',
        'com.google.android.keep',
      ),
    ];
  }
}
