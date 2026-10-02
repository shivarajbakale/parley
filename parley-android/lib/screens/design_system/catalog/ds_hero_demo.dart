import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/catalog/structure_shared_widgets.dart';

final dsHeroDemo = DSComponentDemo(
  name: 'DSHero',
  fullBleed: true,
  summary: 'The branded plate that heads the first screen of a flow.',
  stories: [
    DSStory(
      title: 'Sign in',
      note:
          'The entry point. No leading: there is nothing behind the first '
          'screen of the app to go back to.',
      builder: (context) => StoryStage(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: const DSHero(eyebrow: 'Welcome', title: 'Sign in'),
        ),
      ),
    ),
    DSStory(
      title: 'Pushed, with a subtitle',
      note:
          'Every screen pushed from the entry point takes a leading '
          'affordance. The subtitle is for a flow that has to say what it '
          'is about to ask for before it asks.',
      builder: (context) => StoryStage(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: DSHero(
            eyebrow: 'No account yet',
            title: 'Create one',
            subtitle: 'An email and a password. Nothing else, ever.',
            leading: DSIconButton(
              icon: Icons.arrow_back,
              semanticLabel: 'Back',
              onPressed: () {},
            ),
          ),
        ),
      ),
    ),
    DSStory(
      title: 'A mark of your own',
      note:
          'The kit ships a placeholder glyph on an accent tile. An app '
          'with a real logo passes it here — the plate underneath is '
          'unchanged, which is the point of the slot.',
      builder: (context) => StoryStage(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: DSHero(
            eyebrow: 'Rocketship',
            title: 'Welcome back',
            mark: DSAvatar.fromName(name: 'Rocketship', size: DSAvatarSize.lg),
          ),
        ),
      ),
    ),
  ],
);
