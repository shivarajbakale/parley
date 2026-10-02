import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Things the user presses.
final actionCategory = DSCatalogCategory(
  name: 'Action',
  icon: Icons.touch_app_outlined,
  components: [
    DSComponentDemo(
      name: 'DSButton',
      summary: 'The tap that makes something happen.',
      stories: [
        DSStory(
          title: 'Variants',
          note: 'One primary per screen. Everything else steps down from it.',
          builder: (context) => Wrap(
            spacing: context.design.space.sm,
            runSpacing: context.design.space.sm,
            children: [
              DSButton(label: 'Primary', onPressed: () {}),
              DSButton(
                label: 'Secondary',
                variant: DSButtonVariant.secondary,
                onPressed: () {},
              ),
              DSButton(
                label: 'Outlined',
                variant: DSButtonVariant.outlined,
                onPressed: () {},
              ),
              DSButton(
                label: 'Ghost',
                variant: DSButtonVariant.ghost,
                onPressed: () {},
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Intent',
          note:
              'Destructive is the only intent that is a variant: it changes '
              'the confirm idiom and the haptic, not only the fill. Success, '
              'warning and info are two style fields, at whichever layer '
              'suits — a green Retry is still a secondary action.',
          builder: (context) => Wrap(
            spacing: context.design.space.sm,
            runSpacing: context.design.space.sm,
            children: [
              DSButton(
                label: 'Delete project',
                icon: Icons.delete_outline,
                variant: DSButtonVariant.destructive,
                onPressed: () {},
              ),
              DSButton(
                label: 'Approve',
                icon: Icons.check,
                variant: DSButtonVariant.secondary,
                style: DSButtonStyle(
                  fillColor: context.palette.success,
                  labelColor: context.palette.onSuccess,
                ),
                onPressed: () {},
              ),
              DSButton(
                label: 'Review',
                icon: Icons.warning_amber_outlined,
                variant: DSButtonVariant.secondary,
                style: DSButtonStyle(
                  fillColor: context.palette.tint(context.palette.warning),
                  labelColor: context.palette.foreground,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Sizes',
          note:
              'sm inside a dense row, md everywhere else, lg for the one '
              'action a screen exists for.',
          builder: (context) => Wrap(
            spacing: context.design.space.sm,
            runSpacing: context.design.space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DSButton(label: 'Small', size: DSButtonSize.sm, onPressed: () {}),
              DSButton(label: 'Medium', onPressed: () {}),
              DSButton(label: 'Large', size: DSButtonSize.lg, onPressed: () {}),
            ],
          ),
        ),
        DSStory(
          title: 'Full width',
          note: 'The Form archetype: bottom, full width, above the safe area.',
          builder: (context) => DSButton(
            label: 'Continue',
            icon: Icons.arrow_forward,
            fullWidth: true,
            onPressed: () {},
          ),
        ),
        DSStory(
          title: 'Loading',
          note:
              'One honest behaviour, not three: the label stays, the width '
              'does not change, and a spinner leads. A button that becomes a '
              'spinner loses the user\u2019s place and reflows the layout.',
          builder: (context) => Wrap(
            spacing: context.design.space.sm,
            runSpacing: context.design.space.sm,
            children: const [
              DSButton(label: 'Saving', loading: true),
              DSButton(
                label: 'Saving',
                variant: DSButtonVariant.secondary,
                loading: true,
              ),
              DSButton(
                label: 'Saving',
                variant: DSButtonVariant.outlined,
                loading: true,
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Disabled',
          note:
              'A null onPressed. Disable while a submit is in flight; never '
              'as a substitute for saying what is missing.',
          builder: (context) => Wrap(
            spacing: context.design.space.sm,
            runSpacing: context.design.space.sm,
            children: const [
              DSButton(label: 'Primary'),
              DSButton(label: 'Outlined', variant: DSButtonVariant.outlined),
            ],
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSIconButton',
      summary: 'A secondary action in a dense row, where the icon is enough.',
      stories: [
        DSStory(
          title: 'Two variants, three sizes',
          note:
              'Filled reads as the action of the row it sits in; standard '
              'reads as one of several. Every size keeps a 48dp target — the '
              'glyph shrinks, the tap area does not.',
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final variant in DSIconButtonVariant.values)
                Padding(
                  padding: EdgeInsets.only(bottom: context.design.space.sm),
                  child: DSIconButtonGroup(
                    children: [
                      for (final size in DSIconButtonSize.values)
                        DSIconButton(
                          icon: Icons.edit_outlined,
                          semanticLabel: 'Edit, ${variant.name} ${size.name}',
                          variant: variant,
                          size: size,
                          onPressed: () {},
                        ),
                      DSIconButton(
                        icon: Icons.edit_outlined,
                        semanticLabel: 'Edit, disabled',
                        variant: variant,
                      ),
                      DSIconButton(
                        icon: Icons.edit_outlined,
                        semanticLabel: 'Saving',
                        variant: variant,
                        loading: true,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        DSStory(
          title: 'Five tones',
          note:
              'tone replaces the destructive constructor, and it is the '
              'same five words every other component in the kit uses.',
          builder: (context) => DSIconButtonGroup(
            children: [
              for (final tone in DSTone.values)
                DSIconButton(
                  icon: Icons.delete_outline,
                  semanticLabel: 'Delete, ${tone.name}',
                  tone: tone,
                  onPressed: () {},
                ),
            ],
          ),
        ),
        DSStory(
          title: 'A toggle swaps its glyph, and a badge joins the name',
          note:
              'A fill alone would be colour carrying the state on its own. '
              'The badge count is read as part of the button — it is not a '
              'second thing to tab to.',
          builder: (context) => const _IconButtonToggleDemo(),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSFab',
      summary: 'The one screen-level action, floating over the content.',
      stories: [
        DSStory(
          title: 'Action',
          note: 'Two FABs on one screen means neither was the primary action.',
          builder: (context) =>
              DSFab(icon: Icons.add, semanticLabel: 'Add', onPressed: () {}),
        ),
        DSStory(
          title: 'Extended',
          note:
              'A label when the icon alone would be a guess — the first time '
              'a user meets the action.',
          builder: (context) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: DSFab(
              icon: Icons.edit_outlined,
              label: 'New note',
              onPressed: () {},
            ),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSMenu',
      summary: 'Three to seven actions on one item, behind an overflow.',
      stories: [
        DSStory(
          title: 'Overflow trigger',
          note: 'The default: the vertical dots, in a row or an app bar.',
          builder: (context) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: DSMenu(
              semanticLabel: 'Actions for this document',
              items: [
                DSMenuItem(
                  label: 'Share',
                  icon: Icons.share_outlined,
                  shortcut: '⌘S',
                  onPressed: () =>
                      showDSSnackBar(context, message: 'Selected: share'),
                ),
                DSMenuItem(
                  label: 'Rename',
                  icon: Icons.edit_outlined,
                  onPressed: () =>
                      showDSSnackBar(context, message: 'Selected: rename'),
                ),
                const DSMenuItem(
                  label: 'Move',
                  icon: Icons.drive_file_move_outlined,
                  disabledReason: 'Not available offline',
                ),
                const DSMenuSeparator(),
                DSMenuItem(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  tone: DSTone.error,
                  shortcut: '⌘⌫',
                  onPressed: () =>
                      showDSSnackBar(context, message: 'Selected: delete'),
                ),
              ],
            ),
          ),
        ),
        DSStory(
          title: 'Custom trigger',
          note: 'Any widget can open it — a chip, an avatar, a row of text.',
          builder: (context) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: _SortMenuDemo(),
          ),
        ),
      ],
    ),
  ],
);

/// A toggle and a badge that actually change, so the glyph swap and the
/// folded-in count can be seen rather than described.
class _IconButtonToggleDemo extends StatefulWidget {
  const _IconButtonToggleDemo();

  @override
  State<_IconButtonToggleDemo> createState() => _IconButtonToggleDemoState();
}

class _IconButtonToggleDemoState extends State<_IconButtonToggleDemo> {
  bool _saved = false;
  int _unread = 3;

  @override
  Widget build(BuildContext context) => DSIconButtonGroup(
    children: [
      DSIconButton(
        icon: Icons.bookmark_border,
        selectedIcon: Icons.bookmark,
        selected: _saved,
        semanticLabel: _saved ? 'Remove from saved' : 'Save for later',
        onPressed: () => setState(() => _saved = !_saved),
      ),
      DSIconButton(
        icon: Icons.notifications_none,
        semanticLabel: 'Notifications',
        badgeCount: _unread,
        onPressed: () => setState(() => _unread = _unread == 0 ? 3 : 0),
      ),
      DSIconButton(
        icon: Icons.add,
        semanticLabel: 'Compose',
        variant: DSIconButtonVariant.filled,
        onPressed: () {},
      ),
    ],
  );
}

/// A menu whose radio group actually moves, so "picks one of a group, closes"
/// can be seen rather than described.
class _SortMenuDemo extends StatefulWidget {
  @override
  State<_SortMenuDemo> createState() => _SortMenuDemoState();
}

class _SortMenuDemoState extends State<_SortMenuDemo> {
  String _sort = 'recent';
  bool _hidden = false;

  @override
  Widget build(BuildContext context) => DSMenu(
    semanticLabel: 'Sort',
    tooltip: 'Sort',
    trigger: const DSChip(label: 'Sort', icon: Icons.sort),
    items: [
      const DSMenuSection(label: 'View'),
      DSMenuCheckItem(
        label: 'Show hidden files',
        value: _hidden,
        onChanged: (value) => setState(() => _hidden = value),
      ),
      const DSMenuSeparator(),
      const DSMenuSection(label: 'Sort by'),
      for (final option in const ['recent', 'name', 'size'])
        DSMenuRadioItem<String>(
          label: option,
          value: option,
          groupValue: _sort,
          onChanged: (value) => setState(() => _sort = value),
        ),
    ],
  );
}
