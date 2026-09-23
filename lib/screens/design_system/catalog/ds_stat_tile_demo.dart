import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

final dsStatTileDemo = DSComponentDemo(
  name: 'DSStatTile',
  summary: 'One figure, its label, and an optional mark of its category.',
  stories: [
    DSStory(
      title: 'A grid of four',
      note:
          'The tile draws no surface, so four of them are one card of '
          'cells rather than four cards fighting for the same edge.',
      builder: (context) {
        final chart = context.palette.chart;
        return DSCard(
          padding: EdgeInsets.zero,
          child: DSStatTileGrid(
            children: [
              DSStatTile(
                label: 'Sessions',
                value: '8,402',
                markColor: chart[0],
                deltaLabel: '4.1%',
                trend: DSTrend.up,
                note: 'vs last week',
              ),
              DSStatTile.count(
                label: 'Errors',
                count: 37,
                markColor: context.palette.destructive,
                deltaLabel: '2.8%',
                trend: DSTrend.down,
              ),
              DSStatTile(label: 'Uptime', value: '99.98%', markColor: chart[2]),
              DSStatTile(label: 'p95', value: '240 ms', markColor: chart[3]),
            ],
          ),
        );
      },
    ),
    DSStory(
      title: 'With a glyph',
      note:
          'The well and the dot are alternatives. An icon is for one or '
          'two tiles that have to be identifiable at a glance; a dot is '
          'for a grid of six where an icon each would be noise.',
      builder: (context) => DSCard(
        child: DSStatTile.icon(
          icon: Icons.folder_outlined,
          label: 'Storage',
          value: '68.4 GB',
          markColor: context.palette.chart[1],
        ),
      ),
    ),
    DSStory(
      title: 'Loading, and no data',
      note:
          'Bones cover the value and the delta only — the label is known '
          'before the data arrives. An em-dash is not a zero: nothing '
          'measured and measured-as-none are different readings.',
      builder: (context) => const DSCard(
        padding: EdgeInsets.zero,
        child: DSStatTileGrid(
          children: [
            DSStatTile(
              label: 'Revenue',
              value: '12,400',
              loading: true,
              deltaLabel: '8.0%',
              trend: DSTrend.up,
            ),
            DSStatTile(label: 'Refunds', value: '', note: 'No data yet'),
          ],
        ),
      ),
    ),
  ],
);
