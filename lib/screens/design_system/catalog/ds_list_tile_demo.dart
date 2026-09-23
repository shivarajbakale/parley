import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

final dsListTileDemo = DSComponentDemo(
  name: 'DSListTile',
  fullBleed: true,
  summary: 'A row: leading, title, subtitle, trailing, one tap target.',
  stories: [
    DSStory(
      title: 'Identity first',
      note:
          'Title, then metadata, then one trailing control. The order '
          'the eye reads, not the order the data arrived in.',
      builder: (context) => Column(
        children: [
          DSListTile(
            leading: DSAvatar.fromName(name: 'Ada Lovelace'),
            title: 'Ada Lovelace',
            subtitle: 'Edited the roadmap · 2h ago',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          DSListTile(
            leading: const Icon(Icons.description_outlined),
            title: 'Q3 report',
            subtitle: 'PDF · 2.4 MB',
            trailing: DSMenu(
              semanticLabel: 'Actions for Q3 report',
              items: [
                DSMenuItem(label: 'Open', onPressed: () {}),
                const DSMenuSeparator(),
                DSMenuItem(
                  label: 'Delete',
                  tone: DSTone.error,
                  onPressed: () {},
                ),
              ],
            ),
            onTap: () {},
          ),
        ],
      ),
    ),
    DSStory(
      title: 'Tone and wrapping',
      note:
          'A tone moves the glyph, the well and the title together, so '
          'the row never says it in colour alone; wrap lets a long title '
          'use two lines instead of an ellipsis.',
      builder: (context) => Column(
        children: [
          DSListTile(
            leading: const Icon(Icons.logout),
            title: 'Sign out of every device',
            tone: DSTone.error,
            onTap: () {},
          ),
          const DSListTile(
            title:
                'A title long enough that one line was never going to '
                'be enough for it',
            subtitle: 'wrap: true',
            wrap: true,
          ),
        ],
      ),
    ),
    DSStory(
      title: 'Five tones',
      note:
          'The tone moves the well, the glyph and the title together. '
          'A row that said it in colour alone would say nothing in '
          'greyscale.',
      builder: (context) => Column(
        children: [
          for (final (tone, icon, title) in const [
            (DSTone.neutral, Icons.folder_outlined, 'Archive'),
            (DSTone.info, Icons.sync_outlined, 'Syncing'),
            (DSTone.success, Icons.verified_outlined, 'Verified'),
            (DSTone.warning, Icons.storage_outlined, 'Storage is low'),
            (DSTone.error, Icons.delete_outline, 'Delete account'),
          ])
            DSListTile(
              leading: Icon(icon),
              title: title,
              tone: tone,
              onTap: () {},
            ),
        ],
      ),
    ),
    DSStory(
      title: 'Three leading styles',
      note:
          'well, bare and none come from ComponentSpec.leadingStyle — '
          'an identity chooses one for the whole app, and the row reads '
          'it rather than drawing a circle regardless.',
      builder: (context) => Column(
        children: [
          for (final style in LeadingStyle.values)
            DSListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: 'Notification settings',
              subtitle: 'leadingStyle: ${style.name}',
              style: DSListTileStyle(leadingStyle: style),
              onTap: () {},
            ),
        ],
      ),
    ),
    DSStory(
      title: 'Selection, single and multiple',
      note:
          'The fill and the check are two channels, not one. Single '
          'select declares a mutually exclusive group, so a reader '
          'announces "2 of 3".',
      builder: (context) => const _SelectionDemo(),
    ),
    DSStory(
      title: 'Meta, a trailing control, disabled and loading',
      note:
          'meta is a third line that does not eat the subtitle\u2019s '
          'two-line cap. A trailing control is a second tap target, so '
          'the row keeps its own.',
      builder: (context) => Column(
        children: [
          DSListTile(
            leading: const Icon(Icons.cloud_download_outlined),
            title: 'Offline library',
            subtitle: 'Four albums waiting',
            meta: const DSListTileMeta(
              label: 'Updated 2h ago',
              icon: Icons.schedule,
            ),
            onTap: () {},
          ),
          DSListTile(
            leading: const Icon(Icons.wifi),
            title: 'Wi-Fi only',
            trailing: DSSwitch(
              value: true,
              semanticLabel: 'Wi-Fi only',
              compact: true,
              onChanged: (_) {},
            ),
          ),
          const DSListTile(
            leading: Icon(Icons.lock_outline),
            title: 'Managed by your organisation',
            subtitle: 'You cannot change this',
            enabled: false,
          ),
          const DSListTile(title: 'Loading', loading: true),
        ],
      ),
    ),
    DSStory(
      title: 'A group draws its own separators',
      note:
          'The row cannot know which row is last; the group can. The '
          'inset comes from ComponentSpec.dividerPolicy.',
      builder: (context) => DSListTileGroup(
        children: [
          DSListTile(
            leading: const Icon(Icons.person_outline),
            title: 'Account',
            onTap: () {},
          ),
          DSListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: 'Notifications',
            onTap: () {},
          ),
          DSListTile(
            leading: const Icon(Icons.help_outline),
            title: 'Help',
            onTap: () {},
          ),
        ],
      ),
    ),
  ],
);

/// Three rows that actually select, so the fill, the check and the semantics
/// can be seen changing rather than described.
class _SelectionDemo extends StatefulWidget {
  const _SelectionDemo();

  @override
  State<_SelectionDemo> createState() => _SelectionDemoState();
}

class _SelectionDemoState extends State<_SelectionDemo> {
  int _single = 0;
  final _multiple = <int>{1};

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DSSectionHeader(label: 'Single'),
      for (var i = 0; i < 3; i++)
        DSListTile(
          title: 'Option ${String.fromCharCode(65 + i)}',
          selected: _single == i,
          selectionMode: DSSelectionMode.single,
          onTap: () => setState(() => _single = i),
        ),
      const DSSectionHeader(label: 'Multiple'),
      for (var i = 0; i < 3; i++)
        DSListTile(
          leading: const Icon(Icons.image_outlined),
          title: 'Photo ${i + 1}',
          selected: _multiple.contains(i),
          selectionMode: DSSelectionMode.multiple,
          onTap: () => setState(
            () =>
                _multiple.contains(i) ? _multiple.remove(i) : _multiple.add(i),
          ),
        ),
    ],
  );
}
