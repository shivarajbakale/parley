import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Surfaces that arrive over the screen.
///
/// Each story is a trigger rather than the surface itself: an overlay drawn
/// inline is a picture of an overlay, and the thing worth judging is how it
/// arrives, how it is dismissed, and whether it blocks.
final overlayCategory = DSCatalogCategory(
  name: 'Overlay',
  icon: Icons.layers_outlined,
  components: [
    DSComponentDemo(
      name: 'DSOverlaySurface',
      fullBleed: true,
      summary: 'One route, one scrim and one dismissal for five surfaces.',
      stories: [
        DSStory(
          title: 'The surface itself',
          note:
              'DSOverlaySurface is the shape, the colour and the depth with '
              'no route around it — the escape hatch, and what the stories '
              'below are presenting.',
          // No fixed height: a surface drawn in a box it did not choose is a
          // picture of the surface doing something it never does, and at a
          // raised text scale it overflows the box rather than growing.
          builder: (context) => DSOverlaySurface(
            presentation: DSOverlayPresentation.dialog,
            showDragHandle: false,
            header: const DSOverlayHeader(
              title: 'Choose a folder',
              subtitle: '12 available',
            ),
            footer: const DSOverlayFooter(
              actions: Text('Pinned below the scroll'),
            ),
            child: Padding(
              padding: EdgeInsets.all(context.design.space.lg),
              child: const Text('The body scrolls between them.'),
            ),
          ),
        ),
        DSStory(
          title: 'Five presentations',
          note:
              'A popover and a menu become sheets under 600 points wide — '
              'one call site, both form factors, which is the rule the HIG '
              'states and nobody remembers to write.',
          builder: (context) => const _PresentationDemo(),
        ),
        DSStory(
          title: 'Nested',
          note:
              'A dialog opened from a sheet stacks, and one back pops one '
              'level. That is free from Navigator and is exactly what the '
              'OverlayEntry this replaces could not do.',
          builder: (context) => DSButton(
            label: 'Open a sheet, then a dialog',
            variant: DSButtonVariant.outlined,
            onPressed: () => showDSBottomSheet<void>(
              context: context,
              header: const DSSheetHeader(title: 'Share'),
              builder: (sheetContext) => Padding(
                padding: EdgeInsets.all(context.design.space.lg),
                child: DSButton(
                  label: 'Confirm something',
                  onPressed: () => showDSConfirm(
                    context: sheetContext,
                    title: 'Send this link?',
                    message: 'Anyone with it can open the document.',
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSBottomSheet',
      fullBleed: true,
      summary: 'Companion content at one height, or at several.',
      stories: [
        DSStory(
          title: 'Four fits',
          note:
              'content is the default: a caller who names a fraction is '
              'guessing at text scale, locale length and device height at '
              'once.',
          builder: (context) => Wrap(
            spacing: context.design.space.sm,
            runSpacing: context.design.space.sm,
            children: [
              for (final fit in DSSheetFit.values)
                DSButton(
                  label: fit.name,
                  variant: DSButtonVariant.outlined,
                  onPressed: () => showDSBottomSheet<void>(
                    context: context,
                    fit: fit,
                    header: DSSheetHeader(
                      title: 'Choose a folder',
                      subtitle: fit.name,
                    ),
                    footer: DSSheetFooter(
                      actions: DSButton(
                        label: 'Choose',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    // The list is its own scroll view.
                    scrollable: false,
                    builder: (context) => ListView(
                      shrinkWrap: true,
                      children: [
                        for (final row in _sheetRows)
                          DSListTile(title: row, onTap: () {}),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        DSStory(
          title: 'Snap points',
          note:
              'Passing the points is the opt-in. Settling on one announces '
              'its label — the use the old SnapPoint.label field was written '
              'for and never wired to.',
          builder: (context) => DSButton(
            label: 'Open a snapping sheet',
            icon: Icons.drag_handle,
            onPressed: () => showDSBottomSheet<void>(
              context: context,
              snapPoints: const [0.3, 0.6, 0.9],
              snapLabels: const ['Peek', 'Half', 'Near full'],
              initialSnap: 0.6,
              builder: (context) => ListView.builder(
                itemCount: 20,
                itemBuilder: (context, index) =>
                    DSListTile(title: 'Result ${index + 1}'),
              ),
            ),
          ),
        ),
        DSStory(
          title: 'A form, with the keyboard',
          note:
              'The inset is read in one small widget whose child instance '
              'never changes, so the form is not rebuilt fifteen times on the '
              'way up.',
          builder: (context) => DSButton(
            label: 'Rename',
            variant: DSButtonVariant.secondary,
            onPressed: () => showDSBottomSheet<void>(
              context: context,
              header: const DSSheetHeader(title: 'Rename project'),
              footer: DSSheetFooter(
                actions: DSButton(
                  label: 'Save',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              builder: (context) => Padding(
                padding: EdgeInsets.all(context.design.space.lg),
                child: const DSTextField(
                  label: 'Name',
                  affordances: DSFieldAffordances(autofocus: true),
                ),
              ),
            ),
          ),
        ),
        DSStory(
          title: 'Loading, and empty',
          note:
              'The skeleton is shaped by the slots present. A sheet is never '
              'permitted to render as a bare header over blank surface.',
          // Stacked rather than side by side. Two sheets at half the width
          // is a picture of a sheet doing something a sheet never does, and
          // the probe's width-band rule says so.
          builder: (context) => Column(
            children: [
              const DSBottomSheet(
                loading: true,
                header: DSSheetHeader(title: 'Choose a folder'),
                child: SizedBox.shrink(),
              ),
              SizedBox(height: context.design.space.md),
              const DSBottomSheet(
                empty: true,
                header: DSSheetHeader(title: 'Choose a folder'),
                child: SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSDialog',
      summary: 'A decision that blocks the next step.',
      stories: [
        DSStory(
          title: 'Alert, confirm, destructive',
          note:
              'Destructive names the object, labels the button with the verb '
              '— never "OK" — and does not focus itself.',
          builder: (context) => Wrap(
            spacing: context.design.space.sm,
            runSpacing: context.design.space.sm,
            children: [
              DSButton(
                label: 'Alert',
                variant: DSButtonVariant.outlined,
                onPressed: () => showDSDialog<void>(
                  context: context,
                  title: 'Sync finished',
                  message: '128 items are now available offline.',
                  tone: DSTone.success,
                  actions: DSDialogActions(
                    children: [
                      DSButton(
                        label: 'Done',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
              DSButton(
                label: 'Confirm',
                variant: DSButtonVariant.secondary,
                onPressed: () => showDSConfirm(
                  context: context,
                  title: 'Discard draft?',
                  message: 'This note has not been saved yet.',
                  confirmLabel: 'Discard',
                  tone: DSTone.warning,
                ),
              ),
              DSButton(
                label: 'Destructive',
                variant: DSButtonVariant.destructive,
                onPressed: () => showDSConfirm(
                  context: context,
                  title: "Delete 'Acme'?",
                  message:
                      'The project and its 42 documents are removed for '
                      'everyone on the team.',
                  confirmLabel: 'Delete',
                  icon: Icons.delete_outline,
                  destructive: true,
                ),
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Custom, and pending',
          note:
              'content: takes a widget, so a dialog can collect a name. An '
              'async confirm keeps the scrim locked while its work is in '
              'flight.',
          builder: (context) => Wrap(
            spacing: context.design.space.sm,
            runSpacing: context.design.space.sm,
            children: [
              DSButton(
                label: 'Rename',
                variant: DSButtonVariant.outlined,
                onPressed: () => showDSDialog<String>(
                  context: context,
                  title: 'Rename project',
                  icon: Icons.edit_outlined,
                  content: const DSTextField(label: 'Name'),
                  actions: DSDialogActions(
                    children: [
                      DSButton(
                        label: 'Cancel',
                        variant: DSButtonVariant.ghost,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      DSButton(
                        label: 'Save',
                        onPressed: () => Navigator.of(context).pop('saved'),
                      ),
                    ],
                  ),
                ),
              ),
              DSButton(
                label: 'Pending',
                variant: DSButtonVariant.secondary,
                onPressed: () => showDSConfirm(
                  context: context,
                  title: 'Publish?',
                  message: 'This makes the project visible to the team.',
                  confirmLabel: 'Publish',
                  onConfirm: () => Future<void>.delayed(
                    // ui-lint: allow bare-metric — a fake network
                    // round-trip, so the confirm button has something to stay
                    // busy for. Not an animation: it does not move with the
                    // motion scale.
                    const Duration(seconds: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        DSStory(
          title: 'The surface, inline',
          note:
              'The same widget the route presents, drawn where it can be '
              'judged.',
          builder: (context) => DSDialog(
            title: "Delete 'Acme'?",
            message: 'The project and its 42 documents are removed.',
            tone: DSTone.error,
            icon: const DSDialogIcon(
              icon: Icons.delete_outline,
              tone: DSTone.error,
            ),
            actions: DSDialogActions(
              children: [
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
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSSnackBar',
      summary: 'Confirming something that already happened.',
      stories: [
        DSStory(
          title: 'Four variants',
          note: 'Each fires the haptic that matches what it reports.',
          builder: (context) => Wrap(
            spacing: context.design.space.sm,
            runSpacing: context.design.space.sm,
            children: [
              DSButton(
                label: 'Info',
                size: DSButtonSize.sm,
                variant: DSButtonVariant.outlined,
                onPressed: () =>
                    showDSSnackBar(context, message: 'Draft saved'),
              ),
              DSButton(
                label: 'Success',
                size: DSButtonSize.sm,
                variant: DSButtonVariant.secondary,
                onPressed: () => showDSSnackBar(
                  context,
                  message: 'Project published',
                  tone: DSTone.success,
                ),
              ),
              DSButton(
                label: 'Warning',
                size: DSButtonSize.sm,
                variant: DSButtonVariant.secondary,
                onPressed: () => showDSSnackBar(
                  context,
                  message: 'Working offline',
                  tone: DSTone.warning,
                ),
              ),
              DSButton(
                label: 'Error',
                size: DSButtonSize.sm,
                variant: DSButtonVariant.destructive,
                onPressed: () => showDSSnackBar(
                  context,
                  message: 'Could not reach the server',
                  tone: DSTone.error,
                ),
              ),
            ],
          ),
        ),
        DSStory(
          title: 'With an undo',
          note:
              'The reversible pattern: act immediately, offer the way back. '
              'Never put a *required* action here — it leaves on a timer.',
          builder: (context) => DSButton(
            label: 'Delete row',
            icon: Icons.delete_outline,
            variant: DSButtonVariant.destructive,
            onPressed: () => showDSSnackBar(
              context,
              message: 'Removed Q3 report',
              icon: Icons.delete_outline,
              actionLabel: 'Undo',
              onAction: () =>
                  showDSSnackBar(context, message: 'Restored Q3 report'),
            ),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSSearchBar',
      summary: 'A query, the scopes that narrow it, and what it found.',
      stories: [
        DSStory(
          title: 'Filtering in place',
          note:
              'Controlled: the caller owns the query. The list narrows '
              'under the bar rather than opening a second screen.',
          builder: (context) => const _SearchBarDemo(),
        ),
        DSStory(
          title: 'Scoped, searching, counted',
          note:
              'The spinner replaces the clear button in the same box, so '
              'nothing reflows and focus does not move mid-query. The '
              'previous results stay on screen.',
          builder: (context) =>
              const _SearchBarDemo(scoped: true, searching: true),
        ),
        DSStory(
          title: 'A query that found nothing',
          note:
              'The empty state quotes the query and offers the way out, '
              'instead of leaving a blank column under the field.',
          builder: (context) => const _SearchBarDemo(startQuery: 'zzz'),
        ),
      ],
    ),
  ],
);

class _SearchBarDemo extends StatefulWidget {
  const _SearchBarDemo({
    this.scoped = false,
    this.searching = false,
    this.startQuery = '',
  });

  final bool scoped;
  final bool searching;
  final String startQuery;

  @override
  State<_SearchBarDemo> createState() => _SearchBarDemoState();
}

const _searchRows = ['Annual report', 'Brand guide', 'Budget', 'Roadmap'];

class _SearchBarDemoState extends State<_SearchBarDemo> {
  late String _query = widget.startQuery;
  String _scope = 'All';

  @override
  Widget build(BuildContext context) {
    final matches = [
      for (final row in _searchRows)
        if (row.toLowerCase().contains(_query.trim().toLowerCase())) row,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DSSearchBar(
          value: _query,
          // Short because it has to fit the narrowest phone the kit is graded
          // at: "Search documents" was cut to "Search docum…" at 320 points
          // and a 1.3x text scale, once the field's icon, its clear button and
          // its result count had taken their share of the row.
          hintText: 'Search',
          searching: widget.searching,
          resultCount: widget.searching ? null : matches.length,
          onChanged: (value) => setState(() => _query = value),
          onQueryChanged: (_) {},
          onSubmitted: (_) {},
          onClear: () => setState(() => _query = ''),
          scopes: !widget.scoped
              ? null
              : DSSearchScopes(
                  children: [
                    for (final scope in const ['All', 'Docs', 'Media'])
                      DSChip(
                        label: scope,
                        role: DSChipRole.filter,
                        selected: _scope == scope,
                        onSelected: (_) => setState(() => _scope = scope),
                      ),
                    const DSChipSeparator(),
                    DSChip(
                      label: 'Starred',
                      role: DSChipRole.filter,
                      selected: _scope == 'Starred',
                      onSelected: (_) => setState(() => _scope = 'Starred'),
                    ),
                  ],
                ),
        ),
        context.design.space.verticalSm,
        if (matches.isNotEmpty)
          for (final match in matches) DSListTile(title: match),
      ],
    );
  }
}

const _sheetRows = ['Documents', 'Downloads', 'Pictures', 'Music', 'Archive'];

/// Every presentation, from one trigger each, so the difference between them
/// is a thing that can be watched rather than a table that can be read.
class _PresentationDemo extends StatefulWidget {
  const _PresentationDemo();

  @override
  State<_PresentationDemo> createState() => _PresentationDemoState();
}

class _PresentationDemoState extends State<_PresentationDemo> {
  final GlobalKey _anchor = GlobalKey();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: context.design.space.sm,
    runSpacing: context.design.space.sm,
    children: [
      for (final presentation in DSOverlayPresentation.values)
        KeyedSubtree(
          key: presentation == DSOverlayPresentation.popover ? _anchor : null,
          child: DSButton(
            label: presentation.name,
            variant: DSButtonVariant.outlined,
            onPressed: () => showDSOverlay<void>(
              context: context,
              presentation: presentation,
              anchor: _anchor,
              builder: (context) => DSOverlaySurface(
                presentation: presentation,
                showDragHandle:
                    presentation == DSOverlayPresentation.sheet ||
                    presentation == DSOverlayPresentation.fullScreen,
                // Two lines rather than one, and the same two for every
                // presentation. A single label made the dialog 351 by 94 —
                // a bar laid across the screen, which is a shape no dialog
                // in the app actually has — so the story was showing a
                // defect of the story rather than the presentation it is
                // here to demonstrate.
                child: Padding(
                  padding: EdgeInsets.all(context.design.space.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Presented as ${presentation.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      context.design.space.verticalXs,
                      const DSText(
                        'Same surface, same route, same dismissal — only '
                        'the position and the transition differ.',
                        role: DSTextRole.bodyDetail,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
