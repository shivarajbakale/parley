import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_card.dart';
import 'package:parley_android/design_system/ds_dialog.dart';
import 'package:parley_android/design_system/ds_icon_button.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/design_system/ds_pinned_action_bar.dart';
import 'package:parley_android/design_system/ds_settings.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/design_system/ds_snack_bar.dart';
import 'package:parley_android/design_system/ds_status_state.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/screens/parley/aurora_orb.dart';
import 'package:parley_android/screens/parley/parley_format.dart';
import 'package:parley_android/theme/parley_type.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/error_copy.dart';

/// One transcript — the **Detail** archetype.
///
/// The words first, at reading size, in the serif that marks them as the
/// user's own; the facts under them; Copy pinned so a long transcript never
/// scrolls it away. An edit shows the instruction, then before and after.
class HistoryDetailPage extends ConsumerWidget {
  const HistoryDetailPage({super.key, required this.id, this.now});

  final int id;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(historyEntryProvider(id));
    final value = entry.valueOrNull;

    Future<void> copy() async {
      if (value == null) return;
      await Clipboard.setData(ClipboardData(text: value.text));
      if (context.mounted) {
        showDSSnackBar(context, message: 'Copied', icon: Icons.content_copy);
      }
    }

    Future<void> delete() async {
      if (value == null) return;
      final confirmed = await showDSConfirm(
        context: context,
        icon: Icons.delete_outline,
        title: 'Delete this transcript?',
        message: 'It is removed from History on this phone.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (confirmed ?? false) {
        await deleteHistoryEntry(ref, value);
        if (context.mounted) context.pop();
      }
    }

    return DSPage.surface(
      title: value == null
          ? 'Transcript'
          : formatStamp(value.createdAt, now ?? DateTime.now()),
      actions: value == null
          ? null
          : DSIconButton(
              icon: Icons.delete_outline,
              semanticLabel: 'Delete transcript',
              tooltip: 'Delete transcript',
              onPressed: delete,
            ),
      footer: value == null
          ? null
          : DSPinnedActionBar(
              children: [
                DSButton(
                  label: value.mode == ParleyMode.edit
                      ? 'Copy rewritten text'
                      : 'Copy',
                  icon: Icons.content_copy,
                  onPressed: copy,
                  fullWidth: true,
                ),
              ],
            ),
      child: switch (entry) {
        AsyncError(:final error) => DSErrorState(
          icon: errorCopyFor(error).icon,
          title: 'Could not read this transcript',
          message: errorCopyFor(error).message,
          onRetry: () => ref.invalidate(historyEntryProvider(id)),
        ),
        AsyncData(value: null) => DSEmptyState(
          icon: Icons.delete_sweep_outlined,
          title: 'This transcript no longer exists',
          actionLabel: 'Back to History',
          onAction: () => context.pop(),
        ),
        AsyncValue(:final value?) => _Body(entry: value),
        _ => DSSkeleton(child: _Body(entry: _placeholder)),
      },
    );
  }
}

final _placeholder = HistoryEntry(
  id: 0,
  createdAt: DateTime(2026),
  mode: ParleyMode.dictation,
  text: 'A transcript of about this length, loading.',
  appPackage: '',
  appLabel: 'App',
  insertMethod: InsertMethod.setText,
  recordingMs: 6000,
  wordCount: 8,
  savedMs: 8000,
);

class _Body extends StatelessWidget {
  const _Body({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final gutter = DSGutter.of(context);
    final isEdit = entry.mode == ParleyMode.edit;

    Widget quote(String text, {bool large = true}) => SelectionArea(
      child: DSText(
        '“$text”',
        role: DSTextRole.quote,
        style: DSTextStyle(textStyle: ParleyType.voice(context, large: large)),
      ),
    );

    // The words at the top, the facts anchored to the bottom over the pinned
    // Copy: a short transcript leaves air between them rather than a void
    // under everything.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, space.sm, gutter, 0),
          sliver: SliverList.list(
            children: [
              DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ModeDot(mode: modeOf(entry)),
                        space.horizontalSm,
                        DSText(
                          isEdit ? 'You asked' : 'You said',
                          role: DSTextRole.eyebrow,
                        ),
                      ],
                    ),
                    space.verticalSm,
                    quote(isEdit ? (entry.instruction ?? '') : entry.text),
                  ],
                ),
              ),
              if (isEdit) ...[
                space.verticalMd,
                DSCard(
                  variant: DSCardVariant.outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DSText('Before', role: DSTextRole.eyebrow),
                      space.verticalXs,
                      SelectionArea(
                        child: DSText(
                          entry.beforeText ?? '',
                          role: DSTextRole.bodySupport,
                        ),
                      ),
                      space.verticalMd,
                      const DSText('After', role: DSTextRole.eyebrow),
                      space.verticalXs,
                      SelectionArea(
                        child: DSText(entry.text, role: DSTextRole.body),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        SliverPadding(
          // No side gutter: `DSSettingsSection` insets itself.
          padding: EdgeInsets.fromLTRB(0, space.lg, 0, space.lg),
          // Fills what the words leave and sits at its bottom, but grows
          // past it rather than overflowing when the type is large — a
          // min-height, not the intrinsic guess `SliverFillRemaining` makes.
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) => SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.remainingPaintExtent,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: DSSettingsSection(
                    eyebrow: 'Details',
                    footer:
                        'Saved counts typing at 35 words a minute on a phone, less the '
                        'time spent talking.',
                    children: [
                      DSSettingsRow(label: 'App', value: entry.appLabel),
                      DSSettingsRow(
                        label: 'Mode',
                        value: isEdit ? 'Voice edit' : 'Dictation',
                      ),
                      DSSettingsRow(
                        label: 'Result',
                        value: insertMethodLabel(entry.insertMethod),
                      ),
                      DSSettingsRow(
                        label: 'Length',
                        value:
                            '${formatDuration(entry.recordingMs)} · ${entry.wordCount} words',
                      ),
                      DSSettingsRow(
                        label: 'Saved',
                        value: formatSaved(entry.savedMs),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
