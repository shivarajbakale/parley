import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';

final dsExpansionDemo = DSComponentDemo(
  name: 'DSExpansion',
  summary: 'One question with its answer folded away under it.',
  stories: [
    DSStory(
      title: 'Closed, and opening',
      note:
          'The chevron turns rather than swapping glyphs: the rotation '
          'is what says the panel below it moved.',
      builder: (context) => const DSExpansion(
        title: 'What is included?',
        subtitle: '3 things',
        child: Text(
          'Unlimited projects, the full component kit, and every update '
          'for a year.',
        ),
      ),
    ),
    DSStory(
      title: 'Open on arrival, with a leading glyph',
      note:
          'initiallyExpanded for the one panel that carries the answer '
          'most readers came for. Opening all of them is a page.',
      builder: (context) => const DSExpansion(
        title: 'Delivery',
        leading: Icon(Icons.local_shipping_outlined),
        initiallyExpanded: true,
        child: Text('Two to four working days, tracked.'),
      ),
    ),
    DSStory(
      title: 'An accordion — only one open',
      note:
          'Controlled: the parent holds the open index and each panel '
          'gets expanded: index == i. The component does not coordinate '
          'its siblings, because a component that does cannot be used '
          'alone.',
      builder: (context) => const _AccordionDemo(),
    ),
    DSStory(
      title: 'Disabled',
      note:
          'For a section that is empty rather than hidden. If there is '
          'nothing behind it and never will be, delete the row instead.',
      builder: (context) => const DSExpansion(
        title: 'Returns',
        subtitle: 'Not available in your region',
        enabled: false,
        child: SizedBox.shrink(),
      ),
    ),
  ],
);

/// Three panels sharing one open index — the accordion, assembled at the call
/// site rather than built into the component.
class _AccordionDemo extends StatefulWidget {
  const _AccordionDemo();

  @override
  State<_AccordionDemo> createState() => _AccordionDemoState();
}

class _AccordionDemoState extends State<_AccordionDemo> {
  int _open = 0;

  static const _panels = [
    ('Shipping', 'Free over 50, two to four working days.'),
    ('Returns', 'Thirty days, unworn, with the receipt.'),
    ('Warranty', 'Two years against manufacturing faults.'),
  ];

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (index, (title, body)) in _panels.indexed)
        DSExpansion(
          title: title,
          expanded: _open == index,
          onExpansionChanged: (open) =>
              setState(() => _open = open ? index : -1),
          child: Text(body),
        ),
    ],
  );
}
