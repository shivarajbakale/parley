import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/demo_photo.dart';

final dsMediaHeroDemo = DSComponentDemo(
  name: 'DSMediaHero',
  fullBleed: true,
  summary: 'The one featured item a surface leads with.',
  stories: [
    DSStory(
      title: 'Text below the picture',
      note:
          'The default, because text on its own ground is legible over '
          'any picture the app did not choose.',
      builder: (context) => DSMediaHero(
        source: const DSMediaSource.widget(
          DemoPhoto(asset: DemoPhotos.crossing, fallbackHue: 2),
          semanticLabel: 'A pedestrian crossing from above',
        ),
        eyebrow: 'Featured',
        title: 'A crossing, and queueing',
        subtitle: 'Eight minutes · Systems',
        status: const DSMediaStatus(duration: Duration(minutes: 8), live: true),
        onTap: () {},
      ),
    ),
    DSStory(
      title: 'Text over the picture',
      note:
          'Opt-in, and only over a picture you control. Past 1.6x text '
          'scale it falls back to the layout above.',
      builder: (context) => DSMediaHero(
        source: const DSMediaSource.widget(
          DemoPhoto(asset: DemoPhotos.paletteWall, fallbackHue: 3),
          semanticLabel: 'A wall of paint swatches',
        ),
        placement: DSMediaHeroPlacement.overlay,
        eyebrow: 'Series',
        title: 'Colour, and meaning',
        subtitle: 'Six episodes',
        onTap: () {},
      ),
    ),
    DSStory(
      title: 'Full bleed',
      note:
          'The one member of the family permitted to drop the page '
          'gutter — and it squares the corners when it does.',
      builder: (context) => DSMediaHero(
        source: const DSMediaSource.widget(
          DemoPhoto(asset: DemoPhotos.flatLay, fallbackHue: 0),
          semanticLabel: 'A flat lay of desk objects',
        ),
        fullBleed: true,
        eyebrow: 'This week',
        title: 'The desk, and its objects',
        subtitle: 'Photo essay',
        onTap: () {},
      ),
    ),
  ],
);
