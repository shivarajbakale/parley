import 'package:flutter_test/flutter_test.dart';

import '../../tool/design_system_reference.dart';

/// A generator whose parser is unverified writes a reference that is confidently
/// wrong, which is worse than no reference: an agent trusts it and then passes
/// the parameter it names. These tests run the parser against strings.
void main() {
  Component parse(String name, String source) =>
      parseComponent('lib/design_system/$name.dart', source);

  group('what a component file yields', () {
    test('the class the file is named after is the primary one', () {
      final c = parse('ds_button', '''
class _Helper extends StatelessWidget {}

class DSButton extends StatelessWidget {
  final String label;

  const DSButton({super.key, required this.label});
}
''');
      expect(c.primary?.name, 'DSButton');
      expect(c.primary?.superclass, 'StatelessWidget');
      expect(c.title, 'DSButton');
    });

    test('a private class is neither primary nor a companion', () {
      final c = parse('ds_tab_bar', '''
class DSTabBar extends StatelessWidget {
  const DSTabBar({super.key});
}

class DSTabItem {
  const DSTabItem();
}

class _PillTabBar extends StatelessWidget {
  const _PillTabBar();
}
''');
      expect(c.companions.map((k) => k.name), ['DSTabItem']);
    });

    test('an underscore-prefixed file is private to the kit', () {
      // The same convention ui_lint's barrel-drift rule uses.
      expect(isComponentFile('ds_button.dart'), isTrue);
      expect(isComponentFile('_ds_recent_searches.dart'), isFalse);
      expect(isComponentFile('design_system.dart'), isFalse);
    });

    test(
      'a file whose API is a top-level function is not reported as empty',
      () {
        // `ds_bottom_sheet.dart` ships `showDSBottomSheet` and one small widget.
        final c = parse('ds_bottom_sheet', '''
Future<T?> showDSBottomSheet<T>({
  required BuildContext context,
  bool expand = false,
}) async {
  return null;
}
''');
        expect(c.functions.single.name, 'showDSBottomSheet');
        expect(c.functions.single.params.map((p) => p.name), [
          'context',
          'expand',
        ]);
      },
    );
  });

  group('constructor parameters', () {
    test('a `this.` parameter takes its type from the field', () {
      final c = parse('ds_card', '''
class DSCard extends StatelessWidget {
  final DSCardVariant variant;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const DSCard({
    super.key,
    this.variant = DSCardVariant.elevated,
    required this.child,
    this.padding,
  });
}
''');
      final params = c.primary!.ctors.single.params;
      expect(params.map((p) => p.render()), [
        'Key? key',
        'DSCardVariant variant = DSCardVariant.elevated',
        'required Widget child',
        'EdgeInsetsGeometry? padding',
      ]);
    });

    test('a narrowed field parameter keeps the type and drops the `this.`', () {
      // `required Widget this.body` is legal Dart — DSAnimatedModal uses it to
      // narrow a nullable field per constructor — and a naive split reports the
      // parameter as being named `this.body`.
      final c = parse('ds_animated_modal', '''
class DSAnimatedModal extends StatelessWidget {
  final Widget? body;

  const DSAnimatedModal({super.key, required Widget this.body});
}
''');
      expect(
        c.primary!.ctors.single.params.last.render(),
        'required Widget body',
      );
    });

    test('a local `final` inside a method is not a field declaration', () {
      // `final rawOnPressed = isLoading ? null : onPressed;` in a build method
      // reads as a field named `onPressed` unless indentation and the absence
      // of an initialiser are both required.
      final c = parse('ds_button', '''
class DSButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const DSButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final rawOnPressed = isLoading ? null : onPressed;
    return SizedBox();
  }
}
''');
      expect(
        c.primary!.ctors.single.params.last.render(),
        'VoidCallback? onPressed',
      );
    });

    test('named constructors are listed separately', () {
      final c = parse('ds_loading_state', '''
class DSLoadingState extends StatelessWidget {
  const DSLoadingState({super.key});
  const DSLoadingState.skeleton({super.key, required Widget child});
}
''');
      expect(c.primary!.ctors.map((x) => x.signature('DSLoadingState')), [
        'const DSLoadingState(…)',
        'const DSLoadingState.skeleton(…)',
      ]);
    });

    test(
      'a static helper is captured — some components have no constructor',
      () {
        // DSSnackBar's whole API is `DSSnackBar.show(...)`.
        final c = parse('ds_snack_bar', '''
class DSSnackBar {
  static void show(BuildContext context, {required String message}) {}
  static void _internal() {}
}
''');
        expect(c.primary!.statics.map((s) => s.name), ['show']);
        expect(c.primary!.statics.single.params.map((p) => p.name), [
          'context',
          'message',
        ]);
      },
    );
  });

  group('enums', () {
    test('values are read, and an enhanced enum stops at its members', () {
      final c = parse('ds_button', '''
enum DSButtonSize { sm, md, lg }

enum DSBannerVariant {
  info,
  success,
  // a trailing comment is not a value
  error;

  const DSBannerVariant();
  bool get isBad => this == error;
}

enum _RowKind { nav, toggle }

class DSButton extends StatelessWidget {
  const DSButton({super.key});
}
''');
      final public = c.enums.where((e) => e.isPublic).toList();
      expect(public.map((e) => e.name), ['DSButtonSize', 'DSBannerVariant']);
      expect(public[0].values, ['sm', 'md', 'lg']);
      expect(public[1].values, ['info', 'success', 'error']);
      expect(c.enums.any((e) => e.name == '_RowKind' && !e.isPublic), isTrue);
    });
  });

  group('the doc summary', () {
    test('stops at the first bullet instead of dropping it mid-sentence', () {
      final c = parse('ds_snap_bottom_sheet', '''
/// A draggable bottom sheet with snap points.
///
/// Features:
/// - Drag to snap between defined points
/// - Keyboard avoidance
class DSSnapBottomSheet extends StatefulWidget {
  const DSSnapBottomSheet({super.key});
}
''');
      final out = renderReference([c]);
      expect(out, contains('A draggable bottom sheet with snap points.'));
      // The colon introduced a list that is not in the reference.
      expect(out, isNot(contains('Features:')));
    });
  });

  group('the selection gate', () {
    test('a component with no entry is named, and a stale entry too', () {
      final gaps = selectionGaps(['ds_button', 'ds_brand_new_thing']);
      expect(gaps.missing, ['ds_brand_new_thing']);
      expect(gaps.stale, contains('ds_card'));
      expect(gaps.stale, isNot(contains('ds_button')));
    });

    test('every shipped component has both halves of its guidance', () {
      // The `instead` half is the one that earns the file; an entry that only
      // says what a widget is for teaches nothing a name does not.
      final components = readComponents(componentDirectory());
      final gaps = selectionGaps(components.map((c) => c.key).toList());
      expect(gaps.missing, isEmpty);
      expect(gaps.stale, isEmpty);

      final out = renderReference(components);
      for (final c in components) {
        expect(out, contains('### `${c.title}`'));
      }
      expect(
        RegExp(r'\*\*Instead:\*\*').allMatches(out).length,
        components.length,
      );
    });
  });

  test('rendering is deterministic', () {
    // --check compares byte-for-byte, so a timestamp or a directory ordering
    // would report every checkout as stale.
    final components = readComponents(componentDirectory());
    expect(renderReference(components), renderReference(components));
  });
}
