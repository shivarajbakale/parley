import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/inbox_data.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The inbox demo — `DSTabBar` across the top, `DSSegmentedButton` above the
/// list, every row a `DSListTile`.
///
/// Lives in `screens/design_system/` because it is a demo: it proves that two
/// tab-bar-shaped components, side by side on one screen, can each carry
/// their own meaning (one gates *which* notifications show, the other sorts
/// *how* the active section is ordered) without either competing with the
/// other or hand-rolling any chrome.
///
/// Delete this file and `inbox_data.dart` with the rest of the design-system
/// demo surface when the app ships a real inbox.
class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  InboxSection _section = InboxSection.all;
  InboxSort _sort = InboxSort.newest;

  void _setSection(InboxSection next) {
    if (_section == next) return;
    setState(() => _section = next);
  }

  void _setSort(InboxSort next) {
    if (_sort == next) return;
    setState(() => _sort = next);
  }

  @override
  Widget build(BuildContext context) {
    final sectionTabs = InboxSection.values
        .map((s) => sectionSummary(s))
        .toList(growable: false);

    final items = inboxItems(_section, _sort);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          DSLargeAppBar(
            title: 'Inbox',
            // The line the `_Intro` widget used to render directly beneath
            // the bar. In the header it is the page's one supporting line
            // rather than a paragraph competing with the controls below it.
            subtitle: _introLine(
              unreadCount: demoInboxItems.where((i) => i.isUnread).length,
              totalCount: demoInboxItems.length,
            ),
          ),
          // Pinned, not a `SliverToBoxAdapter`: the app bar above is pinned
          // too, so the controls used to slide under it after about 110
          // points of scroll and switching section meant flinging back to
          // the top of the list first. `DSPinnedHeader` takes its height from
          // the child, so the band stays the height of the two controls at
          // the reader's text size rather than a number to recompute.
          DSPinnedHeader(
            child: _ControlsHeader(
              section: _section,
              sort: _sort,
              sections: sectionTabs,
              onSection: _setSection,
              onSort: _setSort,
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(section: _section),
            )
          else
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _InboxRow(item: item, section: _section);
              },
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height:
                  context.design.space.xl +
                  MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

/// The sentence that sets up the screen, carried by the header's subtitle so
/// the page has one headline block rather than a bar and a paragraph under it.
String _introLine({required int unreadCount, required int totalCount}) =>
    '$unreadCount unread of $totalCount — the tabs gate what shows, the '
    'segmented control sorts it.';

/// The two tab bars, stacked. The tab bar owns the section; the segmented
/// control owns the sort.
class _ControlsHeader extends StatelessWidget {
  const _ControlsHeader({
    required this.section,
    required this.sort,
    required this.sections,
    required this.onSection,
    required this.onSort,
  });

  final InboxSection section;
  final InboxSort sort;
  final List<({String label, IconData icon, int? count})> sections;
  final ValueChanged<InboxSection> onSection;
  final ValueChanged<InboxSort> onSort;

  @override
  Widget build(BuildContext context) {
    // The opaque ground is `DSPinnedHeader`'s — the band it pins is never
    // the one that has to remember the rows scroll behind it.
    return DSGutter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The section tabs. `DSTabLayout.scrollable` is explicit because
          // four icon+label+count tabs at 320pt would clip the labels under
          // the fixed-with-icons layout the auto switch does not always pick.
          DSTabBar(
            layout: DSTabLayout.scrollable,
            index: section.index,
            onIndexChanged: (i) {
              if (i >= 0 && i < InboxSection.values.length) {
                onSection(InboxSection.values[i]);
              }
            },
            tabs: [
              for (final s in sections)
                // No `count` here: four labels with counts overflow the
                // tab's own tap floor at 320pt and the probe's `target`
                // rule fires on the partly-visible tab. The intro line
                // above the controls reads the totals for every section.
                DSTab(label: s.label),
            ],
          ),
          SizedBox(height: context.design.space.md),
          // The sort segmented control. Owns the row — no icon or label
          // prefix, because at 1.3× text scale a prefix would push
          // "Priority" off the end and the segmented control would no longer
          // be the row's only occupant. `fill` sizing lets the longest
          // label claim a proportional share of the row rather than each
          // segment being a third of the total.
          DSSegmentedButton<InboxSort>(
            sizing: DSSegmentedSizing.fill,
            segments: [
              for (final s in InboxSort.values)
                DSSegment<InboxSort>(
                  value: s,
                  label: switch (s) {
                    InboxSort.newest => 'Newest',
                    InboxSort.oldest => 'Oldest',
                    InboxSort.priority => 'Priority',
                  },
                ),
            ],
            selected: sort,
            onChanged: onSort,
          ),
          SizedBox(height: context.design.space.md),
        ],
      ),
    );
  }
}

/// The empty state. Reached when a section has no items, which is
/// deliberately a state and not a missing branch — `DSSegmentedButton` in
/// particular reads as broken if it can select a section that yields zero
/// rows, and an empty placeholder is what keeps the role honest.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.section});

  final InboxSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return DSGutter(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sectionSummary(section).icon,
              // The one glyph that stands for the whole state, so it takes
              // the hero step rather than a hand-typed size between rungs.
              size: context.design.component.glyphHero,
              color: palette.mutedForeground,
            ),
            SizedBox(height: context.design.space.md),
            Text(
              'Nothing in ${sectionSummary(section).label}',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.design.space.xs),
            const DSText(
              'Notifications that match this section will show here.',
              align: TextAlign.center,
              role: DSTextRole.bodySupport,
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the list.
///
/// A `DSListTile`, because every demo page in the kit builds its rows out of
/// the kit's row, and "the row is the row" is the easiest thing to keep
/// consistent. The avatar is the sender's identity, the chip carries the
/// kind (replacing a status badge that would otherwise sit over the
/// avatar's initials — see `flutter-040`'s overlap rule), and the trailing
/// slot is the unread dot or an ellipsis the demo does not act on.
class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.item, required this.section});

  final InboxItem item;
  final InboxSection section;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final space = context.design.space;

    return DSListTile(
      leading: DSAvatar.fromName(name: item.senderName, size: DSAvatarSize.md),
      title: item.subject,
      // `wrap: true` lets the subject use two lines at 320pt — without it
      // every headline like "flagged a regression in Tokens / Motion" is
      // cut with an ellipsis and the probe's `clipped-text` rule fires.
      wrap: true,
      subtitle: item.preview,
      meta: Wrap(
        spacing: space.sm,
        runSpacing: space.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DSChip(label: item.kindLabel, tone: item.tone, icon: item.kindIcon),
          // The timestamp + priority use `palette.mutedForeground` directly
          // rather than `DSListTileMeta`, which paints in `textTertiary`
          // (3.82:1 against the page surface on the light theme). The
          // probe's contrast rule fails a paragraph below 4.5:1, so the
          // meta row reaches into the higher-contrast colour itself.
          _MetaText(
            icon: Icons.schedule,
            label: relativeTime(item.timestamp, now: inboxReferenceNow),
          ),
          if (item.priority >= 1)
            _MetaText(
              icon: Icons.flag_outlined,
              label: item.priority == 2 ? 'Urgent' : 'High',
              tone: item.priority == 2 ? DSTone.error : DSTone.warning,
            ),
        ],
      ),
      // The trailing slot. The unread dot is a `DSBadgeDot`; otherwise a
      // single ellipsis glyph stands in for a menu the demo does not need.
      trailing: item.isUnread
          // ignore: prefer_const_constructors
          ? DSBadgeDot(tone: DSTone.info)
          : Icon(
              Icons.more_horiz,
              size: context.design.component.iconSizeInline,
              color: palette.mutedForeground,
            ),
      // The row paints in the active section's tone only for the "Assigned"
      // tab — that's the one where the user has work to do, so the row's
      // tone is also a UI hint, not just a chip colour.
      tone: switch (section) {
        InboxSection.assigned =>
          item.priority == 2 ? DSTone.error : DSTone.warning,
        _ => DSTone.neutral,
      },
      // Selecting a row in the static demo "reads" it: tapping surfaces a
      // snack bar. The unread dot does not flip — the demo's read state is
      // ephemeral, on purpose, so the next visit sees the same unread map.
      onTap: () {
        showDSSnackBar(
          context,
          message: 'Marked as read',
          icon: Icons.mark_email_read_outlined,
          tone: DSTone.success,
        );
      },
      divider: true,
    );
  }
}

/// A short meta label with an icon. The same shape as [DSListTileMeta], but
/// the colour is read off [palette.mutedForeground] rather than `textTertiary`
/// so a 13pt label clears the probe's 4.5:1 floor on the light theme.
///
/// Sized as a row, not a column, so a long label and a short one sit on the
/// same baseline — the meta slot of a list row is one line, and a column
/// would push the timestamp below the chip rather than beside it.
class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.label, this.tone});

  final IconData icon;
  final String label;
  final DSTone? tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final space = context.design.space;
    final color = switch (tone) {
      DSTone.error => palette.destructive,
      DSTone.warning => palette.warning,
      _ => palette.mutedForeground,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: context.design.component.iconSizeSmall, color: color),
        SizedBox(width: space.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
