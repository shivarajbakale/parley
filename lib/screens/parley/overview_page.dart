import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_card.dart';
import 'package:parley_android/design_system/ds_chip.dart';
import 'package:parley_android/design_system/ds_control_tile.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/design_system/ds_page_header.dart';
import 'package:parley_android/design_system/ds_refresh.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/design_system/ds_stat_tile.dart';
import 'package:parley_android/design_system/ds_status_state.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/screens/parley/aurora_orb.dart';
import 'package:parley_android/screens/parley/empty_scene.dart';
import 'package:parley_android/screens/parley/parley_blocker.dart';
import 'package:parley_android/screens/parley/practice_sheet.dart';
import 'package:parley_android/screens/parley/parley_format.dart';
import 'package:parley_android/theme/parley_modes.dart';
import 'package:parley_android/theme/parley_type.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_routes.dart';
import 'package:parley_android/utils/error_copy.dart';

/// The Overview tab — the **Focal** archetype.
///
/// One hero: the orb, and a sentence saying whether talking will work right
/// now. When it will not, the hero says why and its one button fixes it —
/// the reason people open this tab is "why didn't that work?". Under it, two
/// figures and the last thing dictated.
class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(parleyStatusProvider);
    final summary = ref.watch(usageSummaryProvider);
    final gutter = DSGutter.of(context);
    final space = context.design.space;

    return DSRefresh(
      onRefresh: () async {
        await ref.read(parleyStatusProvider.notifier).refresh();
        ref.invalidate(usageSummaryProvider);
      },
      child: CustomScrollView(
        slivers: [
          const DSPageHeader.sliver(
            title: 'Parley',
            subtitle: 'Talk, and it types — in any app',
            pinned: false,
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              0,
              gutter,
              space.xl + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.list(
              children: [
                switch (status) {
                  AsyncError(:final error) => DSErrorState(
                    title: 'Could not reach the Parley service',
                    message: errorCopyFor(error).message,
                    onRetry: () => ref.invalidate(parleyStatusProvider),
                  ),
                  AsyncValue(:final value?) => _StatusHero(status: value),
                  _ => const DSSkeleton(
                    child: _StatusHero(status: ParleyStatus()),
                  ),
                },
                space.verticalMd,
                // Before the first dictation there is nothing to count: a
                // setup ring stands in for the figures and the last entry.
                ...switch (summary) {
                  AsyncError() => const <Widget>[],
                  AsyncValue(:final value?) when value.lastEntry == null => [
                    _GettingStarted(status: status.value),
                  ],
                  AsyncValue(:final value?) => [
                    _Figures(summary: value),
                    space.verticalMd,
                    _LastEntry(entry: value.lastEntry!),
                  ],
                  _ => const [_Figures(summary: null)],
                },
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHero extends ConsumerWidget {
  const _StatusHero({required this.status});

  final ParleyStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.design.space;
    final h = blockerOf(status);
    final fixable = status.ready || status.paused;

    Future<void> act() => fixBlocker(context, ref, status);

    return DSCard(
      padding: EdgeInsets.fromLTRB(space.lg, space.xl, space.lg, space.md),
      child: Column(
        children: [
          AuroraOrb(diameter: space.xxxl * 2, mode: h.mode),
          space.verticalSm,
          Semantics(
            liveRegion: true,
            child: DSText(
              h.title,
              role: DSTextRole.display,
              align: TextAlign.center,
            ),
          ),
          space.verticalXs,
          DSText(
            h.message,
            role: DSTextRole.bodySupport,
            align: TextAlign.center,
          ),
          space.verticalMd,
          Wrap(
            alignment: WrapAlignment.center,
            spacing: space.xs,
            runSpacing: space.xs,
            children: [
              DSChip(
                label: status.orbEnabled && !status.paused
                    ? 'Orb on'
                    : 'Orb off',
                markColor: OrbPalette.of(
                  status.orbEnabled && !status.paused && status.serviceBound
                      ? OrbMode.done
                      : OrbMode.idle,
                ).dotFor(Theme.of(context).brightness),
              ),
              DSChip(
                label: status.volumeGestureEnabled && !status.paused
                    ? 'Volume gesture'
                    : 'Volume gesture off',
                markColor: OrbPalette.of(
                  status.volumeGestureEnabled &&
                          !status.paused &&
                          status.serviceBound
                      ? OrbMode.done
                      : OrbMode.idle,
                ).dotFor(Theme.of(context).brightness),
              ),
            ],
          ),
          space.verticalMd,
          if (h.action != null) ...[
            DSButton(label: h.action!, onPressed: act, fullWidth: true),
            space.verticalXs,
          ],
          if (fixable)
            DSSwitchTile(
              label: 'Parley is on',
              value: !status.paused,
              onChanged: (on) =>
                  ref.read(parleyStatusProvider.notifier).setPaused(!on),
            ),
        ],
      ),
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.summary});

  final UsageSummary? summary;

  @override
  Widget build(BuildContext context) {
    final loading = summary == null;
    final valueStyle = ParleyType.figure(context);
    return DSCard(
      child: DSStatTileGrid(
        columns: 2,
        children: [
          DSStatTile(
            label: 'Words this week',
            value: loading ? '' : DSStatTile.groupedNumber(summary!.weekWords),
            loading: loading,
            style: DSStatTileStyle(valueStyle: valueStyle),
          ),
          DSStatTile(
            label: 'Saved typing',
            value: loading ? '' : formatSaved(summary!.weekSavedMs),
            loading: loading,
            markColor: OrbPalette.dictation.dotFor(
              Theme.of(context).brightness,
            ),
            style: DSStatTileStyle(valueStyle: valueStyle),
          ),
        ],
      ),
    );
  }
}

/// Before the first dictation: a ring with one segment per setup step, lit
/// as each is done, and the next step named under it. The hero above already
/// fixes a blocker, so this card only acts once everything is ready.
class _GettingStarted extends StatelessWidget {
  const _GettingStarted({required this.status});

  final ParleyStatus? status;

  @override
  Widget build(BuildContext context) {
    final s = status ?? const ParleyStatus();
    final steps = [s.serviceBound, s.micGranted, s.groqKeySet, false];
    final done = steps.where((d) => d).length;
    final ready = s.listening;
    final next = !s.serviceBound || s.paused
        ? 'turn on Parley'
        : !s.micGranted
        ? 'allow the mic'
        : !s.groqKeySet
        ? 'add your key'
        : 'say something';
    return DSCard(
      child: DSEmptyState(
        iconSlot: EmptyScene.progress(done: done, total: steps.length),
        title: 'Next: $next',
        actionLabel: ready ? 'Try it' : null,
        onAction: ready ? () => showPracticeSheet(context) : null,
      ),
    );
  }
}

class _LastEntry extends StatelessWidget {
  const _LastEntry({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    return DSCard(
      onTap: () => context.push(AppRoutes.historyEntryAt(entry.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ModeDot(mode: modeOf(entry)),
              space.horizontalSm,
              Expanded(
                child: DSText(
                  entry.mode == ParleyMode.edit
                      ? 'Last edit'
                      : 'Last dictation',
                  role: DSTextRole.itemMeta,
                ),
              ),
              DSText(
                '${entry.appLabel} · ${formatClock(entry.createdAt)}',
                role: DSTextRole.itemMeta,
              ),
            ],
          ),
          space.verticalSm,
          DSText(
            '“${entry.text}”',
            role: DSTextRole.quote,
            maxLines: 3,
            style: DSTextStyle(textStyle: ParleyType.voice(context)),
          ),
        ],
      ),
    );
  }
}
