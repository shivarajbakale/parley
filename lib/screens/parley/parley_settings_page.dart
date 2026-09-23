import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_bottom_sheet.dart';
import 'package:parley_android/design_system/ds_control_tile.dart';
import 'package:parley_android/design_system/ds_dialog.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_page_header.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_settings.dart';
import 'package:parley_android/design_system/ds_snack_bar.dart';
import 'package:parley_android/design_system/ds_status_state.dart';
import 'package:parley_android/design_system/ds_theme_mode_picker.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_routes.dart';
import 'package:parley_android/utils/error_copy.dart';

/// The Settings tab — the **Settings** archetype.
///
/// Grouped in the order a user reaches for them: how Parley starts, how it
/// writes, the keys it runs on, what it remembers, and the system grants
/// under all of it. Every switch applies to the running service at once.
class ParleySettingsPage extends ConsumerWidget {
  const ParleySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(parleyConfigProvider);
    final status = ref.watch(parleyStatusProvider).valueOrNull;
    final appSettings = ref.watch(settingsProvider);
    final space = context.design.space;

    Future<void> set(String key, Object? value) async {
      try {
        await ref.read(parleyConfigProvider.notifier).set(key, value);
        if (key == 'orbEnabled' || key == 'volumeGestureEnabled') {
          await ref.read(parleyStatusProvider.notifier).refresh();
        }
      } catch (e) {
        if (context.mounted) {
          showDSSnackBar(
            context,
            message: errorCopyFor(e).message,
            tone: DSTone.error,
          );
        }
      }
    }

    final gap = SliverToBoxAdapter(child: SizedBox(height: space.xl));

    return CustomScrollView(
      slivers: [
        const DSPageHeader.compactSliver(title: 'Settings'),
        ...switch (config) {
          AsyncError(:final error) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: DSErrorState(
                title: 'Could not read settings',
                message: errorCopyFor(error).message,
                onRetry: () => ref.invalidate(parleyConfigProvider),
              ),
            ),
          ],
          AsyncValue(:final value?) => [
            SliverToBoxAdapter(
              child: DSSettingsSection(
                eyebrow: 'Triggers',
                footer:
                    'Hold the orb to dictate; double-tap then hold to rewrite. '
                    'The volume gesture is two taps and a held third press.',
                children: [
                  DSSwitchTile(
                    label: 'Floating orb',
                    value: value.orbEnabled,
                    onChanged: (v) => set('orbEnabled', v),
                  ),
                  DSSwitchTile(
                    label: 'Volume-down tap-tap-hold',
                    value: value.volumeGestureEnabled,
                    onChanged: (v) => set('volumeGestureEnabled', v),
                  ),
                  DSSettingsRow(
                    label: 'Orb size',
                    value: _orbSizeLabel(value.orbSize),
                    onTap: () async {
                      final picked = await _pick<String>(
                        context,
                        title: 'Orb size',
                        options: [
                          for (final size in ParleyConfig.orbSizes)
                            (value: size, label: _orbSizeLabel(size)),
                        ],
                        selected: value.orbSize,
                      );
                      if (picked != null) await set('orbSize', picked);
                    },
                  ),
                  DSSwitchTile(
                    label: 'Tuck away outside text fields',
                    value: value.hideOrbWithoutField,
                    onChanged: (v) => set('hideOrbWithoutField', v),
                  ),
                ],
              ),
            ),
            gap,
            SliverToBoxAdapter(
              child: DSSettingsSection(
                eyebrow: 'Dictation',
                children: [
                  DSSettingsRow(
                    label: 'Language',
                    value:
                        ParleyConfig.languages[value.language] ??
                        value.language,
                    onTap: () async {
                      final picked = await _pick<String>(
                        context,
                        title: 'Language',
                        options: ParleyConfig.languages.entries
                            .map((e) => (value: e.key, label: e.value))
                            .toList(),
                        selected: value.language,
                      );
                      if (picked != null) await set('language', picked);
                    },
                  ),
                  DSSwitchTile(
                    label: 'Space before inserted text',
                    subtitle: 'When the cursor follows a word',
                    value: value.leadingSpace,
                    onChanged: (v) => set('leadingSpace', v),
                  ),
                  DSSwitchTile(
                    label: 'Haptic on start and stop',
                    value: value.haptics,
                    onChanged: (v) => set('haptics', v),
                  ),
                ],
              ),
            ),
            gap,
            SliverToBoxAdapter(
              child: DSSettingsSection(
                eyebrow: 'Keys',
                footer:
                    'Keys stay on this phone, encrypted. Only the last four '
                    'characters are ever shown.',
                children: [
                  // The summary goes under the label: two providers and two
                  // key tails do not fit beside it on a narrow phone.
                  DSSettingsRow(
                    label: 'API keys',
                    description: _keysSummary(value),
                    onTap: () => context.push(AppRoutes.apiKeys),
                  ),
                ],
              ),
            ),
            gap,
            SliverToBoxAdapter(
              child: DSSettingsSection(
                eyebrow: 'History',
                children: [
                  DSSettingsRow(
                    label: 'Keep history for',
                    value: _retentionLabel(value.historyRetentionDays),
                    onTap: () async {
                      final picked = await _pick<int>(
                        context,
                        title: 'Keep history for',
                        options: [
                          for (final d in ParleyConfig.retentionChoices)
                            (value: d, label: _retentionLabel(d)),
                        ],
                        selected: value.historyRetentionDays,
                      );
                      if (picked != null) {
                        await set('historyRetentionDays', picked);
                      }
                    },
                  ),
                  DSSettingsRow(
                    label: 'Clear history',
                    tone: DSTone.error,
                    icon: Icons.delete_sweep_outlined,
                    onTap: () => _confirmClear(context, ref),
                  ),
                ],
              ),
            ),
            gap,
            SliverToBoxAdapter(
              child: DSSettingsSection(
                eyebrow: 'System',
                children: [
                  DSSettingsRow(
                    label: 'Accessibility service',
                    value: (status?.serviceBound ?? false) ? 'On' : 'Off',
                    onTap: () => ref
                        .read(parleyBridgeProvider)
                        .openSystemSettings(SystemSettingsTarget.accessibility),
                  ),
                  DSSettingsRow(
                    label: 'Battery',
                    value: (status?.batteryUnrestricted ?? false)
                        ? 'Unrestricted'
                        : 'Optimised',
                    onTap: () => ref
                        .read(parleyBridgeProvider)
                        .openSystemSettings(SystemSettingsTarget.battery),
                  ),
                  DSSettingsRow(
                    label: 'Theme',
                    trailing: DSThemeModePicker(
                      value: appSettings.themeMode,
                      showLabels: false,
                      onChanged: (mode) => ref
                          .read(settingsProvider.notifier)
                          .setThemeMode(mode),
                    ),
                  ),
                  DSSettingsRow(
                    label: 'Run setup again',
                    onTap: () => context.push('${AppRoutes.setup}?again=1'),
                  ),
                  DSSettingsRow(
                    label: 'About',
                    onTap: () => context.push(AppRoutes.about),
                  ),
                ],
              ),
            ),
          ],
          _ => [
            const SliverToBoxAdapter(
              child: DSSkeletonList(itemCount: 8, shrinkWrap: true),
            ),
          ],
        },
        SliverToBoxAdapter(
          child: SizedBox(
            height: space.xl + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  static String _keysSummary(ParleyConfig c) {
    final groq = c.groqKeyLast4 == null
        ? 'Groq missing'
        : 'Groq ••${c.groqKeyLast4}';
    final minimax = c.minimaxKeyLast4 == null
        ? 'no MiniMax'
        : 'MiniMax ••${c.minimaxKeyLast4}';
    return '$groq · $minimax';
  }

  static String _orbSizeLabel(String size) => switch (size) {
    'small' => 'Small',
    'large' => 'Large',
    _ => 'Medium',
  };

  static String _retentionLabel(int days) =>
      days == 0 ? 'Forever' : '$days days';

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDSConfirm(
      context: context,
      icon: Icons.delete_sweep_outlined,
      title: 'Clear all history?',
      message:
          'Every transcript on this phone is deleted. This cannot be undone.',
      confirmLabel: 'Clear history',
      destructive: true,
    );
    if (confirmed ?? false) {
      final n = await ref.read(parleyBridgeProvider).deleteHistory();
      ref.read(historyRevisionProvider.notifier).state++;
      if (context.mounted) {
        showDSSnackBar(context, message: '$n transcripts deleted');
      }
    }
  }
}

/// One choice from a short list, in a sheet.
Future<T?> _pick<T>(
  BuildContext context, {
  required String title,
  required List<({T value, String label})> options,
  required T selected,
}) {
  return showDSBottomSheet<T>(
    context: context,
    header: DSSheetHeader(title: title),
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final o in options)
          DSListTile(
            title: o.label,
            selected: o.value == selected,
            selectionMode: DSSelectionMode.single,
            onTap: () => Navigator.of(sheetContext).pop(o.value),
          ),
      ],
    ),
  );
}
