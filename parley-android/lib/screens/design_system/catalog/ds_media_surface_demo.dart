import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/demo_photo.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

final dsMediaSurfaceDemo = DSComponentDemo(
  name: 'DSMediaSurface',
  summary: 'The picture box the three media shapes share.',
  stories: [
    DSStory(
      title: 'Three aspects, one box',
      note:
          'A height and an aspect are the whole sizing contract: the '
          'width follows, so a mixed list keeps one left edge.',
      builder: (context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final aspect in const [
              DSMediaAspect.square,
              DSMediaAspect.wide,
              DSMediaAspect.portrait,
            ])
              Padding(
                padding: EdgeInsetsDirectional.only(
                  end: context.design.space.md,
                ),
                child: DSMediaSurface(
                  source: const DSMediaSource.widget(
                    DemoPhoto(asset: DemoPhotos.crossing, fallbackHue: 2),
                    semanticLabel: '',
                  ),
                  aspect: aspect,
                  height: context.design.space.xxxl * 3,
                ),
              ),
          ],
        ),
      ),
    ),
    DSStory(
      title: 'The status vocabulary',
      note:
          'Every state the family can draw on a picture lives here, so '
          'a row, a tile and a hero say the same thing the same way.',
      builder: (context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final status in const [
              DSMediaStatus(
                duration: Duration(minutes: 4, seconds: 12),
                progress: 0.4,
              ),
              DSMediaStatus(
                playback: DSMediaPlayback.playing,
                offline: DSMediaOffline.downloaded,
              ),
              DSMediaStatus(live: true, rank: 1),
            ])
              Padding(
                padding: EdgeInsetsDirectional.only(
                  end: context.design.space.md,
                ),
                child: DSMediaSurface(
                  source: const DSMediaSource.widget(
                    DemoPhoto(asset: DemoPhotos.flatLay, fallbackHue: 0),
                    semanticLabel: '',
                  ),
                  aspect: DSMediaAspect.square,
                  status: status,
                  showRank: true,
                  height: context.design.space.xxxl * 3,
                ),
              ),
          ],
        ),
      ),
    ),
  ],
);
