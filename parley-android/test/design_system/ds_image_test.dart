import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The three states a fetched picture has, and the fourth thing it must not
/// do: reflow the layout it sits in when the bytes land.
///
/// Every one of these was a real defect before the component existed. The
/// avatar shipped an `errorBuilder` and no placeholder, so a list of them
/// jumped as each face arrived; the media row had all three but wrote them
/// inline, so the next call site got to disagree about what a failure looks
/// like.
void main() {
  late ui.Image bytes;

  setUpAll(() async {
    bytes = await createTestImage(width: 8, height: 8);
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool reducedMotion = false,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: Scaffold(
              body: Center(child: SizedBox(width: 200, child: child)),
            ),
          ),
        ),
      ),
    );
  }

  group('the arriving state', () {
    testWidgets('holds the box open at its final size, shimmering', (
      tester,
    ) async {
      await pump(
        tester,
        const DSImage.provider(_Pending(), aspectRatio: 1, decorative: true),
      );

      expect(find.byType(DSSkeleton), findsOneWidget);
      // The box is the box it will be. Nothing under it moves later.
      expect(tester.getSize(find.byType(DSImage)), const Size(200, 200));
    });

    testWidgets('a caller can replace it — the avatar shows initials', (
      tester,
    ) async {
      await pump(
        tester,
        const DSImage.provider(
          _Pending(),
          aspectRatio: 1,
          decorative: true,
          placeholder: Text('JA'),
        ),
      );

      expect(find.text('JA'), findsOneWidget);
      expect(find.byType(DSSkeleton), findsNothing);
    });
  });

  group('the failed state', () {
    testWidgets('draws one glyph rather than an empty box', (tester) async {
      await pump(
        tester,
        const DSImage.provider(_Broken(), aspectRatio: 1, decorative: true),
      );
      await tester.pump();

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is one glyph and not a sentence', (tester) async {
      await pump(
        tester,
        const DSImage.provider(_Broken(), aspectRatio: 1, decorative: true),
      );
      await tester.pump();

      expect(find.byType(Text), findsNothing);
    });
  });

  group('the arrived state', () {
    testWidgets('a frame that was already cached does not fade', (
      tester,
    ) async {
      await pump(
        tester,
        DSImage.provider(_Cached(bytes), aspectRatio: 1, decorative: true),
      );

      // A cached picture that fades makes the second visit to a screen look
      // slower than the first.
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    testWidgets('a frame that had to be fetched fades in', (tester) async {
      await pump(
        tester,
        DSImage.provider(_Late(bytes), aspectRatio: 1, decorative: true),
      );
      await tester.pump();

      expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion skips the fade entirely', (tester) async {
      await pump(
        tester,
        DSImage.provider(_Late(bytes), aspectRatio: 1, decorative: true),
        reducedMotion: true,
      );
      await tester.pump();

      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });
  });

  group('content or decoration', () {
    testWidgets('a decorative picture leaves the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const DSImage.provider(_Pending(), aspectRatio: 1, decorative: true),
      );

      final node = tester.getSemantics(find.byType(DSImage));
      expect(node.label, isEmpty);
      expect(node.flagsCollection.isImage, isFalse);
      handle.dispose();
    });

    testWidgets('a content picture carries its label', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const DSImage.provider(
          _Pending(),
          aspectRatio: 1,
          semanticLabel: 'A crossing',
        ),
      );

      // `contains` rather than `equals`: the skeleton under it announces
      // "Loading" while the bytes are in flight, and a reader hearing "A
      // crossing, loading" is being told both things it needs.
      final node = tester.getSemantics(find.byType(DSImage));
      expect(node.label, contains('A crossing'));
      expect(node.flagsCollection.isImage, isTrue);
      handle.dispose();
    });

    testWidgets('being neither is an assertion, not a silent omission', (
      tester,
    ) async {
      expect(
        () => DSImage.network('https://example.invalid/a.jpg'),
        throwsAssertionError,
      );
    });
  });

  group('the style chain', () {
    testWidgets('the radius is a step on the shape ladder', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  ctx = context;
                  return const SizedBox(
                    width: 200,
                    child: DSImage.provider(
                      _Pending(),
                      aspectRatio: 1,
                      decorative: true,
                      shape: AppShape.card,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(DSImage),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(
        clip.borderRadius,
        BorderRadius.all(Radius.circular(ctx.radiusOf(AppShape.card))),
      );
    });

    testWidgets('an instance style beats the resolved default', (tester) async {
      await pump(
        tester,
        const DSImage.provider(
          _Pending(),
          aspectRatio: 1,
          decorative: true,
          style: DSImageStyle(radius: BorderRadius.zero),
        ),
      );

      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(DSImage),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.zero);
    });
  });
}

/// A fetch that never completes.
class _Pending extends ImageProvider<_Pending> {
  const _Pending();

  @override
  Future<_Pending> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_Pending>(this);

  @override
  ImageStreamCompleter loadImage(_Pending key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: Completer<ui.Codec>().future,
        scale: 1,
      );

  @override
  bool operator ==(Object other) => other is _Pending;

  @override
  int get hashCode => (_Pending).hashCode;
}

/// A fetch that fails — a 404, an expired signature, an offline device.
class _Broken extends ImageProvider<_Broken> {
  const _Broken();

  @override
  Future<_Broken> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_Broken>(this);

  @override
  ImageStreamCompleter loadImage(_Broken key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: Future<ui.Codec>.error(Exception('404')),
        scale: 1,
      );

  @override
  bool operator ==(Object other) => other is _Broken;

  @override
  int get hashCode => (_Broken).hashCode;
}

/// Already in the cache: the frame is there on the first build.
class _Cached extends ImageProvider<_Cached> {
  const _Cached(this.image);

  final ui.Image image;

  @override
  Future<_Cached> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_Cached>(this);

  @override
  ImageStreamCompleter loadImage(_Cached key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone())),
      );

  @override
  bool operator ==(Object other) => other is _Cached && other.image == image;

  @override
  int get hashCode => image.hashCode;
}

/// Not in the cache: the frame lands a microtask later, which is the path the
/// fade exists for.
class _Late extends ImageProvider<_Late> {
  const _Late(this.image);

  final ui.Image image;

  @override
  Future<_Late> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_Late>(this);

  @override
  ImageStreamCompleter loadImage(_Late key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        Future<ImageInfo>.microtask(() => ImageInfo(image: image.clone())),
      );

  @override
  bool operator ==(Object other) => other is _Late && other.image == image;

  @override
  int get hashCode => image.hashCode;
}
