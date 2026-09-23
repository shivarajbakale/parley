import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The pieces every other component is built on.
///
/// None of these three paints anything a designer would recognise, which is
/// exactly why they are worth a page: they are the answer to "how do I change
/// this component without editing it", and a kit whose extension seams are
/// undocumented is a kit that gets forked instead of configured.
final foundationCategory = DSCatalogCategory(
  name: 'Foundation',
  icon: Icons.layers_outlined,
  components: [
    DSComponentDemo(
      name: 'DSGround',
      summary: 'The page ground: a soft colour wash behind white cards.',
      stories: [
        DSStory(
          title: 'A page on the wash',
          note:
              'Wraps a scaffold. The scaffold paints no fill inside it, so the '
              'wash shows; a card on top keeps its own white surface. An '
              'identity with no wash gets its child back.',
          builder: (context) => SizedBox(
            height: context.design.space.xxl * 5,
            child: const DSGround(
              child: Scaffold(
                body: Center(
                  child: DSCard(
                    child: DSText(
                      'A card on the ground',
                      role: DSTextRole.body,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSText',
      summary: 'Every string the app draws, named by what it is.',
      stories: [
        DSStory(
          title: 'The roles, in the order a screen uses them',
          note:
              'The sheet to read before writing a Text. A role carries the '
              'step, the grey and the weight together, so picking one is the '
              'only decision left.',
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (role, sample) in const [
                // The sheet starts at the top of the scale. `display` was
                // missing from it, and being missing from here meant being
                // drawn nowhere at all: it is the only role on a display step,
                // so the face that step is set in — Satoshi Light — was
                // bundled into every build of every app this boilerplate
                // produces and rasterised in none of them.
                (DSTextRole.display, '1,284'),
                (DSTextRole.eyebrow, 'Friday · May 16'),
                (DSTextRole.pageTitle, 'Quarterly report'),
                (DSTextRole.sectionTitle, 'This week'),
                (DSTextRole.bodyLead, 'The opening paragraph, one step up.'),
                (
                  DSTextRole.body,
                  'Running copy, which wraps as far as it needs to and never truncates.',
                ),
                (DSTextRole.bodyDetail, 'The supporting line under it.'),
                (DSTextRole.itemTitle, 'Ada Lovelace'),
                (DSTextRole.itemSubtitle, 'Signed in two minutes ago'),
                (DSTextRole.itemMeta, '2.4 MB · 16 May'),
                (DSTextRole.fieldLabel, 'Email address'),
                (DSTextRole.fieldHelper, 'We only use this to sign you in.'),
                (DSTextRole.fieldError, 'That address is already registered.'),
                (DSTextRole.metric, '1,284'),
                (DSTextRole.metricUnit, 'sessions this week'),
              ])
                Padding(
                  padding: EdgeInsets.only(bottom: context.design.space.sm),
                  child: DSText(sample, role: role),
                ),
            ],
          ),
        ),
        DSStory(
          title: 'A line limit brings its ellipsis with it',
          note:
              'The pairing the kit kept splitting. A role that labels '
              'content truncates and says so; a role that is the content '
              'wraps, because the reader came for those words.',
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DSText(
                '2.4 MB · 16 May 2026 · uploaded from Ada’s laptop · shared with four people',
                role: DSTextRole.itemMeta,
              ),
              SizedBox(height: context.design.space.sm),
              const DSText(
                'Body is the thing itself, so it wraps for as long as the reader needs it to and no ellipsis ever appears',
                role: DSTextRole.body,
              ),
            ],
          ),
        ),
        DSStory(
          title: 'A run inside a line',
          note:
              'DSTextSpan, so an emphasised or toned word does not have to '
              'fall back to a raw Text.rich and leave the system.',
          builder: (context) => const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DSText.rich([
                DSTextSpan('Signed in as '),
                DSTextSpan('ada@example.com', emphasis: true),
              ], role: DSTextRole.body),
              DSText.rich([
                DSTextSpan('3 of 12 done · '),
                DSTextSpan('2 overdue', tone: DSTone.warning),
              ], role: DSTextRole.bodyDetail),
            ],
          ),
        ),
        DSStory(
          title: 'A container sets the size, and a tone',
          note:
              'Layer 3. The scope steps the role down its own ratio rather '
              'than naming a second size, and lends its tone to what it holds.',
          builder: (context) => const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: DSText('Default', role: DSTextRole.itemTitle)),
              Expanded(
                child: DSScope(
                  size: DSSize.sm,
                  child: DSText(
                    'In a compact footer',
                    role: DSTextRole.itemTitle,
                  ),
                ),
              ),
              Expanded(
                child: DSScope(
                  tone: DSTone.error,
                  child: DSText('Inside an error', role: DSTextRole.itemTitle),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSPressable',
      summary: 'The kit press dip, for something the kit does not already own.',
      stories: [
        DSStory(
          title: 'Around a custom surface',
          note:
              'It listens for the press and never takes the tap, so the '
              'widget underneath keeps its own callback.',
          builder: (context) {
            final schemePalette = context.palette;
            return DSPressable(
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  context.radiusOf(AppShape.tile),
                ),
                onTap: () => showDSSnackBar(context, message: 'Pressed'),
                child: Container(
                  padding: context.design.space.cardPadding,
                  decoration: BoxDecoration(
                    color: schemePalette.card,
                    borderRadius: BorderRadius.circular(
                      context.radiusOf(AppShape.tile),
                    ),
                  ),
                  child: const DSText(
                    'Press and hold me',
                    role: DSTextRole.body,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSComponentStyle',
      summary: 'A component’s appearance as data, resolvable from four places.',
      stories: [
        DSStory(
          title: 'One instance',
          note:
              'Layer 4. The narrowest override, and the only one that '
              'affects nothing else on the screen.',
          builder: (context) => const DSCard(
            style: DSCardStyle(elevation: DSElevation.none),
            child: Text(
              'A card with its shadow taken off, here and nowhere else.',
            ),
          ),
        ),
        DSStory(
          title: 'A whole subtree',
          note:
              'Layer 2. A ThemeExtension restyles every card below it '
              'without any of them being told.',
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(
              extensions: const [DSCardStyle(elevation: DSElevation.none)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DSCard(child: Text('Flat')),
                context.design.space.verticalSm,
                const DSCard(child: Text('Also flat')),
              ],
            ),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSScope',
      summary: 'What a container is allowed to tell its contents.',
      stories: [
        DSStory(
          title: 'A container sets the density',
          note:
              'Layer 3. The cards inside are tighter, and no call site '
              'says so — which is the repetition the layer removes.',
          builder: (context) => DSScope.merge(
            context,
            density: DSDensity.compact,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DSCard(child: Text('Compact')),
                context.design.space.verticalSm,
                const DSCard(child: Text('Also compact')),
              ],
            ),
          ),
        ),
        DSStory(
          title: 'An explicit argument still wins',
          note:
              'A scope supplies a default, never an override. This is the '
              'difference between it and cloning a child.',
          builder: (context) => DSScope.merge(
            context,
            density: DSDensity.compact,
            child: DSCard(
              padding: EdgeInsets.all(context.design.space.xxl),
              child: const Text('Told to be roomy, and it is.'),
            ),
          ),
        ),
      ],
    ),
  ],
);
