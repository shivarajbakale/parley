import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/catalog/structure_shared_widgets.dart';

final dsSettingsSectionDemo = DSComponentDemo(
  name: 'DSSettingsSection',
  fullBleed: true,
  summary: 'The grouped inset block that makes settings read as settings.',
  stories: [
    DSStory(
      title: 'Every row kind',
      note:
          'nav, toggle, info, action and custom — hairline-separated '
          'inside one tinted container, with the explanation in the '
          'footer rather than under a row.',
      builder: (context) => const _SettingsDemo(),
    ),
    DSStory(
      title: 'Destructive group',
      note:
          'Its own group, at the bottom, behind a confirm that names '
          'the object.',
      builder: (context) => DSSettingsSection(
        eyebrow: 'Danger zone',
        footer: 'Deleting a workspace also deletes its documents.',
        children: [
          DSSettingsRow(
            label: 'Delete workspace',
            tone: DSTone.error,
            icon: Icons.delete_outline,
            onTap: () => showDSConfirm(
              context: context,
              title: "Delete 'Rocketship'?",
              message: 'Everything in it is removed for everyone.',
              confirmLabel: 'Delete',
              destructive: true,
            ),
          ),
        ],
      ),
    ),
  ],
);

class _SettingsDemo extends StatefulWidget {
  const _SettingsDemo();

  @override
  State<_SettingsDemo> createState() => _SettingsDemoState();
}

class _SettingsDemoState extends State<_SettingsDemo> {
  bool _haptics = true;

  @override
  Widget build(BuildContext context) {
    return DSSettingsSection(
      eyebrow: 'Preferences',
      footer: 'Haptics follow your device’s system setting when it is off.',
      children: [
        DSSettingsRow(
          label: 'Display',
          description: 'Text size, contrast',
          icon: Icons.tune,
          onTap: () {},
        ),
        DSSwitchTile(
          label: 'Haptics',
          icon: Icons.vibration,
          value: _haptics,
          onChanged: (value) => setState(() => _haptics = value),
        ),
        const DSSettingsRow(label: 'Version', value: '0.1.0'),
        const DSSettingsRow(
          label: 'Theme',
          trailing: ThemeModeDemo(showLabels: false),
        ),
        DSSettingsRow(label: 'Sign out', icon: Icons.logout, onTap: () {}),
      ],
    );
  }
}
