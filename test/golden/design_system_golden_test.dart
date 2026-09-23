@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';

import '_harness.dart';

/// Pixel baselines for the design system, five galleries wide.
///
/// **Why galleries and not one image per widget.** Sixty components at six
/// variants each is three hundred and sixty files nobody will ever open. The
/// unit that gets reviewed is a screenful of related controls, because that is
/// where the regressions actually read: a radius that changed on the card but
/// not the tile, a shadow that got heavier on one variant, a control that grew
/// past its row at a doubled text scale. Grouping by job also means a new
/// component lands in an existing gallery instead of adding a file.
///
/// **What each gallery is for.** `chrome` is flutter-008's output — the layer
/// that floats, so it is the one where the Apple and Material columns should
/// look most different. `actions`, `content`, `forms` and `feedback` are the
/// widgets `flutter-009` is about to touch; these baselines are the reason that
/// feature can be reviewed at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadGoldenFonts);
  setUpAll(loadGoldenImages);

  /// A scrolling page of components.
  ///
  /// The scroll view is load-bearing rather than convenience: at textScale 2.0
  /// a gallery is taller than the frame, and a column that overflows vertically
  /// paints stripes over the content below it. Scrolling is what a phone
  /// actually does with tall content, and it keeps the horizontal overflow —
  /// the failure that matters — visible.
  Widget gallery(List<Widget> children) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final Widget child in children)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
          ],
        ),
      ),
    ),
  );

  Widget chrome() => Scaffold(
    body: CustomScrollView(
      slivers: <Widget>[
        const DSLargeAppBar(title: 'Library'),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                DSSearchBar(value: '', onChanged: (_) {}),
                const SizedBox(height: 16),
                DSFab(
                  icon: Icons.edit_outlined,
                  label: 'Compose',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
        // Content under the chrome, not decoration: glass is only visible
        // when there is something behind it to blur, and a bar over an
        // empty surface looks identical on both platforms.
        SliverList.list(
          children: <Widget>[
            for (int i = 0; i < 8; i++)
              DSListTile(
                leading: const DSAvatar(initials: 'RS'),
                title: 'Item ${i + 1}',
                subtitle: 'Something behind the glass',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
          ],
        ),
      ],
    ),
    floatingActionButton: DSFab(
      icon: Icons.add,
      semanticLabel: 'Add',
      onPressed: () {},
    ),
    bottomNavigationBar: DSBottomNavBar(
      currentIndex: 0,
      onTap: (_) {},
      items: const <DSBottomNavItem>[
        DSBottomNavItem(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
        ),
        DSBottomNavItem(
          label: 'Library',
          icon: Icons.book_outlined,
          selectedIcon: Icons.book,
          badgeCount: 3,
        ),
        DSBottomNavItem(
          label: 'Alerts',
          icon: Icons.notifications_none,
          selectedIcon: Icons.notifications,
          badgeDot: true,
        ),
        DSBottomNavItem(label: 'Settings', icon: Icons.settings_outlined),
      ],
    ),
  );

  Widget actions() => gallery(<Widget>[
    const DSSectionHeader(label: 'Buttons'),
    DSButton(label: 'Primary', onPressed: () {}, fullWidth: true),
    DSButton(
      label: 'Secondary',
      variant: DSButtonVariant.secondary,
      icon: Icons.bolt_outlined,
      onPressed: () {},
      fullWidth: true,
    ),
    DSButton(
      label: 'Destructive',
      variant: DSButtonVariant.destructive,
      onPressed: () {},
      fullWidth: true,
    ),
    DSButton(
      label: 'Outlined',
      variant: DSButtonVariant.outlined,
      onPressed: () {},
      fullWidth: true,
    ),
    DSButton(
      label: 'Ghost',
      variant: DSButtonVariant.ghost,
      onPressed: () {},
      fullWidth: true,
    ),
    const DSButton(label: 'Disabled', fullWidth: true),
    const DSButton(
      label: 'Loading',
      loading: true,
      icon: Icons.save_outlined,
      fullWidth: true,
    ),
    // Wrap rather than Row: three buttons side by side do not fit a
    // 360pt phone at textScale 2.0, and a gallery that overflows is
    // testing the gallery instead of the kit.
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        DSButton(label: 'Small', size: DSButtonSize.sm, onPressed: () {}),
        DSButton(label: 'Medium', onPressed: () {}),
        DSButton(label: 'Large', size: DSButtonSize.lg, onPressed: () {}),
      ],
    ),
    const DSSectionHeader(label: 'Segmented'),
    DSSegmentedButton<String>(
      segments: const <DSSegment<String>>[
        DSSegment<String>(value: 'day', label: 'Day'),
        DSSegment<String>(value: 'week', label: 'Week'),
        DSSegment<String>(value: 'month', label: 'Month'),
      ],
      selected: 'week',
      onChanged: (_) {},
    ),
  ]);

  Widget content() => gallery(<Widget>[
    const DSSectionHeader(label: 'Cards'),
    const DSCard(child: Text('Elevated — the default surface.')),
    const DSCard(
      variant: DSCardVariant.filled,
      child: Text('Filled — a tonal block inside a page.'),
    ),
    const DSCard(
      variant: DSCardVariant.outlined,
      child: Text('Outlined — a hairline instead of a lift.'),
    ),
    const DSSectionHeader(label: 'Stats'),
    // One card of cells, not four cards: the tile draws no surface, so
    // the grid is the only thing here with a ground and a divider.
    const DSCard(
      padding: EdgeInsets.zero,
      child: DSStatTileGrid(
        children: <Widget>[
          DSStatTile(
            label: 'Revenue',
            value: '12,400',
            deltaLabel: '8.0%',
            trend: DSTrend.up,
            note: 'vs last week',
          ),
          DSStatTile(
            label: 'Sessions',
            value: '1,208',
            deltaLabel: '2.4%',
            trend: DSTrend.down,
          ),
          DSStatTile(label: 'Open tickets', value: '14'),
          DSStatTile(label: 'Refunds', value: '', note: 'No data yet'),
        ],
      ),
    ),
    const DSSectionHeader(label: 'Badges and avatars'),
    const Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        DSBadge(label: 'New'),
        DSBadge(label: 'Beta', icon: Icons.science_outlined),
        DSAvatar(initials: 'RS', size: DSAvatarSize.sm),
        DSAvatar(initials: 'RS'),
        DSAvatar(initials: 'RS', size: DSAvatarSize.lg),
      ],
    ),
  ]);

  /// The role sheet.
  ///
  /// A type scale is the one part of a kit where the regression is always a
  /// *relationship* — a step that stopped being a step, a grey that drifted
  /// into its neighbour, tracking that did not tighten as the size grew. No
  /// single role shows that; the ladder does, which is why this gallery is
  /// every role at once and in the order a screen uses them.
  Widget typography() => gallery(<Widget>[
    const DSText('Friday · May 16', role: DSTextRole.eyebrow),
    const DSText('Quarterly report', role: DSTextRole.pageTitle),
    const DSText('Sync finished', role: DSTextRole.screenTitle),
    const DSText('This week', role: DSTextRole.sectionTitle),
    const DSText('Team plan', role: DSTextRole.cardTitle),
    const DSText(
      'The opening paragraph, one step up.',
      role: DSTextRole.bodyLead,
    ),
    const DSText(
      'Running copy, which wraps as far as it needs to and never truncates.',
      role: DSTextRole.body,
    ),
    const DSText('The supporting line under it.', role: DSTextRole.bodyDetail),
    const DSText('A rule, not a box.', role: DSTextRole.quote),
    const DSText('Ada Lovelace', role: DSTextRole.itemTitle),
    const DSText('Signed in two minutes ago', role: DSTextRole.itemSubtitle),
    const DSText('2.4 MB · 16 May', role: DSTextRole.itemMeta),
    const DSText('Save changes', role: DSTextRole.control),
    const DSText('Skip', role: DSTextRole.controlSmall),
    const DSText('Email address', role: DSTextRole.fieldLabel),
    const DSText(
      'We only use this to sign you in.',
      role: DSTextRole.fieldHelper,
    ),
    const DSText(
      'That address is already registered.',
      role: DSTextRole.fieldError,
    ),
    const DSText('1,284', role: DSTextRole.metric),
    const DSText('sessions this week', role: DSTextRole.metricUnit),
    const DSText('12', role: DSTextRole.count),
    const DSText.rich(<DSTextSpan>[
      DSTextSpan('Signed in as '),
      DSTextSpan('ada@example.com', emphasis: true),
    ], role: DSTextRole.body),
  ]);

  Widget forms() => gallery(<Widget>[
    const DSSectionHeader(label: 'Text fields'),
    const DSTextField(label: 'Email', hintText: 'you@example.com'),
    const DSTextField(
      label: 'Workspace',
      leadingIcon: Icons.workspaces_outline,
      helperText: 'Where this project lives.',
    ),
    const DSTextField(
      label: 'Password',
      input: DSFieldInput.password(),
      validation: DSFieldValidation(required: true),
    ),
    const DSTextField(
      label: 'Handle',
      helperText: 'Letters and numbers only.',
      errorText: 'That handle is taken.',
    ),
    const DSTextField(label: 'Disabled', enabled: false),
    const DSSectionHeader(label: 'Choices'),
    DSSelect<String>(
      label: 'Frequency',
      options: const <Widget>[
        DSSelectOption<String>(value: 'Daily', label: 'Daily'),
        DSSelectOption<String>(value: 'Weekly', label: 'Weekly'),
        DSSelectOption<String>(value: 'Monthly', label: 'Monthly'),
      ],
      value: 'Weekly',
      onChanged: (_) {},
    ),
    DSSwitchTile(
      value: true,
      label: 'Push notifications',
      subtitle: 'Alerts while the app is closed.',
      icon: Icons.notifications_outlined,
      onChanged: (_) {},
    ),
    DSCheckboxTile(
      value: true,
      label: 'I have read the terms',
      onChanged: (_) {},
    ),
    DSControlTile(
      label: 'Playback speed',
      controlPosition: DSControlPosition.trailing,
      onTap: () {},
      trailing: SizedBox(
        width: 160,
        child: DSSlider(
          value: 0.6,
          showValue: true,
          inTile: true,
          onChanged: (_) {},
        ),
      ),
    ),
  ]);

  Widget feedback() => gallery(<Widget>[
    const DSSectionHeader(label: 'Messages'),
    const DSMessage.screen(message: 'A new version is available.'),
    const DSMessage.section(
      tone: DSMessageTone.neutral,
      title: 'Draft',
      message: 'Not published yet.',
    ),
    const DSMessage.section(
      tone: DSMessageTone.success,
      message: 'Your changes were saved.',
    ),
    const DSMessage.section(
      tone: DSMessageTone.warning,
      title: 'This workspace is nearly full',
      message: 'Uploads will fail at 10 GB.',
    ),
    const DSMessage.section(
      tone: DSMessageTone.error,
      message: 'We could not reach the server.',
    ),
    const DSMessage.compact(
      tone: DSMessageTone.warning,
      message: 'Two-factor authentication is off.',
      icon: Icons.lock_outline,
    ),
    const DSSectionHeader(label: 'Progress'),
    // Determinate on purpose: an indeterminate spinner has no fixed frame,
    // so its baseline would encode whatever phase the test clock happened
    // to stop on.
    const DSProgressIndicator.linear(value: 0.6),
    const Center(child: DSProgressIndicator.circular(value: 0.6)),
    const DSSectionHeader(label: 'Skeleton'),
    const DSSkeleton(
      child: DSListTile(
        leading: DSAvatar(initials: 'RS'),
        title: 'Loading a row',
        subtitle: 'The shape of the content that is coming',
      ),
    ),
    const DSSectionHeader(label: 'Empty'),
    const DSEmptyState(
      title: 'Nothing here yet',
      message: 'Anything you add shows up here.',
      actionLabel: 'Add the first one',
    ),
    const DSSectionHeader(label: 'Error'),
    const DSErrorState(
      title: 'Couldn’t load',
      message: 'Check your connection and try again.',
      detailsText: 'SocketException: Failed host lookup',
    ),
  ]);

  /// The two determinate meters, on their own sheet rather than at the foot of
  /// `content` — a gallery frame is 640 tall and anything past it is recorded
  /// as a crop nobody can review.
  Widget meters() => gallery(<Widget>[
    const DSSectionHeader(label: 'Meters'),
    // Wrap and not Row: at text scale 2 two rings side by side do not fit
    // a phone, and the ring is a fixed graphic that reflows its text
    // rather than shrinking.
    const Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        DSProgressRing(
          label: 'Storage',
          value: 68.4,
          max: 128,
          valueText: '68.4 GB',
          caption: 'of 128 GB',
          size: DSProgressRingSize.compact,
        ),
        DSProgressRing(label: 'Budget', value: 1.14, valueText: '114%'),
      ],
    ),
    const SizedBox(height: 16),
    const DSProgressRing.stacked(
      label: 'Weekly goal',
      value: 0.72,
      valueText: '72%',
    ),
    const SizedBox(height: 16),
    const DSMetricBar(label: 'Documents', value: 42, max: 128),
    const SizedBox(height: 12),
    const DSMetricBar(label: 'Cache', value: 0.5, max: 128),
    const SizedBox(height: 12),
    const DSMetricBar(
      label: 'Secondary',
      value: 0.34,
      size: DSMetricBarSize.thin,
    ),
    const SizedBox(height: 16),
    const DSSegmentedProgress(label: 'Payment', currentStep: 3, totalSteps: 5),
    const SizedBox(height: 12),
    const DSSegmentedProgress(
      currentStep: 4,
      totalSteps: 5,
      errorSteps: <int>{2},
      skippedSteps: <int>{3},
    ),
    const SizedBox(height: 12),
    const DSSegmentedProgress.dots(currentStep: 3, totalSteps: 5),
    const SizedBox(height: 12),
    // Tappable, which is the state that regressed: a reachable step is
    // drawn in a 48-point tap cell and an upcoming one is not, so the two
    // kinds of cell have to be seen in one row. The read-only form was
    // the only one rendered here, which is why five labels on two
    // different lines were baselined as correct. Its alignment is
    // asserted in `ds_segmented_progress_test.dart` instead — the frame
    // is 640 tall and anything past that is silently clipped.
    DSSegmentedProgress.labelled(
      currentStep: 3,
      stepLabels: const <String>['Cart', 'Ship', 'Pay', 'Review', 'Done'],
      onStepTap: (_) {},
    ),
  ]);

  /// The media family on its own sheet: a hero, two rows, a skeleton and a
  /// two-up grid of tiles, which is every status the vocabulary can draw.
  Widget media() => gallery(<Widget>[
    const DSMediaHero(
      source: DSMediaSource.widget(
        ColoredBox(color: Color(0xFF3C4A5A)),
        semanticLabel: 'A featured story',
      ),
      eyebrow: 'FEATURED',
      title: 'The one item the page leads with',
      subtitle: 'Text below the picture, which works with any picture',
      status: DSMediaStatus(duration: Duration(minutes: 12, seconds: 4)),
    ),
    const DSMediaRow(
      source: DSMediaSource.widget(
        ColoredBox(color: Color(0xFF6A5A3C)),
        semanticLabel: '',
      ),
      title: 'A row with a duration and a progress bar',
      subtitle: 'One supporting line, never two',
      status: DSMediaStatus(
        duration: Duration(minutes: 4, seconds: 12),
        progress: 0.4,
      ),
    ),
    const DSMediaRow(
      source: DSMediaSource.widget(
        ColoredBox(color: Color(0xFF3C6A4A)),
        semanticLabel: '',
      ),
      aspect: DSMediaAspect.wide,
      title: 'Wide, selected, and offline',
      selected: true,
      status: DSMediaStatus(offline: DSMediaOffline.downloaded, unread: true),
    ),
    const DSMediaRowSkeleton(metaCount: 2),
    const Row(
      children: <Widget>[
        Expanded(
          child: DSMediaTile(
            source: DSMediaSource.widget(
              ColoredBox(color: Color(0xFF5A3C6A)),
              semanticLabel: '',
            ),
            aspect: DSMediaAspect.portrait,
            title: 'A poster',
            subtitle: 'In a grid',
            status: DSMediaStatus(rank: 1),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: DSMediaTile(
            source: DSMediaSource.widget(
              ColoredBox(color: Color(0xFF6A3C4A)),
              semanticLabel: '',
            ),
            aspect: DSMediaAspect.portrait,
            title: 'Live, and playing',
            status: DSMediaStatus(
              live: true,
              playback: DSMediaPlayback.playing,
            ),
          ),
        ),
      ],
    ),
  ]);

  /// Rows on their own sheet rather than inside `content`: at a doubled text
  /// scale a list row is the tallest thing in the kit, and three of them
  /// pushed the badges and avatars off the bottom of the frame.
  Widget rows() => gallery(<Widget>[
    const DSSectionHeader(label: 'Rows'),
    DSListTile(
      leading: DSAvatar.fromName(name: 'Ada Lovelace'),
      title: 'Ada Lovelace',
      subtitle: 'Last seen 4 minutes ago',
      trailing: const DSBadge(label: 'Pro'),
      onTap: () {},
    ),
    DSListTileGroup(
      children: [
        DSListTile(
          leading: const Icon(Icons.folder_outlined),
          title: 'Archive',
          subtitle: '128 items',
          meta: const DSListTileMeta(
            label: 'Updated 2h ago',
            icon: Icons.schedule,
          ),
          onTap: () {},
        ),
        DSListTile(
          leading: const Icon(Icons.wifi),
          title: 'Wi-Fi only',
          trailing: DSSwitch(
            value: true,
            semanticLabel: 'Wi-Fi only',
            onChanged: (_) {},
          ),
        ),
        DSListTile(
          leading: const Icon(Icons.storage_outlined),
          title: 'Storage is nearly full',
          tone: DSTone.warning,
          onTap: () {},
        ),
      ],
    ),
    DSListTile(
      leading: const Icon(Icons.delete_outline),
      title: 'Delete account',
      tone: DSTone.error,
      onTap: () {},
    ),
    DSListTile(
      title: 'Selected',
      selected: true,
      selectionMode: DSSelectionMode.multiple,
      onTap: () {},
    ),
    const DSListTileSkeleton(),
  ]);

  /// Icon buttons on their own sheet: the matrix is two variants by three
  /// sizes plus five tones, and inside `actions` it fell off the bottom of
  /// the frame — a baseline nobody can see is not a baseline.
  Widget icons() => gallery(<Widget>[
    const DSSectionHeader(label: 'Variants'),
    for (final DSIconButtonVariant variant in DSIconButtonVariant.values)
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: DSIconButtonGroup(
          children: <Widget>[
            for (final DSIconButtonSize size in DSIconButtonSize.values)
              DSIconButton(
                icon: Icons.edit_outlined,
                semanticLabel: 'Edit',
                variant: variant,
                size: size,
                onPressed: () {},
              ),
            DSIconButton(
              icon: Icons.edit_outlined,
              semanticLabel: 'Edit, unavailable',
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
    const DSSectionHeader(label: 'Tones'),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: DSIconButtonGroup(
        children: <Widget>[
          for (final DSTone tone in DSTone.values)
            DSIconButton(
              icon: Icons.delete_outline,
              semanticLabel: 'Delete',
              tone: tone,
              onPressed: () {},
            ),
        ],
      ),
    ),
    const DSSectionHeader(label: 'Toggles'),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: DSIconButtonGroup(
        children: <Widget>[
          DSIconButton(
            icon: Icons.bookmark_border,
            selectedIcon: Icons.bookmark,
            selected: true,
            semanticLabel: 'Remove from saved',
            onPressed: () {},
          ),
          DSIconButton(
            icon: Icons.bookmark_border,
            selectedIcon: Icons.bookmark,
            semanticLabel: 'Save for later',
            onPressed: () {},
          ),
          DSIconButton(
            icon: Icons.notifications_none,
            semanticLabel: 'Notifications',
            badgeCount: 3,
            onPressed: () {},
          ),
          DSIconButton(
            icon: Icons.add,
            semanticLabel: 'Compose',
            variant: DSIconButtonVariant.filled,
            onPressed: () {},
          ),
        ],
      ),
    ),
  ]);

  /// Chips on their own sheet: three roles by two sizes plus the tones and
  /// the overflow is a screenful, and inside `actions` it fell off the bottom
  /// of the frame.
  Widget chips() => gallery(<Widget>[
    const DSSectionHeader(label: 'Chips'),
    DSChipGroup(
      children: <Widget>[
        DSChip(
          label: 'All',
          role: DSChipRole.filter,
          selected: true,
          onSelected: (_) {},
        ),
        DSChip(label: 'Unread', role: DSChipRole.filter, onSelected: (_) {}),
        const DSChip(label: 'Documents', count: 12),
        const DSChip(label: 'Draft', tone: DSTone.warning),
        DSChip(
          label: 'Ada Lovelace',
          role: DSChipRole.input,
          leading: const DSChipAvatar(child: Icon(Icons.person_outline)),
          onRemove: () {},
        ),
        const DSChip(label: 'Unavailable', enabled: false),
      ],
    ),
    const DSSectionHeader(label: 'Sizes and states'),
    const DSChipGroup(
      children: <Widget>[
        DSChip(label: 'Small', size: DSChipSize.sm),
        DSChip(label: 'Medium'),
        DSChip(label: 'Unavailable', enabled: false),
        DSChip(label: 'Loading', loading: true),
        DSChip(label: 'Loading more', loading: true),
      ],
    ),
    const DSSectionHeader(label: 'Overflow'),
    DSChipGroup(
      maxVisible: 3,
      selectedFirst: true,
      children: <Widget>[
        for (final String tag in const [
          'Design',
          'Research',
          'Ops',
          'Support',
          'Finance',
        ])
          DSChip(
            label: tag,
            role: DSChipRole.filter,
            selected: tag == 'Ops',
            onSelected: (_) {},
          ),
      ],
    ),
  ]);

  /// The transient surfaces, drawn inline.
  ///
  /// Presented, they would be over a scrim and only one of them could be in
  /// frame at a time. `DSOverlaySurface` exists partly for this: the shape,
  /// the colour and the depth with no route around them, so the four surfaces
  /// the kit ships can be reviewed side by side and in both themes.
  Widget overlays() => gallery(<Widget>[
    const DSSectionHeader(label: 'Sheet'),
    DSBottomSheet(
      header: const DSSheetHeader(
        title: 'Choose a folder',
        subtitle: '12 available',
      ),
      footer: DSSheetFooter(
        actions: DSButton(label: 'Choose', onPressed: () {}),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final String row in const <String>['Documents', 'Music'])
            DSListTile(title: row, onTap: () {}),
        ],
      ),
    ),
    const DSSectionHeader(label: 'Dialog'),
    DSDialog(
      title: "Delete 'Acme'?",
      message: 'The project and its 42 documents are removed.',
      tone: DSTone.error,
      icon: const DSDialogIcon(icon: Icons.delete_outline, tone: DSTone.error),
      actions: DSDialogActions(
        children: <Widget>[
          DSButton(
            label: 'Cancel',
            variant: DSButtonVariant.ghost,
            onPressed: () {},
          ),
          DSButton(
            label: 'Delete',
            variant: DSButtonVariant.destructive,
            onPressed: () {},
          ),
        ],
      ),
    ),
    const DSSectionHeader(label: 'Menu'),
    DSOverlaySurface(
      presentation: DSOverlayPresentation.menu,
      showDragHandle: false,
      child: DSMenuSurface(
        items: <Widget>[
          const DSMenuSection(label: 'View'),
          DSMenuCheckItem(
            label: 'Show hidden files',
            value: true,
            onChanged: (_) {},
          ),
          const DSMenuSeparator(),
          DSMenuItem(
            label: 'Rename',
            icon: Icons.edit_outlined,
            // Spelled out rather than `⌘R`: the golden harness loads
            // Satoshi and MaterialIcons and nothing else, so the command
            // glyph would be baked into the baseline as a tofu box. The
            // catalog uses the symbol, where the system font is there.
            shortcut: 'Ctrl R',
            onPressed: () {},
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
            onPressed: () {},
          ),
        ],
      ),
    ),
  ]);

  // ── The waves of plans 22–31 ────────────────────────────────────────────
  // One gallery per plan group, so a regression reads where it happened: a
  // control that stopped lining up with its row, a header that lost its
  // eyebrow, an atom whose tone stopped deriving.

  Widget controls() => gallery(<Widget>[
    const DSSectionHeader(label: 'Selection'),
    DSCheckbox(value: true, onChanged: (_) {}, semanticLabel: 'On'),
    DSCheckbox(
      value: null,
      tristate: true,
      onChanged: (_) {},
      semanticLabel: 'Mixed',
    ),
    DSSwitch(value: true, onChanged: (_) {}, semanticLabel: 'Wi-Fi'),
    const DSSectionHeader(label: 'Rows'),
    DSCheckboxTile(
      label: 'Include drafts',
      subtitle: 'Unpublished documents show in the list',
      value: true,
      onChanged: (_) {},
    ),
    DSSwitchTile(
      label: 'Haptics',
      icon: Icons.vibration,
      value: true,
      onChanged: (_) {},
    ),
    DSRadioGroup<String>(
      label: 'Delivery',
      value: 'standard',
      onChanged: (_) {},
      children: const <Widget>[
        DSRadioTile<String>(value: 'standard', label: 'Standard'),
        DSRadioTile<String>(value: 'express', label: 'Express'),
      ],
    ),
    const DSSectionHeader(label: 'Sliders'),
    DSSlider(
      value: 40,
      onChanged: (_) {},
      showValue: true,
      minLabel: '0',
      maxLabel: '100',
      semanticLabel: 'Brightness',
    ),
    DSRangeSlider(
      value: const DSRange(20, 80),
      onChanged: (_) {},
      showValue: true,
    ),
  ]);

  Widget segmented() => gallery(<Widget>[
    const DSSectionHeader(label: 'Segmented'),
    DSSegmentedButton<String>(
      selected: 'all',
      onChanged: (_) {},
      segments: const <DSSegment<String>>[
        DSSegment<String>(value: 'all', label: 'All'),
        DSSegment<String>(value: 'mine', label: 'Mine', count: 4),
        DSSegment<String>(value: 'shared', label: 'Shared'),
      ],
    ),
    DSSegmentedButton<String>(
      selected: 'grid',
      onChanged: (_) {},
      sizing: DSSegmentedSizing.content,
      segments: const <DSSegment<String>>[
        DSSegment<String>(
          value: 'grid',
          icon: Icons.grid_view,
          tooltip: 'Grid',
        ),
        DSSegment<String>(
          value: 'list',
          icon: Icons.view_list,
          tooltip: 'List',
        ),
      ],
    ),
    const DSSegmentedButtonSkeleton(segments: 3),
  ]);

  Widget tabs() => gallery(<Widget>[
    const DSSectionHeader(label: 'Underline'),
    DSTabBar(
      index: 0,
      onIndexChanged: (_) {},
      tabs: const <Widget>[
        DSTab(label: 'Overview'),
        DSTab(label: 'Activity', count: 3),
        DSTab(label: 'Files'),
      ],
    ),
    const DSSectionHeader(label: 'Pill'),
    DSTabBar(
      index: 1,
      onIndexChanged: (_) {},
      indicator: DSTabIndicatorStyle.pill,
      tabs: const <Widget>[
        DSTab(label: 'Day'),
        DSTab(label: 'Week'),
        DSTab(label: 'Month'),
      ],
    ),
    const DSTabBarSkeleton(tabs: 3),
  ]);

  Widget headers() => gallery(<Widget>[
    DSPageHeader(
      eyebrow: 'Workspace',
      title: 'Rocketship',
      actions: DSHeaderActions(
        children: <Widget>[
          DSIconButton(
            icon: Icons.share_outlined,
            semanticLabel: 'Share',
            onPressed: () {},
          ),
        ],
      ),
    ),
    DSSection(
      label: 'Members',
      trailing: DSSectionAction(label: 'Invite', onPressed: () {}),
      child: Column(
        children: <Widget>[
          DSListTile(
            leading: DSAvatar.fromName(name: 'Ada Lovelace'),
            title: 'Ada Lovelace',
            subtitle: 'Owner',
          ),
          DSListTile(
            leading: DSAvatar.fromName(name: 'Grace Hopper'),
            title: 'Grace Hopper',
            subtitle: 'Editor',
          ),
        ],
      ),
    ),
    const DSSectionHeader(label: 'Recent', size: DSSectionHeaderSize.sm),
    const DSSectionHeaderSkeleton(),
  ]);

  /// Not a `gallery`: the hero is full bleed and the whole point of it is the
  /// seam where the page's ground rises over the plate, which a 16-point
  /// padding on every side hides.
  Widget hero() => const Scaffold(
    body: Column(
      children: <Widget>[
        DSHero(
          eyebrow: 'Welcome back',
          title: 'Sign in',
          subtitle: 'Pick up where you left off.',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DSMessage(
                  tone: DSMessageTone.info,
                  message:
                      'Mock backend — sign in with demo@rocketship.dev / '
                      'password, or create any account.',
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget search() => gallery(<Widget>[
    DSSearchBar(value: '', hintText: 'Search documents', onChanged: (_) {}),
    DSSearchBar(
      value: 'quarterly',
      hintText: 'Search documents',
      resultCount: 12,
      onChanged: (_) {},
    ),
    DSSearchBar(
      value: 'quarterly',
      hintText: 'Search documents',
      searching: true,
      onChanged: (_) {},
    ),
    DSSearchScopes(
      children: <Widget>[
        DSChip(label: 'All', role: DSChipRole.filter, onSelected: (_) {}),
        DSChip(
          label: 'Docs',
          role: DSChipRole.filter,
          selected: true,
          onSelected: (_) {},
        ),
        DSChip(label: 'Media', role: DSChipRole.filter, onSelected: (_) {}),
      ],
    ),
  ]);

  Widget identity() => gallery(<Widget>[
    const DSSectionHeader(label: 'Wells'),
    const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        DSWell(icon: Icons.folder_outlined, size: DSWellSize.sm),
        DSWell(icon: Icons.folder_outlined),
        DSWell(icon: Icons.check, tone: DSTone.success, size: DSWellSize.lg),
      ],
    ),
    const DSSectionHeader(label: 'Avatars'),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        DSAvatar.fromName(name: 'Ada Lovelace', size: DSAvatarSize.sm),
        DSAvatar.fromName(name: 'Grace Hopper'),
        const DSAvatar(fallbackIcon: Icons.person, size: DSAvatarSize.xl),
        const DSAvatarSkeleton(),
      ],
    ),
    DSAvatarGroup(
      children: <Widget>[
        DSAvatar.fromName(name: 'Ada Lovelace'),
        DSAvatar.fromName(name: 'Grace Hopper'),
        DSAvatar.fromName(name: 'Alan Turing'),
      ],
    ),
    const DSSectionHeader(label: 'Badges and dots'),
    const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        DSBadge(label: 'New'),
        DSBadge(label: 'Failed', tone: DSTone.error),
        DSBadgeDot(tone: DSTone.success),
        DSDot(count: 3),
        DSDot(),
      ],
    ),
  ]);

  Widget status() => gallery(<Widget>[
    DSEmptyState(
      icon: Icons.folder_open_outlined,
      title: 'No documents yet',
      message: 'Anything you create shows up here.',
      actionLabel: 'New document',
      onAction: () {},
    ),
    DSErrorState(
      title: 'Couldn’t load your library',
      message: 'Check your connection and try again.',
      detailsText: 'SocketException: Failed host lookup',
      onRetry: () {},
    ),
  ]);

  Widget illustration() => gallery(<Widget>[
    const DSSectionHeader(label: 'The six kinds'),
    const Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: <Widget>[
        DSIllustration(
          kind: DSIllustrationKind.empty,
          size: DSIllustrationSize.small,
        ),
        DSIllustration(
          kind: DSIllustrationKind.search,
          size: DSIllustrationSize.small,
        ),
        DSIllustration(
          kind: DSIllustrationKind.offline,
          size: DSIllustrationSize.small,
        ),
        DSIllustration(
          kind: DSIllustrationKind.done,
          size: DSIllustrationSize.small,
          tone: DSTone.success,
        ),
        DSIllustration(
          kind: DSIllustrationKind.locked,
          size: DSIllustrationSize.small,
          tone: DSTone.warning,
        ),
        DSIllustration(
          kind: DSIllustrationKind.error,
          size: DSIllustrationSize.small,
          tone: DSTone.error,
        ),
      ],
    ),
    const DSSectionHeader(label: 'The tier an empty state opts into'),
    const DSEmptyState(
      illustration: DSIllustrationKind.search,
      title: 'No matches',
      message: 'Nothing here answers to that word.',
    ),
  ]);

  Widget floating() => gallery(<Widget>[
    const DSSectionHeader(label: 'Snack bars'),
    const DSSnackBar(message: 'Draft saved'),
    const DSSnackBar(message: 'Everything is up to date', tone: DSTone.success),
    DSSnackBar(
      message: 'Couldn’t reach the server',
      tone: DSTone.error,
      actionLabel: 'Retry',
      onAction: () {},
    ),
    const DSSectionHeader(label: 'Floating action buttons'),
    // A `Wrap` rather than a `Row`: the extended button grows with the label
    // and the accessibility sheet renders this at 2.0x, where four of these
    // in a row overflow by 21 points.
    Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceEvenly,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        DSFab(icon: Icons.add, semanticLabel: 'New', onPressed: () {}),
        DSFab(icon: Icons.edit_outlined, label: 'Compose', onPressed: () {}),
      ],
    ),
    const DSSectionHeader(label: 'Action bars'),
    DSPinnedActionBar(
      helperText: 'You can edit this later.',
      layout: DSActionBarLayout.spread,
      children: <Widget>[
        DSButton(
          label: 'Cancel',
          variant: DSButtonVariant.ghost,
          onPressed: () {},
        ),
        DSButton(label: 'Publish', onPressed: () {}),
      ],
    ),
  ]);

  Widget compositions() => gallery(<Widget>[
    DSSettingsSection(
      eyebrow: 'Account',
      footer: 'Signing out clears the stored token on this device.',
      children: <Widget>[
        DSSettingsRow(
          label: 'Profile',
          icon: Icons.person_outline,
          onTap: () {},
        ),
        DSSwitchTile(
          label: 'Notifications',
          icon: Icons.notifications_none,
          value: true,
          onChanged: (_) {},
        ),
        const DSSettingsRow(label: 'Version', value: '0.1.0'),
        DSSettingsRow(
          label: 'Sign out',
          icon: Icons.logout,
          tone: DSTone.error,
          onTap: () {},
        ),
      ],
    ),
    const DSSectionHeader(label: 'Progress'),
    const DSProgressIndicator.linear(value: 0.4, label: '40%'),
    const DSProgressIndicator.linear(),
    const Center(child: DSProgressIndicator.circular(value: 0.7)),
    const DSSectionHeader(label: 'Swipe'),
    DSDismissibleTile(
      key: const ValueKey<String>('golden-row'),
      leadingAction: DSSwipeAction(
        icon: Icons.archive_outlined,
        label: 'Archive',
        onInvoke: () {},
      ),
      trailingAction: DSSwipeAction(
        icon: Icons.delete_outline,
        label: 'Delete',
        tone: DSTone.error,
        onInvoke: () {},
      ),
      child: const DSListTile(
        title: 'Quarterly report',
        subtitle: 'Swipe either way',
      ),
    ),
  ]);

  /// The three chart kinds, on their own sheet.
  ///
  /// A sparkline beside a figure, one line over a run, bars across categories
  /// — the three shapes the component ships, because a baseline of one of them
  /// defends nothing about the other two.
  Widget charts() => gallery(<Widget>[
    const DSSectionHeader(label: 'Charts'),
    const Row(
      children: <Widget>[
        Expanded(
          child: DSStatTile(
            label: 'Revenue',
            value: '48.2k',
            size: DSStatTileSize.compact,
          ),
        ),
        SizedBox(
          width: 96,
          child: DSChart.sparkline(
            values: <double>[31, 34, 30, 38, 42, 40, 48],
            name: 'Revenue',
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    const DSChart.line(
      series: <DSSeries>[
        DSSeries(name: 'Revenue', values: <double>[31, 34, 30, 38, 42, 40, 48]),
      ],
      labels: <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    ),
    const SizedBox(height: 12),
    const DSChart.bar(
      series: <DSSeries>[
        DSSeries(name: 'Revenue', values: <double>[31, 42, 38, 48]),
        DSSeries(name: 'Costs', values: <double>[22, 25, 29, 30]),
      ],
      labels: <String>['Q1', 'Q2', 'Q3', 'Q4'],
    ),
  ]);

  /// The conversation kit on one sheet: both speakers, all four states, and
  /// the bar the turn is written in.
  Widget conversation() => gallery(<Widget>[
    // A run from one speaker, so the tightened corners and the hairline gap
    // between turns are what the baseline records — the part of a transcript
    // a screenshot of two lone bubbles never showed.
    const DSChatBubble(
      author: DSChatAuthor.them,
      text: 'The delivery slot moved to Thursday.',
      group: DSChatGroup.first,
    ),
    const DSChatBubble(
      author: DSChatAuthor.them,
      text: 'Same window — 9 to 11.',
      group: DSChatGroup.middle,
    ),
    const DSChatBubble(
      author: DSChatAuthor.them,
      text: 'Let me know if that is no good.',
      group: DSChatGroup.last,
      timeLabel: '09:41',
    ),
    const DSChatBubble(
      author: DSChatAuthor.me,
      text: 'That works.',
      timeLabel: '09:42',
    ),
    const DSChatBubble(
      author: DSChatAuthor.me,
      text: 'On my way.',
      status: DSChatStatus.sending,
    ),
    const DSChatBubble(
      author: DSChatAuthor.them,
      text: 'Checking the schedule now',
      status: DSChatStatus.streaming,
    ),
    DSChatBubble(
      author: DSChatAuthor.me,
      text: 'Send it to the old address.',
      status: DSChatStatus.failed,
      onRetry: () {},
    ),
    DSComposer(onSend: (_) {}),
    DSComposer(
      controller: TextEditingController(text: 'Something to send'),
      onSend: (_) {},
    ),
    DSComposer(
      onSend: (_) {},
      enabled: false,
      hintText: 'This chat is archived',
    ),
  ]);

  /// A working day with a clash on it, and the window a late booking widened.
  Widget schedule() => gallery(<Widget>[
    const DSTimeGrid(
      startHour: 9,
      endHour: 13,
      now: TimeOfDay(hour: 11, minute: 20),
      slots: [
        DSTimeSlot(
          start: TimeOfDay(hour: 9, minute: 0),
          end: TimeOfDay(hour: 9, minute: 45),
          title: 'Stand-up',
          subtitle: 'Room 2',
        ),
        DSTimeSlot(
          start: TimeOfDay(hour: 10, minute: 0),
          end: TimeOfDay(hour: 11, minute: 0),
          title: 'Design review',
          subtitle: 'With Ada',
        ),
        DSTimeSlot(
          start: TimeOfDay(hour: 10, minute: 30),
          end: TimeOfDay(hour: 11, minute: 30),
          title: 'Dentist',
          tone: DSTone.error,
        ),
        DSTimeSlot(
          start: TimeOfDay(hour: 12, minute: 0),
          end: TimeOfDay(hour: 12, minute: 30),
          title: 'Lunch',
          tone: DSTone.success,
        ),
      ],
    ),
  ]);

  final galleries = <String, Widget Function()>{
    'chrome': chrome,
    'actions': actions,
    'icons': icons,
    'chips': chips,
    'content': content,
    'rows': rows,
    'media': media,
    'conversation': conversation,
    'schedule': schedule,
    'meters': meters,
    'charts': charts,
    'typography': typography,
    'forms': forms,
    'feedback': feedback,
    'overlays': overlays,
    'controls': controls,
    'segmented': segmented,
    'tab_bar': tabs,
    'headers': headers,
    'hero': hero,
    'search': search,
    'identity_atoms': identity,
    'status': status,
    'floating': floating,
    'illustration': illustration,
    'compositions': compositions,
  };

  galleries.forEach((String name, Widget Function() build) {
    testWidgets('$name — Apple and Material, light and dark', (tester) async {
      await expectGoldenSheet(
        tester,
        name: 'ds_$name',
        build: build,
        frame: name == 'chrome' ? kPhoneFrame : kGalleryFrame,
        // `chrome` is a page with a collapsing bar; it is meant to scroll.
        // A gallery is not — everything it claims to show has to be in frame.
        mustFit: name != 'chrome',
      );
    });

    testWidgets('$name — at textScale 2.0', (tester) async {
      await expectGoldenSheet(
        tester,
        name: 'ds_${name}_text2x',
        build: build,
        frame: name == 'chrome' ? kPhoneFrame : kGalleryFrame,
        variants: accessibilityMatrix,
        textScale: 2.0,
        mustFit: name != 'chrome',
      );
    });
  });
}
