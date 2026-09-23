import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/design_system/ds_settings.dart';
import 'package:parley_android/design_system/ds_theme_mode_picker.dart';
import 'package:parley_android/providers/settings_provider.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return DSPage(
      title: 'Display',
      leading: const BackButton(),
      slivers: [
        SliverToBoxAdapter(
          child: DSSettingsSection(
            eyebrow: 'Theme',
            footer:
                'System matches your device setting and updates automatically.',
            children: [
              DSSettingsRow(
                label: 'Mode',
                trailing: DSThemeModePicker(
                  value: settings.themeMode,
                  showLabels: false,
                  onChanged: (mode) {
                    ref.read(settingsProvider.notifier).setThemeMode(mode);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
