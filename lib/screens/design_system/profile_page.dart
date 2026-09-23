import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/screens/design_system/profile_data.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The reader's own profile — the **Detail** archetype
/// (`docs/principles/screen-archetypes.md`): one subject at the top, its
/// content in titled sections below, one primary pinned above the safe area.
///
/// Where `library_detail_page.dart` proves that shape against a book, this
/// proves it against a person, and picks up the design-system atoms the rest
/// of the demo surface never needed: `DSAvatar` (identity-derived, so the
/// same reader is the same colour everywhere a name renders one), a
/// two-column `DSStatTileGrid`, and `DSChip` in its `tag` role rather than
/// its `filter` role — a badge is read, never toggled, and the same chip the
/// Library uses to filter is wrong the moment it grows an `onSelected`.
///
/// The name and the email are real, read from [currentUserProvider] — this
/// is the signed-in reader's own page, not a stranger's — and the bio, the
/// activity and the badges are demo content, the same way the Library's
/// three books and the Blog's two articles are: content a real app supplies
/// and this template does not.
///
/// Delete this file and `profile_data.dart` with the rest of the
/// design-system demo surface when the app ships a real profile.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, this.initialSection = ProfileSection.activity});

  /// Which section the screen opens on. `test/_screens.dart` registers one
  /// entry per section, because a segmented control the probe only ever
  /// sees one side of is a control whose other side is measured by nothing.
  final ProfileSection initialSection;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late ProfileSection _section = widget.initialSection;

  void _setSection(ProfileSection next) {
    if (_section == next) return;
    setState(() => _section = next);
  }

  void _onMenu(String value) => showDSSnackBar(
    context,
    message:
        'Wire "$value" to your own action in '
        'lib/screens/design_system/profile_page.dart.',
  );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final palette = context.palette;
    final space = context.design.space;
    final name = user?.displayName ?? 'Reader';
    // The bar this screen pins reports its own height here, so a snack bar
    // does not land on it and the button does not sit on its primary control.
    // Without the host each of the three floats independently and none of them
    // knows the others exist; `DSFab.hideOnScroll` reads a DSScrollRetreat
    // that nothing publishes.

    return DSBottomInsetsHost(
      child: Scaffold(
        // Not extended: the activity list is genuinely longer than a library
        // item's description, and `extendBody` lets content paint behind the
        // bar at every scroll offset, not only the scrolled-past one — which is
        // fine for a screen short enough that nothing but the tail ever reaches
        // there, and is exactly the defect `ui-probe`'s overlap rule catches on
        // one that runs longer.
        body: CustomScrollView(
          slivers: [
            DSCompactAppBar(
              // Compact, not large: the name is the headline drawn once, in
              // the body below, next to the avatar it belongs with — a large
              // collapsing title repeating the same name a second time is the
              // header spending its budget on a duplicate rather than payload.
              title: 'Profile',
              actions: [
                DSMenu(
                  semanticLabel: 'Profile actions',
                  items: [
                    DSMenuItem(
                      label: 'Share profile',
                      icon: Icons.ios_share,
                      onPressed: () => _onMenu('Share profile'),
                    ),
                    DSMenuItem(
                      label: 'Copy link',
                      icon: Icons.link,
                      onPressed: () => _onMenu('Copy link'),
                    ),
                  ],
                ),
              ],
            ),
            DSGutter.sliver(
              sliver: SliverList.list(
                children: [
                  SizedBox(height: space.sm),
                  Center(
                    child: DSAvatar.fromName(name: name, size: DSAvatarSize.lg),
                  ),
                  SizedBox(height: space.sm),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (user?.email != null) ...[
                    SizedBox(height: space.xs),
                    DSText(
                      user!.email,
                      align: TextAlign.center,
                      role: DSTextRole.bodySupport,
                    ),
                  ],
                  SizedBox(height: space.md),
                  DSStatTileGrid(
                    columns: 2,
                    children: [
                      DSStatTile(
                        label: 'Read',
                        value: '12',
                        size: DSStatTileSize.compact,
                        markColor: palette.chart[0],
                      ),
                      DSStatTile(
                        label: 'Streak',
                        value: '5d',
                        size: DSStatTileSize.compact,
                        markColor: palette.chart[1],
                      ),
                    ],
                  ),
                  SizedBox(height: space.md),
                ],
              ),
            ),
            DSPinnedHeader(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  DSGutter.of(context),
                  0,
                  DSGutter.of(context),
                  space.md,
                ),
                child: DSSegmentedButton<ProfileSection>(
                  sizing: DSSegmentedSizing.fill,
                  segments: const [
                    DSSegment(
                      value: ProfileSection.activity,
                      label: 'Activity',
                    ),
                    DSSegment(value: ProfileSection.badges, label: 'Badges'),
                  ],
                  selected: _section,
                  onChanged: _setSection,
                ),
              ),
            ),
            DSGutter.sliver(
              sliver: switch (_section) {
                ProfileSection.activity => _ActivityList(space: space),
                ProfileSection.badges => _BadgeGrid(
                  palette: palette,
                  space: space,
                ),
              },
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: space.xl + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
        bottomNavigationBar: DSPinnedActionBar(
          children: [
            DSButton(
              variant: DSButtonVariant.primary,
              label: 'Edit profile',
              fullWidth: true,
              onPressed: () => _onMenu('Edit profile'),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the reader has done, most recent first — one `DSListTile` per row,
/// the icon carrying what kind of thing it was rather than a bare bullet.
class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.space});

  final SpaceSpec space;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: demoActivity.length,
      separatorBuilder: (context, index) => SizedBox(height: space.sm),
      itemBuilder: (context, index) {
        final item = demoActivity[index];
        return DSListTile(
          leading: DSWell(icon: item.icon),
          title: item.title,
          // A quoted title is a sentence, not a label — `wrap: true` gives it
          // its lines instead of the ellipsis `ui-probe`'s `clipped-text`
          // rule fails a row for cutting.
          wrap: true,
          trailing: Text(
            item.timeAgo,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.palette.mutedForeground,
            ),
          ),
        );
      },
    );
  }
}

/// What the reader has earned — `DSChip` in its `tag` role, read rather than
/// toggled, each carrying the one line that says what it took to earn it.
/// `DSMessage` under the wrap answers the question a badge with no
/// explanation always raises: "earned how?".
///
/// The `Next` block above it answers the other one. A wall of earned badges
/// says where the reader has been and nothing about where they are going, and
/// the space that question was sitting in measured 240pt of white under the
/// paragraph — `ui-probe`'s `dead-band` rule, `flutter-086`.
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.palette, required this.space});

  final Palette palette;
  final SpaceSpec space;

  @override
  Widget build(BuildContext context) {
    const next = demoNextBadge;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: space.sm,
            runSpacing: space.sm,
            children: [
              for (final badge in demoBadges)
                DSChip(
                  role: DSChipRole.tag,
                  label: badge.label,
                  icon: badge.icon,
                  markColor: palette.mutedForeground,
                ),
            ],
          ),
          SizedBox(height: space.lg),
          const DSSectionHeader(label: 'Next'),
          SizedBox(height: space.sm),
          // A bar, not a chip: the earned badges are a set and this one is a
          // quantity. `valueText` carries the count because a fill of a sixth
          // says "some" and the reader is asking "how many more".
          DSMetricBar(
            value: next.progress.toDouble(),
            max: next.total.toDouble(),
            label: next.label,
            valueText: '${next.progress} of ${next.total}',
            fillColor: palette.primary,
          ),
          SizedBox(height: space.xs),
          DSText(next.detail, role: DSTextRole.bodySupport),
          SizedBox(height: space.lg),
          DSMessage(
            title: 'How badges work',
            message: [
              for (final badge in demoBadges)
                '${badge.label} — ${badge.detail}',
            ].join('\n'),
          ),
        ],
      ),
    );
  }
}
