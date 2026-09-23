import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';

final dsDismissibleTileDemo = DSComponentDemo(
  name: 'DSDismissibleTile',
  fullBleed: true,
  summary: 'A row that can be swiped away.',
  stories: [
    DSStory(
      title: 'Swipe to delete',
      note:
          'Swipe right to left. The same action must exist somewhere '
          'tappable too — a swipe is not discoverable on its own.',
      builder: (context) => const _DismissibleDemo(),
    ),
  ],
);

class _DismissibleDemo extends StatefulWidget {
  const _DismissibleDemo();

  @override
  State<_DismissibleDemo> createState() => _DismissibleDemoState();
}

class _DismissibleDemoState extends State<_DismissibleDemo> {
  List<String> _rows = ['Annual report', 'Brand guide', 'Roadmap'];

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) {
      return DSEmptyState(
        icon: Icons.inbox_outlined,
        title: 'Every row was swiped away.',
        actionLabel: 'Put them back',
        onAction: () => setState(() {
          _rows = ['Annual report', 'Brand guide', 'Roadmap'];
        }),
      );
    }

    return Column(
      children: [
        for (final row in _rows)
          DSDismissibleTile(
            key: ValueKey(row),
            leadingAction: DSSwipeAction(
              icon: Icons.archive_outlined,
              label: 'Archive',
              onInvoke: () => showDSSnackBar(context, message: 'Archived $row'),
            ),
            trailingAction: DSSwipeAction(
              icon: Icons.delete_outline,
              label: 'Remove',
              tone: DSTone.error,
              onInvoke: () {},
            ),
            onDismissed: (_) {
              setState(() => _rows = [..._rows]..remove(row));
              showDSSnackBar(context, message: 'Removed $row');
            },
            child: DSListTile(
              leading: const Icon(Icons.description_outlined),
              title: row,
              subtitle: 'Swipe left to remove',
            ),
          ),
      ],
    );
  }
}
