import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/catalog/structure_shared_widgets.dart';

final dsPageHeaderDemo = DSComponentDemo(
  name: 'DSPageHeader',
  fullBleed: true,
  summary: 'The screen’s title, fixed inside the body.',
  stories: [
    DSStory(
      title: 'A titled section',
      note:
          'DSSection — the Detail archetype is built out of these: '
          'titled blocks with one padding contract, rather than one wall '
          'of text.',
      builder: (context) => DSSection(
        label: 'Members',
        trailing: DSButton(
          label: 'Invite',
          variant: DSButtonVariant.ghost,
          size: DSButtonSize.sm,
          onPressed: () {},
        ),
        child: Column(
          children: [
            DSListTile(
              leading: DSAvatar.fromName(name: 'Ada Lovelace'),
              title: 'Ada Lovelace',
              subtitle: 'Owner',
            ),
            DSListTile(
              leading: DSAvatar.fromName(name: 'Grace Hopper'),
              title: 'Grace Hopper',
              subtitle: 'Editor',
            ),
          ],
        ),
      ),
    ),
    DSStory(
      title: 'Eyebrow, title, actions',
      note:
          'For screens that cannot host a CustomScrollView at the top '
          'level — a TabBarView, for instance.',
      builder: (context) => StoryStage(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: DSPageHeader(
            eyebrow: 'Workspace',
            title: 'Rocketship',
            leading: IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Open navigation menu',
              onPressed: () {},
            ),
            actions: DSHeaderActions(
              children: [
                DSIconButton(
                  icon: Icons.search,
                  semanticLabel: 'Search',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ],
);
