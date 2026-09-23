import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

final dsDividerDemo = DSComponentDemo(
  name: 'DSDivider',
  summary: 'One hairline, in the kit\'s weight and the kit\'s grey.',
  stories: [
    DSStory(
      title: 'Full bleed and inset',
      note:
          'The inset rule starts where the row\'s text starts, which is '
          'the standard list rhythm. Both occupy exactly their own '
          'thickness — the space around them is the caller\'s.',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Above'),
          context.design.space.verticalSm,
          const DSDivider(),
          context.design.space.verticalSm,
          const Text('Between'),
          context.design.space.verticalSm,
          DSDivider(indent: context.design.space.xxl),
          context.design.space.verticalSm,
          const Text('Below'),
        ],
      ),
    ),
    DSStory(
      title: 'Vertical, between a pair',
      note:
          'Fills the height it is given, so it needs a bounded cross '
          'axis — an IntrinsicHeight here, a SizedBox elsewhere.',
      builder: (context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: Text('This week')),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.design.space.md,
              ),
              child: const DSDivider.vertical(),
            ),
            const Expanded(child: Text('Last week')),
          ],
        ),
      ),
    ),
  ],
);
