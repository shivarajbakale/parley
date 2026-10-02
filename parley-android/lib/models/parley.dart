/// Parley's domain, as the bridge hands it over.
///
/// Pure Dart: no Flutter imports. Every shape mirrors
/// `docs/plans/bridge-contract.md`, and `fromMap` is the only place a
/// platform map is read, so a key renamed on the Kotlin side fails here and
/// nowhere else.
library;

/// How a history entry was produced.
enum ParleyMode {
  dictation,
  edit;

  static ParleyMode parse(Object? value) =>
      value == 'edit' ? ParleyMode.edit : ParleyMode.dictation;
}

/// How the text reached the other app's field.
enum InsertMethod {
  setText,
  paste,
  clipboardOnly,
  failed;

  static InsertMethod parse(Object? value) => InsertMethod.values.firstWhere(
    (m) => m.name == value,
    orElse: () => InsertMethod.failed,
  );

  /// Whether the text actually landed in the field.
  bool get inserted => this == setText || this == paste;
}

/// The History tab's filter chips, in the order they are shown.
enum HistoryFilter {
  all('All'),
  dictation('Dictation'),
  edit('Edits'),
  notInserted('Not inserted');

  const HistoryFilter(this.label);
  final String label;
}

/// Who turns speech into text. [groq] is the default, so an install from
/// before the choice existed is unchanged. The wire value is [name].
enum TranscriptionProvider {
  groq(
    label: 'Whisper (Groq)',
    company: 'Groq',
    model: 'Whisper',
    detail: 'Runs on your Groq account.',
    keyHint: 'gsk_…',
  ),
  deepgram(
    label: 'Deepgram Nova-3',
    company: 'Deepgram',
    model: 'Nova-3',
    detail: 'Runs on your Deepgram account.',
    keyHint: 'Paste a key',
  );

  const TranscriptionProvider({
    required this.label,
    required this.company,
    required this.model,
    required this.detail,
    required this.keyHint,
  });

  /// The choice as the user reads it: the model, and whose it is.
  final String label;

  /// The account the key belongs to, for "Groq key" and "Deepgram error".
  final String company;

  /// The model's own name, for "Turns what you say into text (Whisper)."
  final String model;

  /// One sentence under [label] where the choice is made.
  final String detail;

  /// Placeholder for an empty key field.
  final String keyHint;

  /// The other provider — the one a switch offers.
  TranscriptionProvider get other => this == groq ? deepgram : groq;

  static TranscriptionProvider parse(Object? value) =>
      value == 'deepgram' ? deepgram : groq;
}

/// What the Setup sequence and the Overview hero read.
class ParleyStatus {
  const ParleyStatus({
    this.serviceBound = false,
    this.paused = false,
    this.micGranted = false,
    this.batteryUnrestricted = false,
    this.groqKeySet = false,
    this.minimaxKeySet = false,
    this.orbEnabled = true,
    this.volumeGestureEnabled = true,
    this.deepgramKeySet = false,
    this.transcriptionProvider = TranscriptionProvider.groq,
  });

  final bool serviceBound;
  final bool paused;
  final bool micGranted;
  final bool batteryUnrestricted;
  final bool groqKeySet;
  final bool minimaxKeySet;
  final bool orbEnabled;
  final bool volumeGestureEnabled;
  final bool deepgramKeySet;
  final TranscriptionProvider transcriptionProvider;

  /// The chosen transcription provider has a key.
  bool get transcriptionKeySet => switch (transcriptionProvider) {
    TranscriptionProvider.groq => groqKeySet,
    TranscriptionProvider.deepgram => deepgramKeySet,
  };

  /// Everything dictation needs is in place. Battery is advice, not a gate:
  /// Parley works without it until the OS decides to kill the service.
  bool get ready => serviceBound && micGranted && transcriptionKeySet;

  /// Ready and not switched off by the user.
  bool get listening => ready && !paused;

  factory ParleyStatus.fromMap(Map<Object?, Object?> map) => ParleyStatus(
    serviceBound: map['serviceBound'] == true,
    paused: map['paused'] == true,
    micGranted: map['micGranted'] == true,
    batteryUnrestricted: map['batteryUnrestricted'] == true,
    groqKeySet: map['groqKeySet'] == true,
    minimaxKeySet: map['minimaxKeySet'] == true,
    orbEnabled: map['orbEnabled'] != false,
    volumeGestureEnabled: map['volumeGestureEnabled'] != false,
    deepgramKeySet: map['deepgramKeySet'] == true,
    transcriptionProvider: TranscriptionProvider.parse(
      map['transcriptionProvider'],
    ),
  );

  ParleyStatus copyWith({
    bool? serviceBound,
    bool? paused,
    bool? micGranted,
    bool? batteryUnrestricted,
    bool? groqKeySet,
    bool? minimaxKeySet,
    bool? orbEnabled,
    bool? volumeGestureEnabled,
    bool? deepgramKeySet,
    TranscriptionProvider? transcriptionProvider,
  }) => ParleyStatus(
    serviceBound: serviceBound ?? this.serviceBound,
    paused: paused ?? this.paused,
    micGranted: micGranted ?? this.micGranted,
    batteryUnrestricted: batteryUnrestricted ?? this.batteryUnrestricted,
    groqKeySet: groqKeySet ?? this.groqKeySet,
    minimaxKeySet: minimaxKeySet ?? this.minimaxKeySet,
    orbEnabled: orbEnabled ?? this.orbEnabled,
    volumeGestureEnabled: volumeGestureEnabled ?? this.volumeGestureEnabled,
    deepgramKeySet: deepgramKeySet ?? this.deepgramKeySet,
    transcriptionProvider: transcriptionProvider ?? this.transcriptionProvider,
  );

  @override
  bool operator ==(Object other) =>
      other is ParleyStatus &&
      other.serviceBound == serviceBound &&
      other.paused == paused &&
      other.micGranted == micGranted &&
      other.batteryUnrestricted == batteryUnrestricted &&
      other.groqKeySet == groqKeySet &&
      other.minimaxKeySet == minimaxKeySet &&
      other.orbEnabled == orbEnabled &&
      other.volumeGestureEnabled == volumeGestureEnabled &&
      other.deepgramKeySet == deepgramKeySet &&
      other.transcriptionProvider == transcriptionProvider;

  @override
  int get hashCode => Object.hash(
    serviceBound,
    paused,
    micGranted,
    batteryUnrestricted,
    groqKeySet,
    minimaxKeySet,
    orbEnabled,
    volumeGestureEnabled,
    deepgramKeySet,
    transcriptionProvider,
  );
}

/// The settings the service applies live.
class ParleyConfig {
  const ParleyConfig({
    this.orbEnabled = true,
    this.orbSize = 'medium',
    this.hideOrbWithoutField = true,
    this.volumeGestureEnabled = true,
    this.language = 'auto',
    this.leadingSpace = true,
    this.haptics = true,
    this.historyRetentionDays = 30,
    this.groqKeyLast4,
    this.minimaxKeyLast4,
    this.transcriptionProvider = TranscriptionProvider.groq,
    this.deepgramKeyLast4,
  });

  final bool orbEnabled;

  /// `small`, `medium` or `large`.
  final String orbSize;
  final bool hideOrbWithoutField;
  final bool volumeGestureEnabled;

  /// ISO-639-1, or `auto`.
  final String language;
  final bool leadingSpace;
  final bool haptics;

  /// 7, 30, 90, or 0 for forever.
  final int historyRetentionDays;
  final String? groqKeyLast4;
  final String? minimaxKeyLast4;
  final TranscriptionProvider transcriptionProvider;
  final String? deepgramKeyLast4;

  /// The last four of [transcriptionProvider]'s key, or null when it has none.
  String? get transcriptionKeyLast4 => keyLast4Of(transcriptionProvider);

  String? keyLast4Of(TranscriptionProvider provider) => switch (provider) {
    TranscriptionProvider.groq => groqKeyLast4,
    TranscriptionProvider.deepgram => deepgramKeyLast4,
  };

  static const orbSizes = ['small', 'medium', 'large'];
  static const retentionChoices = [7, 30, 90, 0];

  /// The languages offered in Settings. Whisper takes many more; these are the
  /// ones worth a row, and `auto` covers the rest.
  static const languages = <String, String>{
    'auto': 'Auto-detect',
    'en': 'English',
    'hi': 'Hindi',
    'kn': 'Kannada',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
  };

  factory ParleyConfig.fromMap(Map<Object?, Object?> map) => ParleyConfig(
    orbEnabled: map['orbEnabled'] != false,
    orbSize: map['orbSize'] as String? ?? 'medium',
    hideOrbWithoutField: map['hideOrbWithoutField'] != false,
    volumeGestureEnabled: map['volumeGestureEnabled'] != false,
    language: map['language'] as String? ?? 'auto',
    leadingSpace: map['leadingSpace'] != false,
    haptics: map['haptics'] != false,
    historyRetentionDays: (map['historyRetentionDays'] as num?)?.toInt() ?? 30,
    groqKeyLast4: map['groqKeyLast4'] as String?,
    minimaxKeyLast4: map['minimaxKeyLast4'] as String?,
    transcriptionProvider: TranscriptionProvider.parse(
      map['transcriptionProvider'],
    ),
    deepgramKeyLast4: map['deepgramKeyLast4'] as String?,
  );

  Map<String, Object?> toMap() => {
    'orbEnabled': orbEnabled,
    'orbSize': orbSize,
    'hideOrbWithoutField': hideOrbWithoutField,
    'volumeGestureEnabled': volumeGestureEnabled,
    'language': language,
    'leadingSpace': leadingSpace,
    'haptics': haptics,
    'historyRetentionDays': historyRetentionDays,
    'groqKeyLast4': groqKeyLast4,
    'minimaxKeyLast4': minimaxKeyLast4,
    'transcriptionProvider': transcriptionProvider.name,
    'deepgramKeyLast4': deepgramKeyLast4,
  };

  /// A copy with one key changed, the way `setConfig` changes it.
  ParleyConfig withValue(String key, Object? value) =>
      ParleyConfig.fromMap({...toMap(), key: value});
}

/// One dictation or voice edit.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.mode,
    required this.text,
    this.instruction,
    this.beforeText,
    required this.appPackage,
    required this.appLabel,
    required this.insertMethod,
    required this.recordingMs,
    required this.wordCount,
    required this.savedMs,
  });

  final int id;
  final DateTime createdAt;
  final ParleyMode mode;

  /// What was dictated, or for an edit, the text after the rewrite.
  final String text;
  final String? instruction;
  final String? beforeText;
  final String appPackage;
  final String appLabel;
  final InsertMethod insertMethod;
  final int recordingMs;
  final int wordCount;
  final int savedMs;

  /// Typing speed on a phone that the time-saved figure is measured against.
  static const typingWordsPerMinute = 35;

  /// The contract's formula, so the fake and the native side agree.
  static int savedMsFor({required int wordCount, required int recordingMs}) {
    final typingMs = (wordCount / typingWordsPerMinute * 60000).round();
    final saved = typingMs - recordingMs;
    return saved < 0 ? 0 : saved;
  }

  static int wordCountOf(String text) =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  factory HistoryEntry.fromMap(Map<Object?, Object?> map) => HistoryEntry(
    id: (map['id'] as num).toInt(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (map['createdAt'] as num).toInt(),
    ),
    mode: ParleyMode.parse(map['mode']),
    text: map['text'] as String? ?? '',
    instruction: map['instruction'] as String?,
    beforeText: map['beforeText'] as String?,
    appPackage: map['appPackage'] as String? ?? '',
    appLabel: map['appLabel'] as String? ?? '',
    insertMethod: InsertMethod.parse(map['insertMethod']),
    recordingMs: (map['recordingMs'] as num?)?.toInt() ?? 0,
    wordCount: (map['wordCount'] as num?)?.toInt() ?? 0,
    savedMs: (map['savedMs'] as num?)?.toInt() ?? 0,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'mode': mode.name,
    'text': text,
    'instruction': instruction,
    'beforeText': beforeText,
    'appPackage': appPackage,
    'appLabel': appLabel,
    'insertMethod': insertMethod.name,
    'recordingMs': recordingMs,
    'wordCount': wordCount,
    'savedMs': savedMs,
  };

  bool matches(HistoryFilter filter) => switch (filter) {
    HistoryFilter.all => true,
    HistoryFilter.dictation => mode == ParleyMode.dictation,
    HistoryFilter.edit => mode == ParleyMode.edit,
    HistoryFilter.notInserted => !insertMethod.inserted,
  };
}

/// The Overview's two figures and its last line.
class UsageSummary {
  const UsageSummary({
    required this.weekWords,
    required this.weekSavedMs,
    this.lastEntry,
  });

  final int weekWords;
  final int weekSavedMs;
  final HistoryEntry? lastEntry;

  factory UsageSummary.fromMap(Map<Object?, Object?> map) => UsageSummary(
    weekWords: (map['weekWords'] as num?)?.toInt() ?? 0,
    weekSavedMs: (map['weekSavedMs'] as num?)?.toInt() ?? 0,
    lastEntry: map['lastEntry'] is Map
        ? HistoryEntry.fromMap(map['lastEntry']! as Map<Object?, Object?>)
        : null,
  );
}

/// The outcome of checking or saving API keys.
class KeyCheck {
  const KeyCheck({required this.ok, this.errors = const {}});

  final bool ok;

  /// Provider (`groq`, `deepgram`, `minimax`) to the provider's own message.
  final Map<String, String> errors;

  factory KeyCheck.fromMap(Map<Object?, Object?> map) => KeyCheck(
    ok: map['ok'] == true,
    errors: {
      for (final e
          in ((map['errors'] as Map<Object?, Object?>?) ?? const {}).entries)
        if (e.value != null) e.key! as String: e.value! as String,
    },
  );
}

/// Where `openSystemSettings` sends the user.
enum SystemSettingsTarget { accessibility, battery, appDetails }
