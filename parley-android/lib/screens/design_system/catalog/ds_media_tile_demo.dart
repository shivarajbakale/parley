import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/demo_photo.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

final dsMediaTileDemo = DSComponentDemo(
  name: 'DSMediaTile',
  summary: 'The same content model, laid out for a grid or a carousel.',
  stories: [
    DSStory(
      title: 'A grid of posters',
      note:
          'A null width fills the column it is given, so the grid owns '
          'the geometry and the tile owns the content.',
      builder: (context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DSMediaTile(
              source: const DSMediaSource.widget(
                DemoPhoto(asset: DemoPhotos.paletteWall, fallbackHue: 3),
                semanticLabel: 'A wall of paint swatches',
              ),
              aspect: DSMediaAspect.portrait,
              title: 'Colour',
              subtitle: 'Episode 1',
              status: const DSMediaStatus(rank: 1),
              onTap: () {},
            ),
          ),
          SizedBox(width: context.design.space.md),
          Expanded(
            child: DSMediaTile(
              source: const DSMediaSource.widget(
                DemoPhoto(asset: DemoPhotos.explodedView, fallbackHue: 4),
                semanticLabel: 'An exploded diagram of a device',
              ),
              aspect: DSMediaAspect.portrait,
              title: 'Devices',
              subtitle: 'Episode 2',
              status: const DSMediaStatus(rank: 2, progress: 0.7),
              onTap: () {},
            ),
          ),
        ],
      ),
    ),
    DSStory(
      title: 'A carousel',
      note:
          'A token width makes the same tile a carousel item — a row of '
          'them is the whole carousel, with no second component.',
      builder: (context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final photo in const [
              (DemoPhotos.flatLay, 0, 'Report'),
              (DemoPhotos.crossing, 2, 'Release'),
              (DemoPhotos.openBook, 1, 'Tokens'),
            ])
              Padding(
                padding: EdgeInsetsDirectional.only(
                  end: context.design.space.md,
                ),
                child: DSMediaTile(
                  source: DSMediaSource.widget(
                    DemoPhoto(asset: photo.$1, fallbackHue: photo.$2),
                    semanticLabel: '',
                  ),
                  width: context.design.space.xxxl * 3,
                  title: photo.$3,
                  subtitle: 'Watching',
                  status: const DSMediaStatus(progress: 0.3),
                  onTap: () {},
                ),
              ),
          ],
        ),
      ),
    ),
  ],
);
