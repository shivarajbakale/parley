import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/catalog.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// One component, every usage the gallery knows about — the **Detail**
/// archetype for [ComponentGalleryPage].
///
/// Each story is live, not a screenshot: the switches flip, the sheets open,
/// the cascade replays. A gallery of pictures answers what a component looks
/// like; the point of this one is what it does when it is used.
class ComponentPage extends StatelessWidget {
  /// The component's class name, from the route — `DSButton`, `DSCard`.
  final String name;

  const ComponentPage({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final component = componentDemoNamed(name);
    if (component == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Component')),
        body: DSEmptyState(
          icon: Icons.help_outline,
          title: '$name is not part of the design system.',
        ),
      );
    }

    final theme = Theme.of(context);

    return DSPage(
      title: component.name,
      slivers: [
        SliverToBoxAdapter(
          child: DSGutter(
            child: Padding(
              padding: EdgeInsets.only(bottom: context.design.space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTypography.eyebrowCase(context, categoryOf(component)),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.palette.mutedForeground,
                    ),
                  ),
                  context.design.space.verticalXs,
                  DSText(component.summary, role: DSTextRole.bodyLead),
                  context.design.space.verticalXs,
                  // One line, not a section message. The same sentence sits on
                  // all fifty component pages, and as a bordered card it cost
                  // 164 points of the first screenful — pushing the first live
                  // component past the fold on a phone. A note that never
                  // changes is a footnote, not a banner.
                  const DSText(
                    'Selection guidance: '
                    'docs/references/design-system-reference-llms.txt',
                    role: DSTextRole.bodyDetail,
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverList.builder(
          itemCount: component.stories.length,
          itemBuilder: (context, index) => _StorySection(
            story: component.stories[index],
            index: index,
            fullBleed:
                component.stories[index].fullBleed ?? component.fullBleed,
          ),
        ),
      ],
    );
  }
}

/// One usage: its name, the line that says when to reach for it, and the live
/// widget under both.
///
/// The section body sits inside the page gutter, with a uniform gap below it
/// — the gutter is the page's, and the gap is the section's, but neither
/// belongs to the widget the story shows. Without `contentPadding` here,
/// every story rendered edge-to-edge (the gallery's neighbour, by contrast,
/// was inside the gutter — see `gallery_page.dart`).
class _StorySection extends StatelessWidget {
  final DSStory story;
  final int index;

  /// The story's widget insets itself to the gutter, so the frame must not.
  final bool fullBleed;

  const _StorySection({
    required this.story,
    required this.index,
    required this.fullBleed,
  });

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;

    return DSSection(
      label: story.title,
      // The page still owns the gutter; it just applies it per child rather
      // than across the whole body, because one of the two children may
      // decline it. `DSSection` ships its body at `EdgeInsets.zero`, so the
      // vertical half of what used to be here stays the section's own gap.
      contentPadding: EdgeInsets.only(bottom: space.lg),
      child: Column(
        // `stretch` (the prior default) and `start` look identical here, but
        // the stories inside this column are a mixed bag of `Wrap`s, `Align`
        // wrappers and full-width inputs — keeping `stretch` means a single
        // `DSButton` or `DSCard` fills the available width without each story
        // adding its own alignment.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The note is prose and always sits in the gutter, level with the
          // section label above it.
          Padding(
            padding: _storyGutter(context, fullBleed: false),
            child: DSText(story.note, role: DSTextRole.bodyDetail),
          ),
          space.verticalMd,
          Padding(
            padding: _storyGutter(context, fullBleed: fullBleed),
            child: Builder(builder: story.builder),
          ),
        ],
      ),
    );
  }
}

/// The horizontal lane one story body sits in.
///
/// The single owner of the story gutter, and the reason `ui_lint`'s
/// `catalog-gutter` rule accepts a `DSSection` here whose `contentPadding`
/// carries no horizontal component: the gutter did not disappear, it moved
/// one level down so that a [DSStory.fullBleed] widget can decline it.
///
/// [fullBleed] widgets already inset their own content to `space.pageGutter`
/// — that is what lets a list row run its divider to the edge — so paying it
/// again here put them one whole gutter deeper than the note above them.
EdgeInsets _storyGutter(BuildContext context, {required bool fullBleed}) =>
    fullBleed
    ? EdgeInsets.zero
    : EdgeInsets.symmetric(horizontal: DSGutter.of(context));
