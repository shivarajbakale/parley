import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/onboarding_art.dart';
import 'package:parley_android/screens/onboarding_page.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The chrome layer: how the user gets from one place to another.
///
/// These are the stories that need a frame around them — a nav bar or an app
/// bar shown at its own size, on a bounded stage, so it reads the way it will
/// read in a screen rather than stretched across the gallery.
final navigationCategory = DSCatalogCategory(
  name: 'Navigation & chrome',
  icon: Icons.explore_outlined,
  components: [
    DSComponentDemo(
      name: 'DSBottomNavBar',
      summary: 'Three to five top-level destinations.',
      stories: [
        DSStory(
          title: 'Three destinations',
          fullBleed: true,
          note:
              'The minimum, and the shape the app shell itself uses — one '
              'list drives the bar, the drawer and the swipe order. Tap: the '
              'selected destination carries a filled glyph, the indicator '
              'pill and a heavier label, so it survives greyscale.',
          builder: (context) => const _StageFrame(child: _BottomNavDemo()),
        ),
        DSStory(
          title: 'Four, with a count and a dot',
          fullBleed: true,
          note:
              'A count on the destination that has news; a dot only where '
              'the number is genuinely unknowable. Badge the destination, '
              'never the app, and the count is read out as part of the '
              'destination rather than as a second thing to tab to.',
          builder: (context) => const _StageFrame(
            child: _BottomNavDemo(count: 4, withBadge: true),
          ),
        ),
        DSStory(
          title: 'Five, an avatar, and one destination switched off',
          fullBleed: true,
          note:
              'The maximum. iconSlot takes anything — here an avatar on '
              'the profile destination. A disabled destination is rare: one '
              'that is never available should not be a destination.',
          builder: (context) => const _StageFrame(
            child: _BottomNavDemo(count: 5, withBadge: true),
          ),
        ),
        DSStory(
          title: 'Labels off',
          fullBleed: true,
          note:
              'All or nothing, never mixed — a bar whose labels appear only '
              'when selected makes the user tap to find out. With the labels '
              'gone the long-press tooltip carries them, which is also what '
              'happens above 1.8× text scale.',
          builder: (context) =>
              const _StageFrame(child: _BottomNavDemo(showLabels: false)),
        ),
        DSStory(
          title: 'A 9-char label that fits at 9pt',
          fullBleed: true,
          note:
              'Plan 38. The lint budget is 8 characters; this story uses 9 '
              'deliberately, to show the runtime shrink. The pill is the '
              'same size, the label is one point smaller, nothing else '
              'changed. The lint would suggest "Browse" or "Explore" if this '
              'were committed; the story pins the call out so the rule\'s '
              'safety net is visible alongside its primary defence.',
          builder: (context) => const _StageFrame(
            child: _BottomNavDemo(count: 5, withLongLabel: true),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSSidebar',
      summary: 'Six or more destinations, or the secondary ones.',
      stories: [
        DSStory(
          title: 'Header, destinations, footer',
          note:
              'The footer is where the one action that is not a destination '
              'goes — upgrade, sign out, help.',
          builder: (context) => const _StageFrame(
            height: 360,
            padded: false,
            child: _SidebarDemo(),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSTabBar',
      summary: 'Peer views of one subject, switched in place.',
      stories: [
        DSStory(
          title: 'Underline',
          note:
              'The default. Sits on the page ground and reads as '
              'navigation — right directly under an app bar. Drag the panel '
              'sideways: the indicator follows the finger rather than '
              'jumping on release.',
          builder: (context) => const _TabBarDemo(),
        ),
        DSStory(
          title: 'Pill',
          note:
              'On a well track, reading as a control. It takes the same two '
              'colours DSSegmentedButton does, so the two cannot drift.',
          builder: (context) =>
              const _TabBarDemo(indicator: DSTabIndicatorStyle.pill),
        ),
        DSStory(
          title: 'Auto, overflowing',
          note:
              'Six tabs do not fit, so the strip scrolls and fades at the '
              'edge. Nobody had to predict that at build time.',
          builder: (context) => const _TabBarDemo(many: true),
        ),
        DSStory(
          title: 'Counts, a disabled tab, and no controller',
          note:
              'Driven by index and onIndexChanged over a PageView, which is '
              'what used to force a StatefulWidget with a TickerProvider for '
              'three labels. A swipe onto the disabled tab comes back.',
          builder: (context) => const _TabBarDemo(
            uncontrolled: true,
            counts: true,
            disableLast: true,
          ),
        ),
        DSStory(
          title: 'Loading',
          note:
              'The bar keeps its height, so nothing moves when the labels '
              'arrive.',
          builder: (context) => const DSTabBarSkeleton(),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSLargeAppBar',
      fullBleed: true,
      summary:
          'A title that is the content’s identity, collapsing as it '
          'scrolls.',
      stories: [
        DSStory(
          title: 'Collapsing title',
          note:
              'Scroll the stage: the large title shrinks into the bar. On '
              'Apple the bar is glass, on Android a tonal surface.',
          builder: (context) => _StageFrame(
            height: 260,
            padded: false,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: CustomScrollView(
                slivers: [
                  const DSLargeAppBar(
                    // A subtitle, because `header-earns-its-height` fails an
                    // expanded bar that holds nothing but its title: the
                    // height has to buy the reader something the compact bar
                    // could not have shown.
                    title: 'Library',
                    subtitle: 'Eight rows, and the title that names them.',
                  ),
                  SliverList.builder(
                    itemCount: 8,
                    itemBuilder: (context, index) => DSListTile(
                      title: 'Row ${index + 1}',
                      subtitle: 'Scroll to collapse the title',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSCompactAppBar',
      fullBleed: true,
      summary:
          'A navigation bar for a screen whose header is a word — no large '
          'title, no collapse.',
      stories: [
        DSStory(
          title: 'Title only',
          note:
              'The form the header-earns-its-height rule sends a title-only '
              'screen to. It gives the first screenful back the toolbar row plus '
              'the measured title block an expanded bar reserves, and it '
              'takes on the chrome only once content is behind it.',
          builder: (context) => _StageFrame(
            height: 260,
            padded: false,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: CustomScrollView(
                slivers: [
                  const DSCompactAppBar(title: 'Library'),
                  SliverList.builder(
                    itemCount: 8,
                    itemBuilder: (context, index) => DSListTile(
                      title: 'Row ${index + 1}',
                      subtitle: 'Scroll: the bar stays the height it is',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSPinnedHeader',
      summary:
          'A band of controls pinned under the header while the list scrolls.',
      stories: [
        DSStory(
          title: 'A filter that stays put',
          note:
              'Scroll the stage: the chips hold their line while the rows '
              'move behind them. This is the band the Library, the Components '
              'gallery and the Inbox all pin their filters in — the reader '
              'never has to fling back to the top to see what is filtered.',
          builder: (context) => _StageFrame(
            height: 260,
            padded: false,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: CustomScrollView(
                slivers: [
                  const DSCompactAppBar(title: 'Library'),
                  DSPinnedHeader(
                    // The strip scrolls sideways, the way every screen that
                    // pins one builds it: a wrapped strip changes the list's
                    // starting position each time a filter is added.
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: context.design.space.pageGutter,
                        vertical: context.design.space.sm,
                      ),
                      child: Row(
                        spacing: context.design.space.sm,
                        children: [
                          for (final label in const ['All', 'Design', 'Guides'])
                            DSChip(
                              label: label,
                              role: DSChipRole.filter,
                              selected: label == 'All',
                              onSelected: (_) {},
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: 8,
                    itemBuilder: (context, index) => DSListTile(
                      title: 'Row ${index + 1}',
                      subtitle: 'Scroll: the chips do not move',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSPinnedActionBar',
      fullBleed: true,
      summary: 'The primary action, pinned over the content.',
      stories: [
        DSStory(
          title: 'Over a scrolling body',
          note:
              'Detail and Form both need this: the action stays reachable '
              'while the content moves under it.',
          builder: (context) => _StageFrame(
            height: 220,
            padded: false,
            child: Stack(
              children: [
                MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: ListView.builder(
                    padding: EdgeInsets.only(bottom: context.design.space.xxxl),
                    itemCount: 6,
                    itemBuilder: (context, index) =>
                        DSListTile(title: 'Paragraph ${index + 1}'),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DSPinnedActionBar(
                    children: [
                      DSButton(
                        label: 'Save changes',
                        fullWidth: true,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSBottomInsets',
      summary:
          'What is at the bottom of the screen, so nothing lands on '
          'anything else.',
      stories: [
        DSStory(
          title: 'All three at once',
          note:
              'The bug this exists for: a pinned bar, a floating button and '
              'a snack bar over one scrolling body, each placed above the '
              'last rather than on top of it.',
          builder: (context) => _StageFrame(
            height: 260,
            padded: false,
            child: DSBottomInsetsHost(
              child: Builder(
                builder: (inner) => Stack(
                  children: [
                    MediaQuery.removePadding(
                      context: inner,
                      removeBottom: true,
                      child: ListView.builder(
                        padding: DSBottomInsets.of(inner).scrollPadding,
                        itemCount: 8,
                        itemBuilder: (context, index) =>
                            DSListTile(title: 'Row ${index + 1}'),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: DSPinnedActionBar(
                        children: [
                          DSButton(
                            label: 'Publish',
                            fullWidth: true,
                            onPressed: () => showDSSnackBar(
                              inner,
                              message: 'Published — it clears the bar',
                              tone: DSTone.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PositionedDirectional(
                      end: context.design.space.md,
                      bottom:
                          DSBottomInsets.of(inner).total +
                          context.design.space.md,
                      child: DSFab(
                        icon: Icons.add,
                        semanticLabel: 'New row',
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    // The tour applies space.pageGutter itself; the story frame must not
    // apply a second one.
    DSComponentDemo(
      name: 'DSTour',
      fullBleed: true,
      summary:
          'A first-run sequence that ends in a commitment, and the DSTourSlide '
          'it is built from.',
      stories: [
        DSStory(
          title: 'Three stops, with a way out',
          note:
              'The shipped shape. The label changes exactly once — a run of '
              'Nexts, then the commitment — and Skip is present because the '
              'last stop hands over to sign-in, which a returning user can '
              'reach without reading three slides.',
          builder: (context) => SizedBox(
            // A tour is a whole screen; a shorter stage would make the
            // slide scroll inside its own pager, which is the two-axis page
            // `ui-probe` fails on sight.
            height: 844,
            child: DSTour(
              stops: onboardingStops,
              onFinish: () {},
              onSkip: () {},
              finishLabel: 'Get started',
            ),
          ),
        ),
        DSStory(
          title: 'No way out, and a caption',
          note:
              'What a tour looks like when the last stop hands over to setup '
              'the user has to do anyway. Dropping Skip is only honest here: '
              'nobody reaches the app by reading, they reach it by finishing '
              'the thing the last slide points at. The caption says what they '
              'are agreeing to.',
          builder: (context) => SizedBox(
            // A tour is a whole screen; a shorter stage would make the
            // slide scroll inside its own pager, which is the two-axis page
            // `ui-probe` fails on sight.
            height: 844,
            child: DSTour(
              stops: onboardingStops,
              onFinish: () {},
              finishLabel: 'Set up my account',
              finishCaption: 'About two minutes, once.',
            ),
          ),
        ),
        DSStory(
          title: 'On screen',
          note:
              'Offset 0 — the slide the finger is on. The picture takes what '
              'the words leave over, and the words sit at the same height on '
              'every stop so a swipe does not move the headline.',
          builder: (context) => SizedBox(
            height: 480,
            child: DSTourSlide(
              art: onboardingStops.first.art(true),
              headline: onboardingStops.first.headline,
              body: onboardingStops.first.body,
              offset: 0,
            ),
          ),
        ),
        DSStory(
          title: 'Half a page away',
          note:
              'Offset 0.5, the state you only ever see mid-drag. The two '
              'planes are pulled apart: the picture lags and recedes, the '
              'words lead and fade faster. One plane moving is a slide; two '
              'at different rates is depth.',
          builder: (context) => SizedBox(
            height: 480,
            child: DSTourSlide(
              art: onboardingStops.first.art(true),
              headline: onboardingStops.first.headline,
              body: onboardingStops.first.body,
              offset: 0.5,
            ),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSTourDots',
      summary: 'Where you are in a paged sequence.',
      stories: [
        DSStory(
          title: 'At rest',
          note:
              'The current page is a bar rather than a bigger dot: at four '
              'pages, size alone is hard to spot at a glance. No tap target — '
              'the button and the swipe are the two ways forward.',
          builder: (context) => const DSTourDots(count: 4, position: 0),
        ),
        DSStory(
          title: 'Mid-drag',
          note:
              'Position 1.4. Driven by the live scroll position rather than '
              'the settled page, so it is already telling the truth when the '
              'finger lets go — and the two marks either side of the drag are '
              'both visibly short of a full bar.',
          builder: (context) => const DSTourDots(count: 4, position: 1.4),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSTourCanvas',
      summary:
          'The fixed-width board a tour illustration is drawn on, and the '
          'DSTourFillSlot that fills in on top of it.',
      stories: [
        DSStory(
          title: 'A drawing of the product',
          note:
              'Composed at one width and scaled by whoever shows it, so the '
              'picture never reflows. The caller strips the text scaler: this '
              'is a picture of type, not type.',
          builder: (context) => const OnboardingListArt(active: true),
        ),
        DSStory(
          title: 'Filled',
          note:
              'The empty rule is the app before; the content under the halo '
              'is the app after. It is the argument for the tour made in a '
              'picture rather than in a sentence, and it never waits on '
              'anything — reach for DSSkeleton if the content is really '
              'loading.',
          builder: (context) => const OnboardingSetupArt(active: true),
        ),
      ],
    ),
  ],
);

/// A bounded, clipped stage for the widgets that expect to own a screen.
class _StageFrame extends StatelessWidget {
  final Widget child;
  final double height;
  final bool padded;

  const _StageFrame({
    required this.child,
    this.height = 88,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    final schemePalette = context.palette;
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      padding: padded ? EdgeInsets.all(context.design.space.sm) : null,
      decoration: BoxDecoration(
        color: schemePalette.background,
        borderRadius: BorderRadius.circular(context.radiusOf(AppShape.tile)),
        border: Border.all(color: schemePalette.borderSoft),
      ),
      child: child,
    );
  }
}

class _BottomNavDemo extends StatefulWidget {
  final int count;
  final bool withBadge;
  final bool showLabels;

  /// Plan 38: set to `true` to render a 9-character label that would
  /// clip at the default font size on a 360dp phone. The bar's
  /// runtime shrink (`_pickLabelFontSize`) drops the first
  /// destination's label to 9pt — the floor — without ellipsizing it,
  /// and the rest of the bar's labels render at the same shrunk size
  /// because the pick is bar-wide. The story's note names the lint
  /// suggestion for the same word.
  final bool withLongLabel;

  const _BottomNavDemo({
    this.count = 3,
    this.withBadge = false,
    this.showLabels = true,
    this.withLongLabel = false,
  });

  @override
  State<_BottomNavDemo> createState() => _BottomNavDemoState();
}

class _BottomNavDemoState extends State<_BottomNavDemo> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final items = <DSBottomNavItem>[
      DSBottomNavItem(
        // Plan 38: when `withLongLabel` is on, the first destination
        // shows a 9-char label. The runtime shrink lands it at 9pt —
        // the floor — without ellipsizing. Without the shrink it
        // would clip on a 360dp phone.
        label: widget.withLongLabel ? 'Discovery' : 'Home',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
      ),
      DSBottomNavItem(
        label: 'Inbox',
        icon: Icons.mail_outline,
        selectedIcon: Icons.mail,
        badgeCount: widget.withBadge ? 3 : null,
      ),
      const DSBottomNavItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
      DSBottomNavItem(
        label: 'Alerts',
        icon: Icons.notifications_none,
        selectedIcon: Icons.notifications,
        badgeDot: widget.withBadge,
      ),
      const DSBottomNavItem(
        label: 'You',
        icon: Icons.person_outline,
        enabled: false,
        semanticLabel: 'Your profile, sign in to open',
        iconSlot: DSAvatar(initials: 'AL', size: DSAvatarSize.sm),
      ),
    ].take(widget.count).toList();

    return DSBottomNavBar(
      currentIndex: _index.clamp(0, items.length - 1),
      onTap: (index) => setState(() => _index = index),
      items: items,
      style: widget.showLabels
          ? null
          : const DSBottomNavBarStyle(showLabels: false),
    );
  }
}

class _SidebarDemo extends StatefulWidget {
  const _SidebarDemo();

  @override
  State<_SidebarDemo> createState() => _SidebarDemoState();
}

class _SidebarDemoState extends State<_SidebarDemo> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 304,
        child: DSSidebar(
          header: const DSSidebarHeader(
            title: 'Rocketship',
            caption: 'Version 0.1.0',
          ),
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: const [
            DSBottomNavItem(
              label: 'Home',
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
            ),
            DSBottomNavItem(
              label: 'Library',
              icon: Icons.collections_bookmark_outlined,
              selectedIcon: Icons.collections_bookmark,
            ),
            DSBottomNavItem(
              label: 'Settings',
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
            ),
          ],
          footer: DSListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: 'Upgrade to Pro',
            onTap: () {},
          ),
        ),
      ),
    );
  }
}

class _TabBarDemo extends StatefulWidget {
  const _TabBarDemo({
    this.indicator = DSTabIndicatorStyle.underline,
    this.many = false,
    this.uncontrolled = false,
    this.counts = false,
    this.disableLast = false,
  });

  final DSTabIndicatorStyle indicator;
  final bool many;
  final bool uncontrolled;
  final bool counts;
  final bool disableLast;

  @override
  State<_TabBarDemo> createState() => _TabBarDemoState();
}

class _TabBarDemoState extends State<_TabBarDemo>
    with SingleTickerProviderStateMixin {
  static const _labels = [
    'Overview',
    'Activity',
    'Members',
    'Files',
    'Billing',
    'Settings',
  ];

  late final int _count = widget.many ? 6 : 3;
  late final TabController? _controller = widget.uncontrolled
      ? null
      : TabController(length: _count, vsync: this);

  /// The uncontrolled story drives its own panels, so it needs its own page
  /// controller: `index`/`onIndexChanged` says which tab is selected, and this
  /// says which panel the swipe has reached.
  late final PageController? _pages = widget.uncontrolled
      ? PageController()
      : null;
  int _index = 0;

  @override
  void dispose() {
    _controller?.dispose();
    _pages?.dispose();
    super.dispose();
  }

  bool _tabEnabled(int index) => !(widget.disableLast && index == _count - 1);

  void _goTo(int index) {
    setState(() => _index = index);
    final motion = context.design.motion;
    _pages?.animateToPage(
      index,
      duration: motion.scaled(motion.normal),
      curve: motion.emphasize,
    );
  }

  /// A swipe can reach a panel whose tab refuses to be selected, so the page
  /// comes back rather than sitting under no indicator.
  void _onPageChanged(int index) {
    if (!_tabEnabled(index)) {
      _goTo(_index);
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DSTabBar(
          controller: _controller,
          index: _controller == null ? _index : null,
          onIndexChanged: _controller == null ? _goTo : null,
          indicator: widget.indicator,
          tabs: [
            for (final (i, label) in _labels.take(_count).indexed)
              DSTab(
                label: label,
                count: widget.counts && i == 1 ? 3 : null,
                enabled: _tabEnabled(i),
              ),
          ],
        ),
        SizedBox(height: context.design.space.sm),
        _StageFrame(
          // The stage is a box and the copy inside it is not: at text 2.0x a
          // fixed 132 overflowed by 27pt, which the probe caught. The frame
          // takes the reader's text scale with it, because a scroll inside a
          // horizontally paging surface is the dual-axis defect the probe
          // catches next.
          height: 132 * MediaQuery.textScalerOf(context).scale(1),
          child: _controller != null
              ? TabBarView(
                  controller: _controller,
                  children: [
                    for (final label in _labels.take(_count))
                      _TabPanel(label: label),
                  ],
                )
              : PageView(
                  controller: _pages,
                  onPageChanged: _onPageChanged,
                  children: [
                    for (final (i, label) in _labels.take(_count).indexed)
                      _TabPanel(label: label, enabled: _tabEnabled(i)),
                  ],
                ),
        ),
      ],
    );
  }
}

/// The panel under the bar.
///
/// Two jobs: it makes the switch visible — a story that is only a row of
/// labels shows the indicator moving and nothing else — and it is the surface
/// the horizontal drag lands on, which is how a tab bar is switched on a phone.
class _TabPanel extends StatelessWidget {
  const _TabPanel({required this.label, this.enabled = true});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          SizedBox(height: context.design.space.xs),
          DSText(
            enabled ? 'Swipe to change tab.' : 'Disabled — the swipe returns.',
            align: TextAlign.center,
            role: DSTextRole.bodyDetail,
          ),
        ],
      ),
    );
  }
}
