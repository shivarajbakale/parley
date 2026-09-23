import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/ds_compact_app_bar.dart';
import 'package:parley_android/design_system/ds_pinned_header.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The band that holds a filter on screen while the list under it moves.
///
/// Three screens hand-rolled this before it was a component, so the contract
/// worth testing is the one each of them was retyping: it stays, it stacks
/// under the pinned slivers above it, it is opaque, and its height is its
/// child's rather than a number.
void main() {
  /// Both the bar and the band are slivers, so neither widget has a box to
  /// measure. The band's ground is its own `DecoratedBox`, and the bar's is
  /// the `AppBar` inside its persistent header.
  Finder bandBox() => find
      .descendant(
        of: find.byType(DSPinnedHeader),
        matching: find.byType(DecoratedBox),
      )
      .first;

  Future<void> pump(
    WidgetTester tester, {
    double bandHeight = 44,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                const DSCompactAppBar(title: 'Library'),
                DSPinnedHeader(
                  child: SizedBox(
                    height: bandHeight,
                    child: const Center(child: Text('Filters')),
                  ),
                ),
                SliverList.list(
                  children: List.generate(
                    30,
                    (i) => SizedBox(height: 80, child: Text('row $i')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('it holds its line while the list scrolls under it', (
    tester,
  ) async {
    await pump(tester);
    final before = tester.getRect(find.text('Filters'));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsOneWidget);
    expect(tester.getRect(find.text('Filters')), before);
  });

  testWidgets('it stacks under the pinned bar above it, not through it', (
    tester,
  ) async {
    await pump(tester);
    final bar = tester.getRect(find.byType(AppBar));
    final band = tester.getRect(bandBox());

    expect(
      band.top,
      greaterThanOrEqualTo(bar.bottom),
      reason: 'the band honours the overlap of the pinned sliver above it',
    );
  });

  testWidgets('its height is its child, at any text size', (tester) async {
    await pump(tester, bandHeight: 44);
    expect(tester.getRect(bandBox()).height, 44);

    await pump(tester, bandHeight: 61, textScaler: const TextScaler.linear(2));
    expect(
      tester.getRect(bandBox()).height,
      61,
      reason: 'no number of its own to recompute when the child grows',
    );
  });

  testWidgets('the ground is opaque, so rows cannot show through it', (
    tester,
  ) async {
    await pump(tester);
    final context = tester.element(find.byType(DSPinnedHeader));
    final decoration =
        tester.widget<DecoratedBox>(bandBox()).decoration as BoxDecoration;

    expect(decoration.color, context.palette.background);
    expect(decoration.color!.a, 1.0);
  });
}
