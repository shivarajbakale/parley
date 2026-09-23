import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';

final dsSectionHeaderDemo = DSComponentDemo(
  name: 'DSSectionHeader',
  fullBleed: true,
  summary: 'A title above a group.',
  stories: [
    DSStory(
      title: 'Plain and with an action',
      note:
          'The trailing action is the escape to the full list — "See '
          'all", never a second primary button.',
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DSSectionHeader(label: 'Recent'),
          DSSectionHeader(
            label: 'Shared with you',
            trailing: DSButton(
              label: 'See all',
              variant: DSButtonVariant.ghost,
              size: DSButtonSize.sm,
              onPressed: () {},
            ),
          ),
        ],
      ),
    ),
  ],
);
