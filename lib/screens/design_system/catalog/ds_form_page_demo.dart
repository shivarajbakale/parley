import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/catalog/structure_shared_widgets.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

final dsFormPageDemo = DSComponentDemo(
  name: 'DSFormPage',
  fullBleed: true,
  summary:
      'The page whose title stays put and whose primary action is '
      'pinned.',
  stories: [
    DSStory(
      title: 'A form under its bar',
      note:
          'The header is fixed and the fields scroll under the bar, not '
          'against it. The clearance below the last field is the height '
          'the bar reports, so no screen picks a number: four built this '
          'shape by hand and picked four.',
      builder: (context) => SizedBox(
        height: 320,
        child: StoryStage(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: DSFormPage(
              eyebrow: 'WORKSPACE',
              title: 'Invite a member',
              subtitle: 'Who is joining, and what may they do?',
              leading: const BackButton(),
              footer: DSPinnedActionBar(
                helperText: 'They get an email straight away.',
                children: [DSButton(label: 'Send invite', onPressed: () {})],
              ),
              children: const [
                DSFieldGroup(
                  children: [
                    DSTextField(label: 'Email', hintText: 'name@company.com'),
                    DSTextField(label: 'Job title', hintText: 'Optional'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    DSStory(
      title: 'The title that does not scroll away',
      note:
          'Scroll it. On a page of content the header should go — the '
          'content is the subject. On a form it must not: the header '
          'names what is being filled in and the bar names what the '
          'button will do with it, and a reader with both gone is '
          'answering questions about an unnamed thing.',
      builder: (context) => SizedBox(
        height: 300,
        child: StoryStage(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: DSFormPage(
              title: 'Report a problem',
              leading: const BackButton(),
              footer: DSPinnedActionBar(
                children: [DSButton(label: 'Send', onPressed: () {})],
              ),
              children: [
                const DSFieldGroup(
                  children: [
                    DSTextField(label: 'What happened?'),
                    DSTextField(label: 'When?'),
                    DSTextField(label: 'Where in the app?'),
                    DSTextField(label: 'Anything else?'),
                  ],
                ),
                SizedBox(height: context.design.space.lg),
                const DSCard(
                  child: Text(
                    'The header is still up there, and so is the button.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    DSStory(
      title: 'Rows that own their own edge',
      note:
          'DSFormPage.fullBleed. A DSListTile insets its own content so '
          'its divider can run to the edge — inside a gutter-padded '
          'scroll it is indented twice and stands out of the column it '
          'belongs to.',
      builder: (context) => SizedBox(
        height: 260,
        child: StoryStage(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: DSFormPage.fullBleed(
              title: 'Repeat',
              leading: const BackButton(),
              footer: DSPinnedActionBar(
                children: [DSButton(label: 'Save rule', onPressed: () {})],
              ),
              children: const [
                DSListTile(
                  title: 'Every week',
                  subtitle: 'On the day it starts',
                  trailing: Icon(Icons.check),
                ),
                DSListTile(title: 'Every month', subtitle: 'On the date'),
                DSListTile(title: 'Never', subtitle: 'It happens once'),
              ],
            ),
          ),
        ),
      ),
    ),
  ],
);
