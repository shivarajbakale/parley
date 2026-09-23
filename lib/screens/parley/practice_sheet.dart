import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_bottom_sheet.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/design_system/ds_text_field.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// A field to dictate into without leaving Parley — the action on the empty
/// states that wait for a first dictation. The orb already floats over this
/// app, so the sheet only has to hand it a focused field.
Future<void> showPracticeSheet(BuildContext context) => showDSBottomSheet<void>(
  context: context,
  header: const DSSheetHeader(title: 'Try it'),
  builder: (context) => const PracticeSheetBody(),
);

/// The sheet's content, separate so a test can mount it without a route.
class PracticeSheetBody extends StatelessWidget {
  const PracticeSheetBody({super.key});

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final gutter = DSGutter.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, space.sm, gutter, space.xl),
      child: const DSTextField(
        label: 'Practice',
        hintText: 'Hold the orb and talk',
        affordances: DSFieldAffordances(autofocus: true),
        input: DSFieldInput(maxLines: 4, minLines: 3),
      ),
    );
  }
}
