import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

final dsFieldGroupDemo = DSComponentDemo(
  name: 'DSFieldGroup',
  fullBleed: true,
  summary: 'A run of form fields under one eyebrow, on the page ground.',
  stories: [
    DSStory(
      title: 'Eyebrow, fields, footer',
      note:
          'The footer is where a sentence too long for a helper line '
          'goes: the helper slot is one fixed line so a form does not '
          'jump when an error replaces it, and a longer one is '
          'ellipsised. A footer wraps.',
      builder: (context) => const DSFieldGroup(
        eyebrow: 'Billing contact',
        footer:
            'Invoices and receipts go to this address. Changing it does '
            'not change the address you sign in with.',
        children: [
          DSTextField(
            label: 'Full name',
            hintText: 'Ada Lovelace',
            leadingIcon: Icons.person_outline,
          ),
          DSTextField(
            label: 'Email',
            hintText: 'you@example.com',
            helperText: 'We only use this for billing.',
            leadingIcon: Icons.mail_outline,
          ),
        ],
      ),
    ),
    DSStory(
      title: 'One field, no eyebrow',
      note:
          'An eyebrow costs its own line plus the gap under it, and over '
          'a group of one it is chrome standing in for the label the '
          'field already carries.',
      builder: (context) => const DSFieldGroup(
        children: [
          DSTextField(label: 'Workspace name', hintText: 'Rocketship'),
        ],
      ),
    ),
    DSStory(
      title: 'Two groups, and a section under them',
      note:
          'A second group is for decisions a reader would answer '
          'separately, not a caption on every field. Rows that navigate '
          'or toggle belong in a DSSettingsSection below the fields — '
          'a field dropped into that section is an outline ring on '
          'identical grey, inset twice.',
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DSFieldGroup(
            eyebrow: 'Workspace',
            children: [DSTextField(label: 'Name', hintText: 'Rocketship')],
          ),
          context.design.space.verticalLg,
          const DSFieldGroup(
            eyebrow: 'Invoices',
            children: [
              DSTextField(
                label: 'Billing email',
                hintText: 'you@example.com',
                leadingIcon: Icons.mail_outline,
              ),
            ],
          ),
          context.design.space.verticalLg,
          const DSSettingsSection(
            eyebrow: 'Plan',
            children: [
              DSSettingsRow(
                label: 'Current plan',
                icon: Icons.workspace_premium_outlined,
                value: 'Team',
              ),
            ],
          ),
        ],
      ),
    ),
  ],
);
