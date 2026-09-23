import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_chip.dart';
import 'package:parley_android/design_system/ds_dismissible_tile.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/design_system/ds_page_header.dart';
import 'package:parley_android/design_system/ds_pinned_header.dart';
import 'package:parley_android/design_system/ds_refresh.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_search_bar.dart';
import 'package:parley_android/design_system/ds_section_header.dart';
import 'package:parley_android/design_system/ds_snack_bar.dart';
import 'package:parley_android/design_system/ds_status_state.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/screens/parley/aurora_orb.dart';
import 'package:parley_android/screens/parley/parley_format.dart';
import 'package:parley_android/theme/parley_type.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_routes.dart';
import 'package:parley_android/utils/error_copy.dart';

/// The History tab — the **Collection** archetype.
///
/// Newest first, grouped by day. Search runs over the words themselves,
/// because "that thing I said about the invoice" is how people look for a
/// dictation. Swipe deletes with an undo; the row's tap-reachable twin is the
/// Delete on the transcript page. Long-press copies.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key, this.now});

  /// Pins "Today" / "Yesterday" for goldens; the clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(historyListProvider);
    final query = ref.watch(historyQueryProvider);
    final hidden = ref.watch(hiddenHistoryIdsProvider);

    return DSRefresh(
      onRefresh: () => ref.refresh(historyListProvider.future),
      child: CustomScrollView(
        slivers: [
          const DSPageHeader.compactSliver(title: 'History'),
          DSPinnedHeader(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                DSGutter.of(context),
                0,
                DSGutter.of(context),
                context.design.space.sm,
              ),
              child: DSSearchBar(
                value: query.text,
                hintText: 'Search what you said',
                onChanged: (v) => ref
                    .read(historyQueryProvider.notifier)
                    .update((q) => q.copyWith(text: v)),
                onClear: () => ref
                    .read(historyQueryProvider.notifier)
                    .update((q) => q.copyWith(text: '')),
              ),
            ),
          ),
          DSPinnedHeader(child: _FilterStrip(selected: query.filter)),
          ...switch (entries) {
            AsyncError(:final error) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: DSErrorState(
                  icon: errorCopyFor(error).icon,
                  title: 'Could not read your history',
                  message: errorCopyFor(error).message,
                  onRetry: () => ref.invalidate(historyListProvider),
                ),
              ),
            ],
            AsyncValue(:final value?) => _content(context, ref, [
              for (final e in value)
                if (!hidden.contains(e.id)) e,
            ], query),
            _ => const [
              SliverToBoxAdapter(
                child: DSSkeletonList(itemCount: 8, shrinkWrap: true),
              ),
            ],
          },
        ],
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    List<HistoryEntry> entries,
    HistoryQuery query,
  ) {
    if (entries.isEmpty) {
      void clear() =>
          ref.read(historyQueryProvider.notifier).state = const HistoryQuery();
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: query.isFiltered
              ? DSEmptyState(
                  icon: Icons.search_off_outlined,
                  title: query.text.trim().isEmpty
                      ? 'Nothing under ${query.filter.label}.'
                      : 'No transcripts match "${query.text.trim()}".',
                  message: 'Clear the search or pick another filter.',
                  actionLabel: 'Clear filters',
                  onAction: clear,
                )
              : const DSEmptyState(
                  icon: Icons.graphic_eq,
                  title: 'Things you dictate show up here',
                  message: 'Hold the orb in any app to start.',
                ),
        ),
      ];
    }

    final today = now ?? DateTime.now();
    final rows = <Widget>[];
    String? day;
    for (final entry in entries) {
      final label = formatDay(entry.createdAt, today);
      if (label != day) {
        day = label;
        rows.add(DSSectionHeader(label: label, size: DSSectionHeaderSize.sm));
      }
      rows.add(_HistoryRow(entry: entry));
    }

    return [
      SliverPadding(
        padding: EdgeInsets.only(
          bottom:
              context.design.space.xl + MediaQuery.paddingOf(context).bottom,
        ),
        sliver: SliverList.list(children: rows),
      ),
    ];
  }
}

class _FilterStrip extends ConsumerWidget {
  const _FilterStrip({required this.selected});

  final HistoryFilter selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(
        DSGutter.of(context),
        0,
        DSGutter.of(context),
        context.design.space.sm,
      ),
      child: Row(
        spacing: context.design.space.sm,
        children: [
          for (final filter in HistoryFilter.values)
            DSChip(
              label: filter.label,
              role: DSChipRole.filter,
              selected: filter == selected,
              onSelected: (_) => ref
                  .read(historyQueryProvider.notifier)
                  .update((q) => q.copyWith(filter: filter)),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.entry});

  final HistoryEntry entry;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final undo = await deleteHistoryEntry(ref, entry);
    if (!context.mounted) return;
    showDSSnackBar(
      context,
      message: 'Transcript deleted',
      icon: Icons.delete_outline,
      actionLabel: 'Undo',
      onAction: undo,
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: entry.text));
    if (!context.mounted) return;
    showDSSnackBar(context, message: 'Copied', icon: Icons.content_copy);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = [
      entry.appLabel,
      formatClock(entry.createdAt),
      if (entry.mode == ParleyMode.edit) 'edit' else '${entry.wordCount} words',
      if (!entry.insertMethod.inserted)
        insertMethodLabel(entry.insertMethod).toLowerCase(),
    ].join(' · ');

    final title = entry.mode == ParleyMode.edit
        ? (entry.instruction ?? entry.text)
        : entry.text;

    return DSDismissibleTile(
      key: ValueKey<int>(entry.id),
      trailingAction: DSSwipeAction(
        icon: Icons.delete_outline,
        label: 'Delete',
        tone: DSTone.error,
        onInvoke: () => _delete(context, ref),
      ),
      child: DSListTile(
        leading: Padding(
          padding: EdgeInsetsDirectional.only(top: context.design.space.xs),
          child: ModeDot(mode: modeOf(entry)),
        ),
        title: title,
        // The words the reader came for are never cut: `body` wraps without
        // a line limit, where `itemTitle` stops at two.
        titleSlot: DSText(
          title,
          role: DSTextRole.body,
          style: DSTextStyle(textStyle: ParleyType.voiceRow(context)),
        ),
        subtitle: meta,
        onTap: () => context.push(AppRoutes.historyEntryAt(entry.id)),
        onLongPress: () => _copy(context),
      ),
    );
  }
}
