@Tags(<String>['golden'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '_harness.dart';

/// Proves the golden harness loaded real fonts before any baseline is trusted.
///
/// This is the first file in the suite on purpose. A Flutter test that has not
/// loaded the asset fonts still renders — every glyph becomes the same fallback
/// box — so a whole set of baselines can be recorded, committed and reviewed
/// while encoding nothing about type or iconography. The failure is invisible
/// in the diff of the run that introduces it, because there is no earlier image
/// to compare against.
///
/// So the harness is tested rather than assumed, and by a property no fallback
/// can satisfy: two different characters must not paint the same pixels.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadGoldenFonts);

  test('Satoshi is loaded, not substituted', () {
    // The test font is fixed-width: in it every string of four characters lays
    // out to the same width. Satoshi is proportional, so a W and three i's are
    // narrower than four W's. If the family failed to load, both measurements
    // fall through to the same substitute and the widths match exactly.
    double widthOf(String text, String? family) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: family, fontSize: 32),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    final narrow = widthOf('Wiii', 'Satoshi');
    final wide = widthOf('WWWW', 'Satoshi');
    expect(
      narrow,
      lessThan(wide - 1),
      reason:
          'Satoshi did not load — the substitute font is fixed-width, so '
          'every glyph is the same box and every baseline is worthless',
    );
  });

  testWidgets('MaterialIcons is loaded, not substituted', (tester) async {
    // Two icons that look nothing alike. Without the icon font both render as
    // the same fallback box and the images are byte-identical, which is exactly
    // the state this suite must never record a baseline in.
    final check = await _paint(tester, Icons.check);
    final close = await _paint(tester, Icons.close);

    expect(
      check,
      isNot(equals(close)),
      reason:
          'MaterialIcons did not load — every icon is painting the same '
          'fallback box',
    );
  });
}

/// Renders [icon] on its own and returns the raw pixels.
Future<Uint8List> _paint(WidgetTester tester, IconData icon) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Icon(icon, size: 40, color: const Color(0xFF000000)),
            ),
          ),
        ),
      ),
    ),
  );

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  // `runAsync` is required, not tidiness: rasterising goes out to the engine,
  // and the fake async zone a widget test runs in never lets that future
  // complete. Without it the test simply hangs until the ten-minute timeout.
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}
