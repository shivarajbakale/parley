import 'package:parley_android/models/parley.dart';
import 'package:parley_android/theme/parley_modes.dart';

/// The colour a history entry wears: amber for an edit, the error red for
/// text that never reached its field, indigo otherwise.
OrbMode modeOf(HistoryEntry entry) {
  if (!entry.insertMethod.inserted) return OrbMode.error;
  return entry.mode == ParleyMode.edit ? OrbMode.edit : OrbMode.dictation;
}

/// "41 min", "2 h 5 min", "38 sec".
String formatSaved(int ms) {
  final seconds = (ms / 1000).round();
  if (seconds < 60) return '$seconds sec';
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

/// "0:06", "1:42".
String formatDuration(int ms) {
  final total = (ms / 1000).round();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// "9:41" — 24-hour, because it is the shortest unambiguous form.
String formatClock(DateTime t) =>
    '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Today", "Yesterday", "Mon 21 Sep".
String formatDay(DateTime t, DateTime now) {
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';
}

/// "Thu 24 Sep, 9:41".
String formatStamp(DateTime t, DateTime now) =>
    '${formatDay(t, now)}, ${formatClock(t)}';

String insertMethodLabel(InsertMethod m) => switch (m) {
  InsertMethod.setText => 'Inserted',
  InsertMethod.paste => 'Pasted',
  InsertMethod.clipboardOnly => 'Copied, not inserted',
  InsertMethod.failed => 'Not inserted',
};
