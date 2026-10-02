import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/catalog/structure_shared_widgets.dart';

final dsPageDemo = DSComponentDemo(
  name: 'DSPage',
  fullBleed: true,
  summary:
      'The page scaffold: a header, a scroll, and the clearance '
      'under both.',
  stories: [
    DSStory(
      title: 'Sections down a page',
      note:
          'The page pads nothing. DSPageSection is what puts the card and '
          'the paragraph on the reading edge, and DSListTile insets its '
          'own content — which is why the rows line up with the section '
          'labels while their dividers still run to the edge.',
      builder: (context) => SizedBox(
        height: 320,
        child: StoryStage(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: DSPage(
              title: 'Workspace',
              slivers: [
                const DSPageSection(
                  first: true,
                  title: 'This week',
                  child: DSCard(
                    child: Text(
                      'A box inside a section takes the full section '
                      'width. A card that adds its own margin starts one '
                      'gutter further in than the rows below it.',
                    ),
                  ),
                ),
                const DSPageSectionHeader(title: 'Members'),
                SliverList.list(
                  children: const [
                    DSListTile(title: 'Ada Lovelace', subtitle: 'Owner'),
                    DSListTile(title: 'Grace Hopper', subtitle: 'Editor'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    DSStory(
      title: 'A label over a list',
      note:
          'DSPageSectionHeader rather than a titled DSPageSection: a '
          'SliverList inside a section would need a SliverToBoxAdapter, '
          'which builds every row in one pass and gives up the laziness '
          'that made it a sliver.',
      builder: (context) => SizedBox(
        height: 260,
        child: StoryStage(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: DSPage(
              title: 'Library',
              slivers: [
                const DSPageSectionHeader(first: true, title: 'Recent'),
                SliverList.builder(
                  itemCount: 6,
                  itemBuilder: (context, index) => DSListTile(
                    title: 'Row ${index + 1}',
                    subtitle: 'Its text starts on the page gutter',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    DSStory(
      title: 'Clearance under a pinned bar',
      note:
          'The page installs the bottom-inset host, so the action bar '
          'reports its own height and the scroll ends above it. Ten '
          'screens carried a bar or a floating button with no host over '
          'them, so the last row sat underneath it.',
      builder: (context) => SizedBox(
        height: 300,
        child: StoryStage(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: DSPage(
              title: 'Checkout',
              footer: DSPinnedActionBar(
                children: [DSButton(label: 'Place order', onPressed: () {})],
              ),
              slivers: [
                SliverList.builder(
                  itemCount: 6,
                  itemBuilder: (context, index) => DSListTile(
                    title: 'Line ${index + 1}',
                    subtitle: 'Scroll: the last one clears the bar',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    DSStory(
      title: 'The gutter on its own',
      note:
          'DSGutter is the inset without the rhythm — for a sliver that '
          'has to stay a sliver, or a box whose vertical space belongs to '
          'something else.',
      builder: (context) => const DSGutter(
        child: DSCard(
          child: Text(
            'This card is on the page gutter and supplies its own '
            'vertical space.',
          ),
        ),
      ),
    ),
  ],
);
