import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/demo_photo.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

final dsMediaRowDemo = DSComponentDemo(
  name: 'DSMediaRow',
  fullBleed: true,
  summary: 'A row led by the picture the reader recognises it by.',
  stories: [
    DSStory(
      title: 'A row with facts',
      note:
          'The picture box is laid out before a byte is fetched, so a '
          'list never reflows as pictures arrive.',
      builder: (context) => DSMediaRow(
        source: const DSMediaSource.widget(
          DemoPhoto(asset: DemoPhotos.flatLay, fallbackHue: 0),
          semanticLabel: 'Cover of the quarterly report',
        ),
        title: 'Quarterly report',
        subtitle: 'Finance · Updated 2 days ago',
        meta: [
          DSMediaMeta(label: 'Draft', markColor: context.palette.warning),
          const DSMediaMeta(
            icon: Icons.description_outlined,
            label: '12 pages',
          ),
        ],
        trailing: DSMenu(
          semanticLabel: 'Actions for the quarterly report',
          items: [DSMenuItem(label: 'Open', onPressed: () {})],
        ),
        onTap: () {},
      ),
    ),
    DSStory(
      title: 'The status vocabulary',
      note:
          'Duration and progress are visible at once, because that is '
          'the actual partly-watched case. A playing item replaces the '
          'pill with an equalizer.',
      builder: (context) => Column(
        children: [
          DSMediaRow(
            source: const DSMediaSource.widget(
              DemoPhoto(asset: DemoPhotos.crossing, fallbackHue: 2),
              semanticLabel: '',
            ),
            aspect: DSMediaAspect.wide,
            title: 'Release 4.2',
            subtitle: 'Changelog',
            status: const DSMediaStatus(
              duration: Duration(minutes: 4, seconds: 12),
              progress: 0.4,
            ),
            onTap: () {},
          ),
          DSMediaRow(
            source: const DSMediaSource.widget(
              DemoPhoto(asset: DemoPhotos.openBook, fallbackHue: 1),
              semanticLabel: '',
            ),
            title: 'Design tokens',
            status: const DSMediaStatus(
              playback: DSMediaPlayback.playing,
              offline: DSMediaOffline.downloaded,
            ),
            onTap: () {},
          ),
          DSMediaRow(
            source: const DSMediaSource.widget(
              DemoPhoto(asset: DemoPhotos.paletteWall, fallbackHue: 3),
              semanticLabel: '',
            ),
            title: 'Selected row',
            subtitle: 'The trailing control stays where it was',
            selected: true,
            trailing: const Icon(Icons.more_vert),
            onTap: () {},
          ),
        ],
      ),
    ),
    DSStory(
      title: 'Compact, and loading',
      note:
          'Compact spends its density on the picture and the padding, '
          'not on the type — and drops the supporting line rather than '
          'truncating it.',
      builder: (context) => const Column(
        children: [
          DSScope(
            density: DSDensity.compact,
            child: DSMediaRow(
              source: DSMediaSource.widget(
                DemoPhoto(asset: DemoPhotos.openBook, fallbackHue: 1),
                semanticLabel: '',
              ),
              title: 'Design tokens',
              subtitle: '3 min read',
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          DSMediaRowSkeleton(metaCount: 2),
        ],
      ),
    ),
  ],
);
