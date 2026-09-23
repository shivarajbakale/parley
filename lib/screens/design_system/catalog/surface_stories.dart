import 'dart:async';
import 'dart:ui' show Codec;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/demo_photo.dart';

/// The shapes content sits on.
final surfaceCategory = DSCatalogCategory(
  name: 'Surface',
  icon: Icons.dashboard_outlined,
  components: [
    DSComponentDemo(
      name: 'DSCard',
      summary: 'One grouped surface, tappable or not.',
      stories: [
        DSStory(
          title: 'Variants',
          note:
              'Elevated floats, filled groups, outlined divides. One card '
              'style per screen — mixing them reads as three systems.',
          builder: (context) => Column(
            children: [
              const DSCard(child: Text('Elevated — the default')),
              context.design.space.verticalSm,
              const DSCard(
                variant: DSCardVariant.filled,
                child: Text('Filled — a tonal group'),
              ),
              context.design.space.verticalSm,
              const DSCard(
                variant: DSCardVariant.outlined,
                child: Text('Outlined — a hairline division'),
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Tappable',
          note:
              'onTap gives it the press dip and the ink — the whole card '
              'becomes the target, not the row inside it.',
          builder: (context) => DSCard(
            onTap: () => showDSSnackBar(context, message: 'Card tapped'),
            child: Row(
              children: [
                const DSWell(icon: Icons.folder_outlined),
                context.design.space.horizontalMd,
                Expanded(
                  child: Text(
                    'Open the project',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
        DSStory(
          title: 'Header, footer, media',
          note:
              'The slots exist so a caller stops re-deriving a title row. '
              'Media sits outside the padding, so an image reaches the '
              'card\u2019s own corners.',
          builder: (context) => DSCard(
            media: DSCardMedia(
              aspectRatio: 16 / 9,
              child: ColoredBox(color: context.palette.muted),
            ),
            header: const DSCardHeader(
              title: 'Quarterly report',
              subtitle: 'Finance · Updated 2 days ago',
            ),
            footer: DSCardFooter(
              helper: const DSCardHelperText('Draft'),
              actions: [
                DSButton(
                  label: 'Open',
                  variant: DSButtonVariant.ghost,
                  onPressed: () {},
                ),
              ],
            ),
            child: const Text(
              'The body sits between the header and the footer, inside the '
              'card\u2019s own padding.',
            ),
          ),
        ),
        DSStory(
          title: 'Selected, and loading',
          note:
              'Selection draws a fill and a check: the fill alone would leave '
              'colour carrying the meaning.',
          builder: (context) => Column(
            children: [
              const DSCard(selected: true, child: Text('Selected')),
              context.design.space.verticalSm,
              const DSCardSkeleton(showHeader: true, showFooter: true),
            ],
          ),
        ),
        DSStory(
          title: 'Tone',
          note:
              'The variant says how far off the page the card sits; the tone '
              'says what it is about. A success card is still elevated, and '
              'it is the same green a success message paints.',
          builder: (context) => Column(
            children: [
              const DSCard(
                tone: DSTone.error,
                header: DSCardHeader(
                  title: 'Nightly export failed',
                  subtitle: 'Retried twice at 02:10',
                ),
                child: Text(
                  'The destination bucket refused the write. Nothing was '
                  'lost — the run will be picked up again tonight.',
                ),
              ),
              context.design.space.verticalSm,
              const DSCard(
                tone: DSTone.success,
                variant: DSCardVariant.outlined,
                child: Text('Backup completed an hour ago.'),
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Sections',
          note:
              'A rule between the header, the body and the footer, running '
              'the full width of the card. For a card that is really three '
              'sections, where a gap the size of the one inside the body '
              'does not say where one ends.',
          builder: (context) => DSCard(
            style: const DSCardStyle(dividers: true),
            header: const DSCardHeader(
              title: 'Team plan',
              subtitle: 'Renews 3 March',
            ),
            footer: DSCardFooter(
              helper: const DSCardHelperText('9 of 20 seats used'),
              actions: [
                DSButton(
                  label: 'Manage',
                  variant: DSButtonVariant.ghost,
                  onPressed: () {},
                ),
              ],
            ),
            child: const Text(
              'Unlimited projects, shared boards, and audit history for '
              'the last ninety days.',
            ),
          ),
        ),
        DSStory(
          title: 'Unavailable, and held',
          note:
              'Disabled dims the whole card and brings it down to the page — '
              'a surface nobody can reach has no business floating above one. '
              'A long press is its own gesture: this card opens nothing and '
              'still answers a hold.',
          builder: (context) => Column(
            children: [
              DSCard(
                enabled: false,
                onTap: () {},
                header: const DSCardHeader(
                  title: 'Archived workspace',
                  subtitle: 'Read-only since June',
                ),
                child: const Text('Restore it to open the boards again.'),
              ),
              context.design.space.verticalSm,
              DSCard(
                onLongPress: () =>
                    showDSSnackBar(context, message: 'Held — pick an action'),
                child: const Text('Hold this card'),
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Hero gradient',
          note:
              'At most one gradient per screen, on the Focal hero. Two and '
              'neither is the focal point.',
          builder: (context) {
            final schemePalette = context.palette;
            return DSCard(
              style: DSCardStyle(
                fillGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.palette.secondary, context.palette.card],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This week',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: schemePalette.primaryForeground,
                    ),
                  ),
                  context.design.space.verticalXs,
                  Text(
                    '4h 12m focused',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: schemePalette.primaryForeground,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSImage',
      summary: 'A picture the app did not ship, in all three of its states.',
      stories: [
        DSStory(
          title: 'Arriving, arrived, failed',
          note:
              'All three at the same size, which is the point: the box is '
              'drawn before a byte lands, so nothing under it moves when the '
              'bytes do. The middle one is a provider that never completes.',
          builder: (context) {
            final space = context.design.space;
            return Row(
              children: [
                const Expanded(
                  child: DSImage.asset(
                    DemoPhotos.crossing,
                    aspectRatio: 1,
                    semanticLabel: 'A crossing, seen from above',
                  ),
                ),
                space.horizontalSm,
                const Expanded(
                  child: DSImage.provider(
                    _NeverArrives(),
                    aspectRatio: 1,
                    decorative: true,
                  ),
                ),
                space.horizontalSm,
                const Expanded(
                  child: DSImage.network(
                    'https://example.invalid/missing.jpg',
                    aspectRatio: 1,
                    decorative: true,
                  ),
                ),
              ],
            );
          },
        ),
        DSStory(
          title: 'Shape and box',
          note:
              'The radius is a step on the shape ladder, not a number: a hero '
              'takes the card step so its corners match the surface it heads, '
              'and a thumbnail takes the tile step so it matches the row.',
          builder: (context) {
            final space = context.design.space;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DSImage.asset(
                  DemoPhotos.paletteWall,
                  aspectRatio: 16 / 9,
                  shape: AppShape.card,
                  semanticLabel: 'A wall of paint swatches',
                ),
                space.verticalSm,
                Row(
                  children: [
                    DSImage.asset(
                      DemoPhotos.flatLay,
                      width: space.xxxl,
                      height: space.xxxl,
                      semanticLabel: 'Tools laid out on a desk',
                    ),
                    space.horizontalSm,
                    DSImage.asset(
                      DemoPhotos.openBook,
                      width: space.xxxl,
                      height: space.xxxl,
                      shape: AppShape.pill,
                      semanticLabel: 'An open book',
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSPullQuote',
      summary: 'One sentence lifted out of the article it came from.',
      stories: [
        DSStory(
          title: 'A rule, not a box',
          note:
              'The rule is as tall as the words. The version this replaced '
              'hard-coded a 48-point bar, so every quote longer than two '
              'lines shipped with the rule stopping a third of the way down.',
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DSPullQuote(
                quote:
                    'A token called brand-blue-500 is a token that needs to '
                    'be re-approved every six months.',
              ),
              context.design.space.verticalLg,
              DSPullQuote(
                quote:
                    'Type is the only design choice the user reads on every '
                    'screen.',
                attribution: 'Jules Andersen',
                accentColor: context.palette.primary,
              ),
            ],
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSMessage',
      fullBleed: true,
      summary: 'A message that stays until it is acted on.',
      stories: [
        DSStory(
          title: 'Five tones',
          note:
              'Icon, tone and text — three channels, always. The two '
              'components this replaces let a message be a glyph and a hue.',
          builder: (context) => Column(
            children: [
              const DSMessage.section(
                tone: DSMessageTone.neutral,
                title: 'Draft',
                message: 'Not published. Only you can see this.',
              ),
              context.design.space.verticalSm,
              const DSMessage.section(message: 'Changes save as you type.'),
              context.design.space.verticalSm,
              const DSMessage.section(
                tone: DSMessageTone.success,
                message: 'Backup completed an hour ago.',
              ),
              context.design.space.verticalSm,
              const DSMessage.section(
                tone: DSMessageTone.warning,
                message: 'Two members have not accepted their invite.',
              ),
              context.design.space.verticalSm,
              const DSMessage.section(
                tone: DSMessageTone.error,
                title: 'The last sync failed',
                message: 'We could not reach the server at 09:40.',
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Three scopes',
          note:
              'Screen is full bleed under the app bar; section is inset '
              'inside a card; compact is one line with no affordances.',
          builder: (context) => Column(
            children: [
              const DSMessage.screen(
                tone: DSMessageTone.warning,
                title: "You're offline",
                message: 'Changes are saved locally and will sync.',
              ),
              context.design.space.verticalSm,
              const DSMessage.section(
                message: 'Two members have not accepted their invites.',
              ),
              context.design.space.verticalSm,
              const DSMessage.compact(
                message: "Read-only. You don't have edit access.",
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Action and dismiss',
          note:
              'The action is the way out of the state being reported. '
              'Dismiss without one and the problem is still there.',
          builder: (context) => _DismissDemo(
            builder: (onDismiss) => DSMessage.screen(
              tone: DSMessageTone.error,
              title: 'Your session expired',
              message: 'Sign in again to keep working — nothing was lost.',
              actionLabel: 'Sign in',
              onAction: () => showDSSnackBar(context, message: 'Signing in…'),
              onDismiss: onDismiss,
            ),
          ),
        ),
        DSStory(
          title: 'A long message wraps',
          note:
              'The one component in the kit that never truncates: a '
              'truncated error is a support ticket.',
          builder: (context) => const DSMessage.section(
            tone: DSMessageTone.warning,
            title: 'Storage is almost full',
            message:
                'This workspace is using 9.6 GB of its 10 GB. New '
                'uploads will fail once the limit is reached, and scheduled '
                'backups will stop running until there is room for them.',
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSChip',
      summary: 'A tappable filter, tag or token.',
      stories: [
        DSStory(
          title: 'Tags, tones and marks',
          note:
              'A tag takes no tab stop — it is text with a background. The '
              'tone tints the chip and its label together; a mark dot is a '
              'graphic beside a label that still reads at 4.5:1.',
          builder: (context) => DSChipGroup(
            children: [
              const DSChip(label: 'Design'),
              for (final tone in DSTone.values.skip(1))
                DSChip(label: tone.name, tone: tone),
              DSChip(
                label: 'Research',
                markColor: context.palette.mutedForeground,
              ),
              const DSChip(label: 'Documents', count: 12),
              const DSChip(
                label: 'A label long enough that it has to be cut short',
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Sizes, disabled and loading',
          note:
              'The visual height is 28 or 32 and the target is 48 at both — '
              'the decoupling is the whole reason this component exists.',
          builder: (context) => const DSChipGroup(
            children: [
              DSChip(label: 'Small', size: DSChipSize.sm),
              DSChip(label: 'Medium'),
              DSChip(label: 'Unavailable', enabled: false),
              DSChip(label: 'Loading', loading: true),
              DSChip(label: 'Loading more', loading: true),
            ],
          ),
        ),
        DSStory(
          title: 'Selectable and deletable',
          note:
              'onSelected makes it a filter; onDeleted makes it a token the '
              'user put there.',
          builder: (context) => const _ChipDemo(),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSBadge',
      summary: 'A short status or count, attached to something else.',
      stories: [
        DSStory(
          title: 'Status and count',
          note: 'Read, never pressed — the same pill shape on both platforms.',
          builder: (context) {
            return Wrap(
              spacing: context.design.space.sm,
              runSpacing: context.design.space.sm,
              children: const [
                DSBadge(label: 'Draft'),
                DSBadge(label: 'Live', tone: DSTone.success, showDot: true),
                DSBadge(label: 'Overdue', tone: DSTone.error),
                DSBadge(label: 'Beta', tone: DSTone.info),
              ],
            );
          },
        ),
        DSStory(
          title: 'In a row',
          note:
              'The trailing slot of a list row is where a status badge '
              'belongs — one per row, never two.',
          builder: (context) => const DSListTile(
            title: 'Quarterly report',
            subtitle: 'Edited 2 hours ago',
            trailing: DSBadge(label: 'Draft'),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSAvatar',
      summary: 'A person or entity’s identity, with an initials fallback.',
      stories: [
        DSStory(
          title: 'Sizes',
          note: 'sm in a row, md in a tile, lg in a header, xl on a profile.',
          builder: (context) => Wrap(
            spacing: context.design.space.sm,
            runSpacing: context.design.space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              DSAvatar(initials: 'AB', size: DSAvatarSize.sm),
              DSAvatar(initials: 'AB'),
              DSAvatar(initials: 'AB', size: DSAvatarSize.lg),
              DSAvatar(initials: 'AB', size: DSAvatarSize.xl),
            ],
          ),
        ),
        DSStory(
          title: 'From a name, and the icon fallback',
          note:
              'fromName derives the initials and a stable tint, so the same '
              'person is the same colour on every screen.',
          builder: (context) => Wrap(
            spacing: context.design.space.sm,
            runSpacing: context.design.space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DSAvatar.fromName(name: 'Ada Lovelace'),
              DSAvatar.fromName(name: 'Grace Hopper'),
              DSAvatar.fromName(name: 'Rocketship Team'),
              const DSAvatar(fallbackIcon: Icons.person_outline),
            ],
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSWell',
      summary: 'The tinted round icon holder inside cards and tiles.',
      stories: [
        DSStory(
          title: 'Sizes and tints',
          note:
              'A category or an action. When it stands for a *person*, it is '
              'a DSAvatar.',
          builder: (context) {
            return Wrap(
              spacing: context.design.space.sm,
              runSpacing: context.design.space.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: const [
                DSWell(icon: Icons.bolt, size: DSWellSize.sm),
                DSWell(icon: Icons.notifications_outlined),
                DSWell(
                  icon: Icons.shield_outlined,
                  tone: DSTone.error,
                  size: DSWellSize.lg,
                ),
              ],
            );
          },
        ),
      ],
    ),
  ],
);

/// Shows a dismissible surface and puts it back, so the story can be replayed
/// without leaving the page.
class _DismissDemo extends StatefulWidget {
  final Widget Function(VoidCallback onDismiss) builder;

  const _DismissDemo({required this.builder});

  @override
  State<_DismissDemo> createState() => _DismissDemoState();
}

class _DismissDemoState extends State<_DismissDemo> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: DSButton(
          label: 'Bring it back',
          variant: DSButtonVariant.ghost,
          onPressed: () => setState(() => _visible = true),
        ),
      );
    }
    return widget.builder(() => setState(() => _visible = false));
  }
}

class _ChipDemo extends StatefulWidget {
  const _ChipDemo();

  @override
  State<_ChipDemo> createState() => _ChipDemoState();
}

class _ChipDemoState extends State<_ChipDemo> {
  final _selected = <String>{'Design'};
  final _tokens = <String>['ada@example.com', 'grace@example.com'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSChipGroup(
          selectedFirst: true,
          maxVisible: 4,
          children: [
            for (final tag in const [
              'Design',
              'Research',
              'Ops',
              'Support',
              'Finance',
            ])
              DSChip(
                label: tag,
                role: DSChipRole.filter,
                selected: _selected.contains(tag),
                onSelected: (on) => setState(() {
                  if (on) {
                    _selected.add(tag);
                  } else {
                    _selected.remove(tag);
                  }
                }),
              ),
          ],
        ),
        context.design.space.verticalMd,
        DSChipGroup(
          children: [
            for (final token in _tokens)
              DSChip(
                label: token,
                role: DSChipRole.input,
                leading: const DSChipAvatar(child: Icon(Icons.person_outline)),
                onRemove: () => setState(() => _tokens.remove(token)),
              ),
            if (_tokens.isEmpty)
              DSButton(
                label: 'Reset',
                size: DSButtonSize.sm,
                variant: DSButtonVariant.ghost,
                onPressed: () => setState(() {
                  _tokens.addAll(['ada@example.com', 'grace@example.com']);
                }),
              ),
          ],
        ),
      ],
    );
  }
}

/// A provider that never completes, so the arriving state can be looked at.
///
/// A real fetch resolves in a few hundred milliseconds, which is long enough
/// to be a defect on a slow connection and too short to review in a gallery.
class _NeverArrives extends ImageProvider<_NeverArrives> {
  const _NeverArrives();

  @override
  Future<_NeverArrives> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_NeverArrives>(this);

  @override
  ImageStreamCompleter loadImage(
    _NeverArrives key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: Completer<Codec>().future,
    scale: 1,
  );

  @override
  bool operator ==(Object other) => other is _NeverArrives;

  @override
  int get hashCode => (_NeverArrives).hashCode;
}
