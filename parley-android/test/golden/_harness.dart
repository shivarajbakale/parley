import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The golden harness: fonts, the variant matrix, and the contact sheet.
///
/// **Why a contact sheet rather than one image per variant.** Every subject in
/// this suite has to be checked on both platforms, in both brightnesses, and
/// at a doubled text scale. Written as separate files that is six PNGs per
/// subject, and a reviewer looking at one diff cannot see whether the change
/// was meant to apply to the other five. Rendering the whole matrix into a
/// single image makes the comparison the artifact: one file, one diff, and the
/// variants sit next to each other the way a photographer's contact sheet puts
/// every frame on one page.
///
/// **The trap this file exists to avoid.** In a Flutter test the asset fonts
/// are not loaded unless something loads them, and an unloaded font renders
/// every glyph as the same fallback box. A whole suite of baselines can be
/// generated, committed and reviewed in that state: the images look plausibly
/// like layout, and they encode nothing about type or iconography at all.
/// [loadGoldenFonts] loads both families from the manifest, and
/// `font_harness_test.dart` proves the load worked before any baseline is
/// trusted.
///
/// **These baselines belong to one host.** Text rasterisation is not identical
/// across operating systems, so the PNGs here were recorded on the host named
/// by `GOLDEN_HOST` in the Makefile, and the CI job that verifies them runs on
/// the matching runner. Changing hosts means changing both, together, and
/// re-recording — `make golden-update`.

/// One frame of the contact sheet.
@immutable
class GoldenVariant {
  const GoldenVariant({
    required this.label,
    required this.platform,
    required this.brightness,
  });

  /// The caption printed above the frame. It is drawn outside the frame's own
  /// [MediaQuery], so it stays legible on the doubled-text-scale sheet.
  final String label;

  final TargetPlatform platform;
  final Brightness brightness;
}

/// The appearance matrix: the two platform skins against the two brightnesses.
///
/// Order matters — it is the reading order of the rendered sheet, two columns
/// wide, so a platform is a column and a brightness is a row.
const List<GoldenVariant> appearanceMatrix = <GoldenVariant>[
  GoldenVariant(
    label: 'Apple · light',
    platform: TargetPlatform.iOS,
    brightness: Brightness.light,
  ),
  GoldenVariant(
    label: 'Material · light',
    platform: TargetPlatform.android,
    brightness: Brightness.light,
  ),
  GoldenVariant(
    label: 'Apple · dark',
    platform: TargetPlatform.iOS,
    brightness: Brightness.dark,
  ),
  GoldenVariant(
    label: 'Material · dark',
    platform: TargetPlatform.android,
    brightness: Brightness.dark,
  ),
];

/// The accessibility matrix: both platforms at a doubled text scale.
///
/// Light only, and deliberately so. Doubling the text scale tests whether the
/// layout survives, and the layout does not know what brightness it is in;
/// running it in dark as well would double the baselines to re-check something
/// the appearance sheet already covers.
const List<GoldenVariant> accessibilityMatrix = <GoldenVariant>[
  GoldenVariant(
    label: 'Apple · textScale 2.0',
    platform: TargetPlatform.iOS,
    brightness: Brightness.light,
  ),
  GoldenVariant(
    label: 'Material · textScale 2.0',
    platform: TargetPlatform.android,
    brightness: Brightness.light,
  ),
];

/// The size of one frame. A small phone: the width that breaks first, at the
/// height the probe grades.
///
/// The two used to disagree — 720 here against `ProbeCell.height`'s 844 —
/// and the disagreement was silent. A booking form was reasoned about at 844,
/// where its last control cleared the pinned bar by 11 points, and
/// photographed at 720, where the same control was under the bar and out of
/// the only picture anyone reviews. A screen has to be graded and seen at the
/// same size or one of the two is describing a phone nobody has.
/// `test/screens_registry_test.dart` holds them together.
const Size kPhoneFrame = Size(360, 844);

/// A shorter frame for the component galleries, which scroll their own
/// content and do not need a full screen's height to be legible.
const Size kGalleryFrame = Size(360, 640);

const double _captionHeight = 22;

/// Loads every font the app declares, so glyphs render as glyphs.
///
/// Reads `FontManifest.json` from the test asset bundle rather than naming
/// files, which is what picks up **MaterialIcons** — the icon font is injected
/// into the manifest by `uses-material-design: true` and lives inside the SDK
/// cache, so there is no path in this repository to point a [FontLoader] at.
Future<void> loadGoldenFonts() async {
  final manifest = await rootBundle.loadStructuredData<List<dynamic>>(
    'FontManifest.json',
    (String source) async => json.decode(source) as List<dynamic>,
  );

  for (final dynamic entry in manifest) {
    final font = entry as Map<String, dynamic>;
    final loader = FontLoader(_familyOf(font));
    for (final dynamic asset in font['fonts'] as List<dynamic>) {
      loader.addFont(
        rootBundle.load((asset as Map<String, dynamic>)['asset'] as String),
      );
    }
    await loader.load();
  }
}

/// Decodes every bundled photograph into the image cache, so an asset image
/// paints on the first frame of a sheet.
///
/// The trap is the same shape as the font one above. A widget test drives a
/// fake clock, and an `Image.asset` that has not been decoded yet resolves
/// across a real microtask that the fake clock never reaches — so the picture
/// is simply absent from the baseline, and the baseline looks like a
/// deliberate empty box. Decoded here, in `setUpAll`, where the clock is
/// real, the stream completer is already holding a frame and hands it to the
/// widget synchronously when it subscribes.
Future<void> loadGoldenImages() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final images = manifest.listAssets().where(
    (String asset) => asset.startsWith('assets/images/'),
  );

  for (final String asset in images) {
    final completer = Completer<void>();
    final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void done() {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    }

    listener = ImageStreamListener(
      (ImageInfo _, bool _) => done(),
      // A missing asset is the fallback swatch's job, not a reason to fail
      // every golden in the suite before it has rendered anything.
      onError: (Object _, StackTrace? _) => done(),
    );
    stream.addListener(listener);
    await completer.future;
  }
}

/// The family name a [TextStyle] would have to ask for.
///
/// A font shipped by a package is addressed as `packages/<package>/<family>`
/// even though the manifest records the bare family, so the prefix has to be
/// put back or the font loads under a name nothing references.
String _familyOf(Map<String, dynamic> font) {
  final family = font['family'] as String;
  if (family.startsWith('packages/')) return family;
  for (final dynamic asset in font['fonts'] as List<dynamic>) {
    final path = (asset as Map<String, dynamic>)['asset'] as String;
    if (path.startsWith('packages/')) {
      return 'packages/${path.split('/')[1]}/$family';
    }
  }
  return family;
}

/// Renders [build] once per variant into one image and compares it against
/// `goldens/<name>.png`.
///
/// [build] is called per frame rather than passed as a widget, because the same
/// widget instance cannot sit in four subtrees at once and a subject with a
/// controller in it needs its own.
///
/// [scope] wraps the whole sheet — one `ProviderScope` for all frames, since
/// the frames differ by theme rather than by state.
Future<void> expectGoldenSheet(
  WidgetTester tester, {
  required String name,
  required Widget Function() build,
  Size frame = kGalleryFrame,
  List<GoldenVariant> variants = appearanceMatrix,
  double textScale = 1.0,
  int columns = 2,
  bool mustFit = false,
  Widget Function(Widget child)? scope,
  DesignSpec? spec,
}) async {
  final rows = (variants.length / columns).ceil();
  final design = spec ?? AppTheme.spec;

  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  Future<void> render(Size frameSize) async {
    tester.view.physicalSize = Size(
      frameSize.width * columns,
      (frameSize.height + _captionHeight) * rows,
    );
    Widget sheet = _ContactSheet(
      frame: frameSize,
      columns: columns,
      textScale: textScale,
      variants: variants,
      frameBuilder: build,
      spec: design,
    );
    if (scope != null) sheet = scope(sheet);
    await tester.pumpWidget(sheet);

    // A fixed number of frames rather than `pumpAndSettle`: the kit's
    // skeletons and progress indicators animate forever by design, and
    // settling on them never returns. Several frames rather than one long
    // jump, because the staggered entrance schedules each row from a
    // post-frame callback — jump straight to the end and every delayed row is
    // still at opacity zero, which renders as a page with its content
    // missing. The test clock is deterministic, so the same frames land in
    // the same place in every run.
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  await render(frame);

  if (mustFit) {
    // Grow the frame to whatever the tallest variant needs, then check.
    //
    // A gallery is a `SingleChildScrollView` inside a fixed frame, so anything
    // past the frame's height is simply not painted — and the golden matches,
    // because the golden only ever saw the top. Two widgets were added to the
    // `meters` gallery and neither changed a single pixel of its baseline, and
    // `forms` was hiding 358 points, more than half a frame. A picture that
    // silently stops at the fold reports coverage that does not exist.
    //
    // Twice, not once: growing the frame reflows the content, and a Wrap that
    // had two rows at the old width can want a third line of height at the
    // new one.
    for (int pass = 0; pass < 2; pass++) {
      final hidden = _hiddenExtent(tester);
      if (hidden <= 0.5) break;
      frame = Size(frame.width, frame.height + hidden.ceilToDouble());
      await render(frame);
    }
    expect(
      _hiddenExtent(tester),
      lessThanOrEqualTo(0.5),
      reason:
          'the $name sheet still has content below its frame after two '
          'growth passes — split the gallery rather than leaving it hidden.',
    );
  }

  await expectLater(
    find.byType(_ContactSheet),
    matchesGoldenFile('goldens/$name.png'),
  );
}

/// The pixels [spec] renders for [build], as raw RGBA.
///
/// The other half of [expectGoldenSheet]. A baseline proves an identity did
/// not change since somebody last looked at it; it cannot prove that two
/// identities render differently, because each one is compared only against
/// its own past. Comparing the pixels of one identity against another is the
/// only check that can tell a live derivation from a dead one — a widget that
/// quietly kept a constant of its own draws the same thing under every spec,
/// and every baseline still passes.
///
/// Same sheet, same frames, same clock as [expectGoldenSheet], so a difference
/// in the bytes is a difference in the design and nothing else.
Future<Uint8List> renderSheetPixels(
  WidgetTester tester, {
  required DesignSpec spec,
  required Widget Function() build,
  Size frame = kPhoneFrame,
  List<GoldenVariant> variants = appearanceMatrix,
  double textScale = 1.0,
  int columns = 2,
  Widget Function(Widget child)? scope,
}) async {
  final rows = (variants.length / columns).ceil();

  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.view.physicalSize = Size(
    frame.width * columns,
    (frame.height + _captionHeight) * rows,
  );

  Widget sheet = _ContactSheet(
    frame: frame,
    columns: columns,
    textScale: textScale,
    variants: variants,
    frameBuilder: build,
    spec: spec,
  );
  if (scope != null) sheet = scope(sheet);
  await tester.pumpWidget(sheet);
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }

  // Started outside `runAsync` and awaited inside it, the way
  // `matchesGoldenFile` does: `captureImage` asserts the tree has been
  // painted, and the encode is the part that needs a real event loop.
  final imageFuture = captureImage(
    find.byType(_ContactSheet).evaluate().single,
  );
  final bytes = await tester.runAsync(() async {
    final image = await imageFuture;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// The share of pixels that differ between two sheets of the same size.
///
/// A fraction rather than a boolean, so a failure says how nearly identical
/// the two identities were rather than only that they were not different.
double pixelDifference(Uint8List a, Uint8List b) {
  if (a.length != b.length) return 1;
  var differing = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) {
      differing++;
    }
  }
  return differing / (a.length / 4);
}

/// The most any one variant has scrolled out of view *below the fold*, in
/// points.
///
/// Vertical scrollables only. The caller grows the frame's height by whatever
/// this returns, so counting a horizontal one asks it to fix sideways overflow
/// with vertical room: `DSTabBar` scrolls its strip when the labels do not
/// fit, and the tab_bar gallery's 79 points of off-screen tabs were read as 79
/// points of hidden content, twice, and then reported as a gallery that needed
/// splitting.
double _hiddenExtent(WidgetTester tester) {
  var worst = 0.0;
  for (final element in find.byType(Scrollable).evaluate()) {
    // The element *is* the Scrollable, so its own state holds the position —
    // `Scrollable.of` looks upward and finds nothing.
    final state = (element as StatefulElement).state as ScrollableState;
    if (state.position.axis != Axis.vertical) continue;
    final extra = state.position.maxScrollExtent;
    if (extra > worst) worst = extra;
  }
  return worst;
}

class _ContactSheet extends StatelessWidget {
  const _ContactSheet({
    required this.frame,
    required this.columns,
    required this.textScale,
    required this.variants,
    required this.frameBuilder,
    required this.spec,
  });

  final Size frame;
  final int columns;
  final double textScale;
  final List<GoldenVariant> variants;
  final Widget Function() frameBuilder;
  final DesignSpec spec;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        // A mid grey: neither theme's surface, so the frame edges read on both
        // the light and the dark rows.
        color: const Color(0xFF6E6E6E),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int row = 0; row * columns < variants.length; row++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (
                    int col = 0;
                    col < columns && row * columns + col < variants.length;
                    col++
                  )
                    _Frame(
                      variant: variants[row * columns + col],
                      size: frame,
                      textScale: textScale,
                      spec: spec,
                      child: frameBuilder(),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.variant,
    required this.size,
    required this.textScale,
    required this.spec,
    required this.child,
  });

  final GoldenVariant variant;
  final Size size;
  final double textScale;
  final DesignSpec spec;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // From the spec being rendered, not from `AppTheme`. A sheet that took
    // the app's theme while wrapping a different `Design` would paint one
    // identity's colours through another identity's `ThemeData`, and the
    // difference the identity sheets are looking for would be half real.
    final theme = spec
        .themeFor(variant.brightness)
        .copyWith(platform: variant.platform);

    return SizedBox(
      width: size.width,
      height: size.height + _captionHeight,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: _captionHeight,
            child: Center(
              child: Text(
                variant.label,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 12,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            // The spec, installed the way `lib/app.dart` installs it. Without
            // it every widget that reads `context.palette` renders
            // `DesignSpec.fallback` — a different identity entirely — and the
            // sheet would be a picture of the fallback rather than of the app.
            child: Design(
              spec: spec,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                // Inside the app, not around it: MaterialApp installs its own
                // MediaQuery from the test view, which is the size of the
                // whole sheet. Left alone, every frame would believe it was as
                // wide as all of them together.
                builder: (BuildContext context, Widget? inner) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: size,
                    textScaler: TextScaler.linear(textScale),
                    padding: EdgeInsets.zero,
                    viewInsets: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                  ),
                  child: inner!,
                ),
                home: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
