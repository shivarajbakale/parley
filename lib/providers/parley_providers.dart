import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/services/parley/parley_bridge.dart';
import 'package:parley_android/services/service_config.dart';

/// The native core, chosen once in `ServiceConfig`. Tests override this with
/// a `FakeParleyBridge` they hold on to.
final parleyBridgeProvider = Provider<ParleyBridge>(
  (ref) => ServiceConfig.createParleyBridge(),
);

/// Live service status: seeded by `getStatus`, then kept current by the
/// event channel. [ParleyStatusNotifier.refresh] re-reads it when the app
/// resumes, because a grant given in system Settings (microphone, battery)
/// does not always arrive as an event.
final parleyStatusProvider =
    AsyncNotifierProvider<ParleyStatusNotifier, ParleyStatus>(
      ParleyStatusNotifier.new,
      dependencies: [parleyBridgeProvider],
    );

class ParleyStatusNotifier extends AsyncNotifier<ParleyStatus> {
  @override
  Future<ParleyStatus> build() async {
    final bridge = ref.watch(parleyBridgeProvider);
    final sub = bridge.statusChanges.listen((s) => state = AsyncData(s));
    ref.onDispose(sub.cancel);
    return bridge.getStatus();
  }

  Future<void> refresh() async {
    final next = await ref.read(parleyBridgeProvider).getStatus();
    state = AsyncData(next);
  }

  Future<void> setPaused(bool paused) async {
    final previous = state.valueOrNull;
    if (previous != null) state = AsyncData(previous.copyWith(paused: paused));
    state = AsyncData(await ref.read(parleyBridgeProvider).setPaused(paused));
  }

  Future<bool> requestMic() async {
    final granted = await ref.read(parleyBridgeProvider).requestMicPermission();
    await refresh();
    return granted;
  }
}

/// Settings the service applies live. Writes are optimistic: the switch
/// moves at once, and the bridge's answer replaces the guess.
final parleyConfigProvider =
    AsyncNotifierProvider<ParleyConfigNotifier, ParleyConfig>(
      ParleyConfigNotifier.new,
      dependencies: [parleyBridgeProvider],
    );

class ParleyConfigNotifier extends AsyncNotifier<ParleyConfig> {
  @override
  Future<ParleyConfig> build() => ref.watch(parleyBridgeProvider).getConfig();

  Future<void> set(String key, Object? value) async {
    final previous = state.valueOrNull;
    if (previous != null) state = AsyncData(previous.withValue(key, value));
    try {
      state = AsyncData(
        await ref.read(parleyBridgeProvider).setConfig(key, value),
      );
    } catch (e, st) {
      state = previous != null ? AsyncData(previous) : AsyncError(e, st);
      rethrow;
    }
  }

  /// Re-reads after keys change, so the last-four hints update.
  Future<void> reload() async {
    state = AsyncData(await ref.read(parleyBridgeProvider).getConfig());
  }
}

/// Ticks each time the service writes a history entry, so everything that
/// shows history can `watch` one thing to stay current.
final historyRevisionProvider = StateProvider<int>((ref) {
  final sub = ref
      .watch(parleyBridgeProvider)
      .historyAdded
      .listen((_) => ref.controller.state++);
  ref.onDispose(sub.cancel);
  return 0;
}, dependencies: [parleyBridgeProvider]);

final usageSummaryProvider = FutureProvider<UsageSummary>((ref) {
  ref.watch(historyRevisionProvider);
  return ref.watch(parleyBridgeProvider).getUsageSummary();
}, dependencies: [historyRevisionProvider, parleyBridgeProvider]);

/// The History tab's search text and filter chip.
class HistoryQuery {
  const HistoryQuery({this.text = '', this.filter = HistoryFilter.all});

  final String text;
  final HistoryFilter filter;

  bool get isFiltered => text.trim().isNotEmpty || filter != HistoryFilter.all;

  HistoryQuery copyWith({String? text, HistoryFilter? filter}) =>
      HistoryQuery(text: text ?? this.text, filter: filter ?? this.filter);
}

final historyQueryProvider = StateProvider<HistoryQuery>(
  (ref) => const HistoryQuery(),
  dependencies: const [],
);

final historyListProvider = FutureProvider<List<HistoryEntry>>(
  (ref) {
    ref.watch(historyRevisionProvider);
    final query = ref.watch(historyQueryProvider);
    return ref
        .watch(parleyBridgeProvider)
        .listHistory(limit: 200, query: query.text, filter: query.filter);
  },
  dependencies: [
    historyRevisionProvider,
    historyQueryProvider,
    parleyBridgeProvider,
  ],
);

final historyEntryProvider = FutureProvider.family<HistoryEntry?, int>((
  ref,
  id,
) {
  ref.watch(historyRevisionProvider);
  return ref.watch(parleyBridgeProvider).getHistoryEntry(id);
}, dependencies: [historyRevisionProvider, parleyBridgeProvider]);

/// Rows swiped away but not yet gone from the store. A `Dismissible` must
/// leave the tree in the same frame it is dismissed, and the store's answer
/// arrives a frame or more later, so the list hides these synchronously.
final hiddenHistoryIdsProvider = StateProvider<Set<int>>(
  (ref) => const <int>{},
  dependencies: const [],
);

/// Deletes an entry and hands back an undo.
Future<Future<void> Function()> deleteHistoryEntry(
  WidgetRef ref,
  HistoryEntry entry,
) async {
  final bridge = ref.read(parleyBridgeProvider);
  final hidden = ref.read(hiddenHistoryIdsProvider.notifier);
  hidden.update((ids) => {...ids, entry.id});
  await bridge.deleteHistory(id: entry.id);
  ref.read(historyRevisionProvider.notifier).state++;
  return () async {
    await bridge.restoreHistory(entry);
    hidden.update((ids) => {...ids}..remove(entry.id));
    ref.read(historyRevisionProvider.notifier).state++;
  };
}
