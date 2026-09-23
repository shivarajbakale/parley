@Tags(<String>['probe'])
library;

import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_choice_label.dart';
import 'package:parley_android/theme/app_materials.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The probe: a set of *absolute* assertions applied to every surface.
///
/// The four gates this scaffolder already had are all relative to something.
/// `analyze` reads types, `ui_lint` reads source text, a test checks what
/// somebody thought to assert, and a golden only fails when a picture
/// *changes* — so a layout that was wrong the day its baseline was recorded is
/// recorded as correct forever. Every defect in `docs/principles/premium.md`
/// shipped with all four green.
///
/// What is absolute is a measurement taken from a real render tree: a row that
/// overflows, a control smaller than the tap floor, a page whose subject is
/// below the fold. None of those needs a previous run to compare against, so
/// each can fail on a surface no human has ever opened.

/// One cell of the matrix a surface is measured in.
@immutable
class ProbeCell {
  const ProbeCell({
    required this.width,
    required this.textScale,
    required this.brightness,
    required this.platform,
  });

  /// 320 is the smallest phone still shipping, 390 the median, 430 the
  /// largest. Width rather than size, because height is what scrolls.
  final double width;

  /// 1.0, 1.3 and 2.0. WCAG 1.4.4 asks for 2.0; 1.3 is where a layout that is
  /// merely tight actually breaks first, and it is the setting real people use.
  final double textScale;

  final Brightness brightness;
  final TargetPlatform platform;

  /// The height every cell is measured at: one median phone screenful. The
  /// `fold` rule is written against it, so it is a constant rather than a
  /// dimension of the matrix — three heights would give three different folds
  /// and no way to say which one a page failed.
  static const double height = 844;

  String get label =>
      '${width.toInt()}pt · text ${textScale}x · '
      '${brightness == Brightness.light ? 'light' : 'dark'} · '
      '${platform == TargetPlatform.iOS ? 'Apple' : 'Material'}';

  @override
  String toString() => label;

  // A value, because the `width-band` rule collects across surfaces and has to
  // key on the cell two of them were measured in.
  @override
  bool operator ==(Object other) =>
      other is ProbeCell &&
      other.width == width &&
      other.textScale == textScale &&
      other.brightness == brightness &&
      other.platform == platform;

  @override
  int get hashCode => Object.hash(width, textScale, brightness, platform);
}

/// The cells that vary the things layout depends on.
///
/// Brightness is fixed here because a `RenderFlex` does not know what colour it
/// is: running the layout rules in both themes would double the run to
/// re-measure identical geometry. Platform is *not* fixed, because the
/// adaptive spec resolves different radii, insets and chrome per platform, and
/// that is geometry.
final List<ProbeCell> layoutMatrix = <ProbeCell>[
  for (final double width in <double>[320, 390, 430])
    for (final double scale in <double>[1.0, 1.3, 2.0])
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.iOS,
        TargetPlatform.android,
      ])
        ProbeCell(
          width: width,
          textScale: scale,
          brightness: Brightness.light,
          platform: platform,
        ),
];

/// The cells that vary what colour things are, for the one rule that reads
/// colour. One width and one text scale: contrast does not reflow.
final List<ProbeCell> appearanceMatrix = <ProbeCell>[
  for (final Brightness brightness in <Brightness>[
    Brightness.light,
    Brightness.dark,
  ])
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.iOS,
      TargetPlatform.android,
    ])
      ProbeCell(
        width: 390,
        textScale: 1.0,
        brightness: brightness,
        platform: platform,
      ),
];

/// One surface the probe walks.
@immutable
class ProbeSurface {
  const ProbeSurface({
    required this.name,
    required this.build,
    this.scope,
    this.subject,
    this.subjectDescription,
  });

  /// `catalog/DSButton/Primary`, `screen/library`. It is printed on every
  /// violation, so it has to say where to look without a lookup table.
  final String name;

  final Widget Function() build;

  /// Wraps the whole app — a `ProviderScope` for the screens that read one.
  final Widget Function(Widget child)? scope;

  /// What this surface exists to show, for the `fold` rule.
  ///
  /// The plan for this gate proposed a `DSSubject` *widget* so the declaration
  /// could not drift from the screen. It is declared here instead, on the entry
  /// that builds the surface, for two reasons: a marker widget that renders
  /// nothing would still have to earn selection guidance and a gallery story
  /// like every other member of the kit, and the declaration cannot drift from
  /// a screen it is constructed alongside — if the finder stops matching, the
  /// rule fails rather than silently passing.
  final Finder? subject;

  /// How the subject reads in a failure — 'the component under the header'.
  final String? subjectDescription;
}

/// The five rules that grade a kit built before anything measured it.
///
/// They are not softer than the other rules and they are not advisory: they
/// run on every surface, print everything they find, and fail the moment a
/// count moves in either direction. What is different is that their starting
/// count is not zero, and `test/probe/debt.dart` is where it is written down.
const Set<String> gradedAgainstDebt = <String>{
  'target',
  'contrast',
  'clipped-text',
  'overlap',
  'dead-band',
};

/// One thing a rule found, said the way a person can act on it.
@immutable
class ProbeViolation {
  const ProbeViolation({
    required this.rule,
    required this.surface,
    required this.cell,
    required this.detail,
    required this.key,
  });

  final String rule;
  final String surface;
  final ProbeCell cell;

  /// The offending *thing*, without the measurement — the control's label, the
  /// first words of the text. One thing found in eighteen cells of the matrix
  /// is one finding, and this is what says so.
  final String key;

  /// The measurement, always — never just the name of the rule. "overflowed"
  /// sends somebody looking; "overflowed by 31.0pt on the right" is the bug.
  final String detail;

  @override
  String toString() => '[$rule] $surface\n    ${cell.label}\n    $detail';
}

/// Mounts [surface] in [cell] and settles it.
///
/// Fixed pumps rather than `pumpAndSettle`: the kit's skeletons and progress
/// indicators animate forever by design and settling on them never returns.
/// Six of them, because the staggered entrance schedules each row from a
/// post-frame callback and a single jump leaves every delayed row at opacity
/// zero — which measures as a page with its content missing.
Future<void> mountProbe(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(cell.width, ProbeCell.height);
  addTearDown(tester.view.reset);

  final ThemeData theme =
      (cell.brightness == Brightness.light
              ? AppTheme.lightTheme
              : AppTheme.darkTheme)
          .copyWith(platform: cell.platform);

  Widget app = Design(
    spec: AppTheme.spec,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      // Inside the app rather than around it: `MaterialApp` installs its own
      // `MediaQuery` from the test view, and a text scale set outside it is
      // overwritten before a single widget reads it.
      builder: (BuildContext context, Widget? inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(cell.textScale),
          padding: EdgeInsets.zero,
          viewInsets: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
        ),
        child: inner!,
      ),
      home: surface.build(),
    ),
  );
  if (surface.scope != null) app = surface.scope!(app);

  await tester.pumpWidget(app);
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// The global rect of [box], in the coordinates of the surface.
Rect _globalRect(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

bool _isVisible(RenderBox box) =>
    box.hasSize && box.size.width > 0.5 && box.size.height > 0.5;

/// Whether [box] cuts what is drawn inside it.
///
/// A viewport counts: the part of a paragraph that has scrolled past the
/// bottom of a list is not on the screen, however tall the paragraph's own box
/// is. Reading the box alone reported every long paragraph in a scroll view as
/// overlapping the bar underneath the viewport.
bool _clipsChildren(RenderObject box) =>
    box is RenderClipRect ||
    box is RenderClipRRect ||
    box is RenderClipOval ||
    box is RenderClipPath ||
    box is RenderViewportBase;

/// The part of [object] that is actually painted: its box, cut by every clip
/// above it.
Rect _visibleRect(RenderBox object) {
  Rect rect = _globalRect(object);
  RenderObject? node = object.parent;
  while (node != null) {
    if (node is RenderBox && node.hasSize && _clipsChildren(node)) {
      rect = rect.intersect(_globalRect(node));
      if (rect.width <= 0 || rect.height <= 0) return Rect.zero;
    }
    node = node.parent;
  }
  return rect;
}

// ---------------------------------------------------------------------------
// The rules. Each one names a defect that shipped, and each is absolute: it
// can fail on a surface nobody has looked at.
// ---------------------------------------------------------------------------

/// `overflow` — any `RenderFlex` overflowed, at any cell of the matrix.
///
/// Shipped as `DSSectionHeader`, 31 points, with the striped bar painted over
/// the end of a four-word title. It is read from the exception the framework
/// already reports during paint rather than from the render tree, because the
/// overflow amount is private to `RenderFlex` and the message carries it.
///
/// Anything else that was thrown is rethrown rather than reported: a probe
/// that quietly turns an unrelated crash into a layout violation is a probe
/// that hides the crash.
List<ProbeViolation> ruleOverflow(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  final List<ProbeViolation> found = <ProbeViolation>[];

  // Every exception, not the first. One surface can overflow in several
  // places at once, and an undrained queue is reported by the framework at
  // the end of the test as "multiple exceptions ... at least one was
  // unexpected" — which loses the measurements this rule exists to report.
  for (
    Object? thrown = tester.takeException();
    thrown != null;
    thrown = tester.takeException()
  ) {
    final String message = thrown.toString();
    if (!message.contains('overflowed by')) throw thrown;

    final RegExpMatch? measured = RegExp(
      r'overflowed by ([\d.]+) pixels on the (\w+)',
    ).firstMatch(message);

    found.add(
      ProbeViolation(
        rule: 'overflow',
        surface: surface.name,
        cell: cell,
        key: 'overflow',
        detail: measured == null
            ? message.split('\n').first
            : 'a row or column overflowed by ${measured.group(1)}pt '
                  'on the ${measured.group(2)}',
      ),
    );
  }

  return found;
}

/// Whether [object] is a glyph from an icon font rather than words.
bool _isIcon(RenderParagraph object) =>
    object.text.style?.fontFamily?.contains('MaterialIcons') ?? false;

/// `gutter` — a screen's words start left of the page gutter.
///
/// Shipped on the demo blog: its section headers and its intro paragraph read
/// `space.pageGutter`, and its rows did not, because the row component's own
/// doc comment said the gutter belonged to `DSPage`, `DSFormPage` or
/// `DSGutter` — three widgets the kit had not written. Two of the three ship
/// now, and `ui_lint`'s `screen-gutter` rule is what keeps a screen from
/// spelling the token again; this rule stays because it measures the result
/// rather than the source. The thumbnails sat flush against the edge of the
/// screen with the headers 16 points in, on a page where every other list in
/// the app lines up.
///
/// Screens only. A catalog story draws its own stage at a fixed size and a
/// component sheet is a picture of a component, not of a page; the gutter is
/// a fact about a *page*.
///
/// Text only, and left edge only. A picture may bleed — a hero, a banner, a
/// map are all correct at zero — and a row's press fill *should* reach the
/// edge. What may not start outside the gutter is the reading edge.
List<ProbeViolation> ruleGutter(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  if (!surface.name.startsWith('screen/')) return const <ProbeViolation>[];

  final double gutter = AppTheme.spec.space.pageGutter;
  final List<ProbeViolation> found = <ProbeViolation>[];
  final Set<String> reported = <String>{};
  final Set<RenderObject> seen = Set<RenderObject>.identity();

  for (final RenderObject object in tester.allRenderObjects) {
    if (object is! RenderParagraph) continue;
    if (!seen.add(object)) continue;
    if (!_isVisible(object)) continue;
    if (_isIcon(object)) continue;
    if (_hiddenByOpacity(object)) continue;

    final Rect rect = _visibleRect(object);
    if (rect.width <= 0.5 || rect.height <= 0.5) continue;
    // Off the top or bottom of the screen: not this screenful's problem.
    if (rect.bottom <= 0 || rect.top >= ProbeCell.height) continue;
    if (rect.left >= gutter - 0.5) continue;

    final String text = object.text.toPlainText().trim();
    if (text.isEmpty) continue;
    final String key = text.length > 30 ? '${text.substring(0, 30)}…' : text;
    if (!reported.add(key)) continue;

    found.add(
      ProbeViolation(
        rule: 'gutter',
        surface: surface.name,
        cell: cell,
        key: key,
        detail:
            '"$key" starts at ${rect.left.toStringAsFixed(0)}pt, inside the '
            '${gutter.toStringAsFixed(0)}pt page gutter every other run of '
            'text on the page is aligned to',
      ),
    );
  }

  return found;
}

/// The kit's *bands*: the components that read as a row of the page.
///
/// A band draws an edge. The reader sees where it starts and where it stops,
/// and a band that stops short of the page gutter with nothing beside it reads
/// as a mistake even when the layout that produced it was deliberate.
///
/// Text is not on the list: a paragraph may end wherever its last word ends,
/// and a caption is often centred on purpose. Neither is a button — this kit
/// sizes one to its label, so a lone "Skip" in a corner is the design rather
/// than a defect. What is on the list is every component that in this kit is
/// laid out to the width it is given: cards, rows, fields, bars.
const Set<String> bandComponents = <String>{
  'DSCard',
  'DSCheckboxTile',
  'DSControlTile',
  'DSExpansion',
  'DSFieldGroup',
  'DSListTile',
  'DSMediaRow',
  'DSMessage',
  'DSPinnedActionBar',
  'DSPullQuote',
  'DSRadioTile',
  'DSSearchBar',
  'DSSegmentedButton',
  'DSSelect',
  'DSSettingsRow',
  'DSSettingsSection',
  'DSSlider',
  'DSStepper',
  'DSSwitchTile',
  'DSTabBar',
  'DSTextField',
};

/// The kit's widgets that arrange rather than draw.
///
/// A band is excused by anything of the kit's standing beside it, and these
/// stand nowhere: a gutter, a page, a scope, a tap target and a focus ring all
/// wrap something else and inherit its rect, so counting them as company would
/// excuse every band from the widget wrapping it.
const Set<String> _invisibleToShortMeasure = <String>{
  'DSFocusRing',
  'DSGutter',
  'DSInkSurface',
  'DSPage',
  'DSPageSection',
  'DSPressable',
  'DSRatioTransition',
  'DSScope',
  'DSSkeleton',
  'DSTapTarget',
};

/// How far a band may fall short of the gutter before it reads as a mistake.
///
/// Not zero. A segmented control insets its track by a couple of points so the
/// selected pill has somewhere to sit, and a focus ring needs room outside the
/// control it rings. Eight points is under half the page gutter — wide enough
/// for a control's own trim, too narrow to hide a band laid out against the
/// wrong width.
const double _shortMeasureSlack = 8;

/// How much of two boxes' heights must overlap before they count as sharing a
/// line. Two controls side by side rarely have identical heights — one wraps to
/// a second line at 1.3 — so this is a majority rather than a match.
const double _sharedLineOverlap = 0.6;

/// `short-measure` — a band stops short of the page and nothing fills the rest.
///
/// The defect this catches is the one a screenshot shows instantly and no
/// other rule could see: a card, a row or a field laid out against a width
/// that is not the page's, leaving a ragged column of content with a strip of
/// background beside it. `gutter` looks at the *left* edge of running text and
/// says nothing about the right; `overflow` fires only when a box is too big;
/// a golden records whatever shape the page had on the day it was taken.
///
/// Three things keep it from firing on layouts that are right. A band inside
/// another band is skipped — a row in a card is measured against the card, and
/// the card is what this rule holds. A band with any of the kit's other
/// drawing widgets beside it is excused by it, which is what makes a composer
/// with a send button pass and a lone short field fail. And the slack above
/// covers a control's own trim.
List<ProbeViolation> ruleShortMeasure(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  if (!surface.name.startsWith('screen/')) return const <ProbeViolation>[];

  final double gutter = AppTheme.spec.space.pageGutter;
  final double pageLeft = gutter;
  final double pageRight = cell.width - gutter;

  final List<(Element, String, Rect)> bands = <(Element, String, Rect)>[];
  final List<Rect> company = <Rect>[];

  for (final Element element in tester.allElements) {
    final String name = element.widget.runtimeType.toString().split('<').first;
    if (!name.startsWith('DS')) continue;
    final RenderObject? object = element.findRenderObject();
    if (object is! RenderBox || !object.attached || !_isVisible(object)) {
      continue;
    }
    final Rect rect = _globalRect(object);

    // Everything of the kit's that draws is company a band may keep. Wider
    // than [bandComponents] on purpose: a chat composer is a field with an
    // icon button beside it, and the button is what makes the field's width
    // right rather than short.
    if (!_invisibleToShortMeasure.contains(name)) company.add(rect);

    if (!bandComponents.contains(name)) continue;
    // Off this screenful: not this screenful's problem.
    if (rect.bottom <= 0 || rect.top >= ProbeCell.height) continue;
    // Wider than the page band. Deliberate in this kit and common: a pinned
    // action bar, a settings section and a list row all paint to the screen's
    // edges and inset their own content. Only falling *short* is the defect.
    if (rect.left < pageLeft - _shortMeasureSlack) continue;
    if (rect.right > pageRight + _shortMeasureSlack) continue;
    bands.add((element, name, rect));
  }

  bool nested(Element candidate) {
    bool found = false;
    candidate.visitAncestorElements((Element ancestor) {
      final String name = ancestor.widget.runtimeType.toString().split('<')[0];
      if (bandComponents.contains(name)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  bool besideIt(Rect rect, {required bool onRight}) {
    for (final Rect other in company) {
      final double overlap =
          math.min(rect.bottom, other.bottom) - math.max(rect.top, other.top);
      final double shorter = math.min(rect.height, other.height);
      if (shorter <= 0 || overlap / shorter < _sharedLineOverlap) continue;
      if (onRight) {
        if (other.left >= rect.right - _shortMeasureSlack &&
            other.right >= pageRight - _shortMeasureSlack) {
          return true;
        }
      } else {
        if (other.right <= rect.left + _shortMeasureSlack &&
            other.left <= pageLeft + _shortMeasureSlack) {
          return true;
        }
      }
    }
    return false;
  }

  final List<ProbeViolation> found = <ProbeViolation>[];
  final Set<String> alreadySaid = <String>{};

  for (final (Element element, String name, Rect rect) in bands) {
    if (nested(element)) continue;
    for (final bool onRight in <bool>[true, false]) {
      final double shortfall = onRight
          ? pageRight - rect.right
          : rect.left - pageLeft;
      if (shortfall <= _shortMeasureSlack) continue;
      // Something else finishes the line: a deliberate pair.
      if (besideIt(rect, onRight: onRight)) continue;

      final String edge = onRight ? 'right' : 'left';
      final String key = '$name.$edge';
      if (!alreadySaid.add(key)) continue;
      final String verdict =
          '${shortfall.toStringAsFixed(0)}pt short on the $edge, with nothing '
          'beside it';
      found.add(
        ProbeViolation(
          rule: 'short-measure',
          surface: surface.name,
          cell: cell,
          key: key,
          detail:
              '$name spans ${rect.left.toStringAsFixed(0)}..'
              '${rect.right.toStringAsFixed(0)}pt inside a page that runs '
              '${pageLeft.toStringAsFixed(0)}..'
              '${pageRight.toStringAsFixed(0)}pt — $verdict',
        ),
      );
    }
  }

  return found;
}

/// The components that inset their own contents by a page gutter.
///
/// A row has to work as the direct child of a scroll view, so it applies the
/// page's reading edge itself. That is right until something above it has done
/// the same, and then the two insets add up.
const Set<String> _selfInsettingRows = <String>{
  'DSControlTile',
  'DSListTile',
  'DSMediaRow',
  'DSSettingsRow',
  'DSSwitchTile',
};

/// The containers a row is allowed to sit inside a gutter of.
///
/// A card is a surface the reader can see. Content inset from its edge reads
/// as the card's padding, not as a row that missed the page — which is the
/// whole difference between this rule firing and staying quiet.
const Set<String> _visibleContainers = <String>{
  'DSCard',
  'DSMediaTile',
  'DSOverlaySurface',
  'DSSettingsSection',
};

/// `double-gutter` — a row applied the page gutter that its container already
/// applied.
///
/// The defect two screenshots of the shipped app show: on the settings page
/// the section's label sat at 20pt and its rows' icons at 40pt; on the
/// generator every switch stopped 20pt short of the card above it. Both rows
/// were the full width of the page — it is their *contents* that were inset
/// twice — so `short-measure` cannot see this and neither can `gutter`, which
/// reads the left edge of running text and has no opinion about how far in it
/// should be.
///
/// The test is the gap between a row's own left edge and the leftmost thing
/// drawn inside it. A gutter's worth of it, with no visible container to
/// explain it, is one inset too many.
List<ProbeViolation> ruleDoubleGutter(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  if (!surface.name.startsWith('screen/')) return const <ProbeViolation>[];

  final double gutter = AppTheme.spec.space.pageGutter;
  final List<ProbeViolation> found = <ProbeViolation>[];
  final Set<String> alreadySaid = <String>{};

  for (final Element element in tester.allElements) {
    final String name = element.widget.runtimeType.toString().split('<').first;
    if (!_selfInsettingRows.contains(name)) continue;

    final RenderObject? object = element.findRenderObject();
    if (object is! RenderBox || !object.attached || !_isVisible(object)) {
      continue;
    }
    final Rect rect = _globalRect(object);
    if (rect.bottom <= 0 || rect.top >= ProbeCell.height) continue;
    // Edge to edge: the row *is* the gutter's owner here, which is the
    // arrangement this inset was written for.
    if (rect.left < gutter - 0.5) continue;

    bool excused = false;
    element.visitAncestorElements((Element ancestor) {
      final String outer = ancestor.widget.runtimeType.toString().split('<')[0];
      if (_selfInsettingRows.contains(outer) ||
          _visibleContainers.contains(outer)) {
        excused = true;
        return false;
      }
      return true;
    });
    if (excused) continue;

    // The leftmost thing actually drawn inside the row.
    double? contentLeft;
    void walk(RenderObject child) {
      if (child is RenderBox &&
          child.attached &&
          _isVisible(child) &&
          (child is RenderParagraph || child is RenderDecoratedBox)) {
        final Rect inner = _globalRect(child);
        if (inner.width > 0.5 && inner.height > 0.5) {
          contentLeft = contentLeft == null
              ? inner.left
              : math.min(contentLeft!, inner.left);
        }
      }
      child.visitChildren(walk);
    }

    object.visitChildren(walk);
    final double? left = contentLeft;
    if (left == null) continue;

    final double inset = left - rect.left;
    if (inset < gutter - 0.5) continue;
    if (!alreadySaid.add(name)) continue;

    found.add(
      ProbeViolation(
        rule: 'double-gutter',
        surface: surface.name,
        cell: cell,
        key: name,
        detail:
            '$name starts at ${rect.left.toStringAsFixed(0)}pt and draws its '
            'first content at ${left.toStringAsFixed(0)}pt — a second '
            '${gutter.toStringAsFixed(0)}pt gutter inside a row that is '
            'already in one, with no surface to explain it',
      ),
    );
  }

  return found;
}

/// `clipped-text` — content the reader needs was cut with an ellipsis.
///
/// Shipped on the demo blog: every row's headline was set in a component whose
/// default is one line, so "Designing for motion: how we ma…" is what the list
/// offered, and the article's own title was cut in its app bar. Nothing failed,
/// because an ellipsis is what a layout does when it fits — and the checklist
/// every skill carries listed "long strings use ellipsis" as the *pass*
/// condition.
///
/// The distinction the rule draws is between a **label** and **content**. A
/// label names a control and may be cut: it is recoverable from where it sits,
/// and its column is fixed. Content is the thing the reader came for, and a cut
/// headline is a row that cannot be used. Type size is what separates them
/// here — `baseSize` and up is a title or a body role, below it is a label or a
/// caption — because the roles are grown from that number and the render tree
/// carries the size rather than the name.
///
/// Graded at the text scales a layout is expected to *fit*. At 2.0 every
/// bounded box ellipses, and a rule applied there would only ever say "the
/// text is big" — the same reason `fold` stops at 1.3.
List<ProbeViolation> ruleClippedText(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  if (cell.textScale > 1.3) return const <ProbeViolation>[];

  final List<ProbeViolation> found = <ProbeViolation>[];
  final Set<String> reported = <String>{};
  final double contentFloor = AppTheme.spec.type.baseSize;

  for (final RenderObject object in tester.allRenderObjects) {
    if (object is! RenderParagraph) continue;
    if (!_isVisible(object)) continue;
    if (_isIcon(object)) continue;
    if (_hiddenByOpacity(object)) continue;
    if (!object.didExceedMaxLines) continue;
    // The rule's own message draws this line — "a label may be truncated; the
    // words the reader came for may not" — and then the rule could not see it,
    // because it decides by font size and this kit sets a tab's label at the
    // same 16 points as body copy. `AppChoiceLabel` is the kit saying which
    // strings are the choices in a set rather than the content: a segmented
    // control that grew to fit its longest label would stop being a segmented
    // control.
    if (_insideChoiceLabel(object)) continue;

    final double size = object.text.style?.fontSize ?? contentFloor;
    if (size < contentFloor) continue;

    final String text = object.text.toPlainText();
    final String key = text.length > 40 ? '${text.substring(0, 40)}…' : text;
    if (!reported.add(key)) continue;

    found.add(
      ProbeViolation(
        rule: 'clipped-text',
        surface: surface.name,
        cell: cell,
        key: key,
        detail:
            '"$key" is ${size.toStringAsFixed(0)}pt content and it is cut '
            'with an ellipsis at ${object.size.width.toStringAsFixed(0)}pt '
            'wide. A label may be truncated; the words the reader came for '
            'may not — give the box the lines, not the ellipsis',
      ),
    );
  }

  return found;
}

/// `word-break` — a box is narrower than a single word of what is in it.
///
/// Shipped on the demo blog's list thumbnails: a 72-point swatch holding the
/// word "Tokens" at a headline size, so the row read "Token / s" and the
/// article below it "Motio / n". Nothing overflowed and nothing was clipped —
/// the paragraph simply wrapped somewhere no writer put a break.
///
/// Absolute, and cheap: the minimum intrinsic width of a paragraph is the width
/// of its widest word, so a paragraph laid out narrower than that has had a
/// word broken.
List<ProbeViolation> ruleWordBreak(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  if (cell.textScale > 1.3) return const <ProbeViolation>[];

  final List<ProbeViolation> found = <ProbeViolation>[];
  final Set<String> reported = <String>{};

  for (final RenderObject object in tester.allRenderObjects) {
    if (object is! RenderParagraph) continue;
    if (!_isVisible(object)) continue;
    if (_isIcon(object)) continue;
    if (_hiddenByOpacity(object)) continue;
    if (object.softWrap == false) continue;
    // Only paragraphs free to wrap. `TextPainter.minIntrinsicWidth` on a
    // paragraph with a line cap is not the width of its widest word — it is
    // the width at which the string fits in that many lines — so a capped
    // paragraph reports half its own sentence as a "word" and every
    // ellipsised label reads as a break. A capped line that does not fit is
    // `clipped-text`'s finding; this rule is about a box narrower than a word
    // of what it holds.
    if (object.maxLines != null) continue;
    // An ellipsis makes a paragraph single-line whatever its width, so its
    // minimum intrinsic width is the whole string. That paragraph is cut, not
    // broken, and `clipped-text` is the rule that says so.
    if (object.overflow == TextOverflow.ellipsis) continue;

    final double widestWord = object.getMinIntrinsicWidth(double.infinity);
    if (widestWord <= object.size.width + 0.5) continue;

    final String text = object.text.toPlainText();
    final String key = text.length > 40 ? '${text.substring(0, 40)}…' : text;
    if (!reported.add(key)) continue;

    found.add(
      ProbeViolation(
        rule: 'word-break',
        surface: surface.name,
        cell: cell,
        key: key,
        detail:
            '"$key" is laid out at ${object.size.width.toStringAsFixed(0)}pt '
            'and its longest word needs '
            '${widestWord.toStringAsFixed(0)}pt, so the word is broken across '
            'lines. Fit the words to the box or the box to the words',
      ),
    );
  }

  return found;
}

/// `overlap` — two runs of text are painted over one another.
///
/// Shipped on the demo article: an eyebrow and a two-line title in a bar whose
/// height was a constant, so the block grew upward into the toolbar and the
/// back chevron was drawn through the word ENGINEERING. No flex overflowed, so
/// the framework said nothing and the golden recorded it.
///
/// Icons count, because half of these are a glyph over a word. Boxes that
/// merely touch do not: the threshold is an overlap of more than two points on
/// both axes, which no kerning or rounding produces.
List<ProbeViolation> ruleOverlap(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  final List<(Rect, String, bool)> painted = <(Rect, String, bool)>[];

  // `allRenderObjects` yields an object once per render view it is reachable
  // through, so every paragraph arrives twice — and a paragraph compared with
  // itself overlaps itself completely. Identity, not text: two rows may
  // legitimately hold the same words.
  final Set<RenderObject> seen = Set<RenderObject>.identity();

  for (final RenderObject object in tester.allRenderObjects) {
    if (object is! RenderParagraph) continue;
    if (!seen.add(object)) continue;
    if (!_isVisible(object)) continue;
    if (_hiddenByOpacity(object)) continue;

    // The painted part, not the box: a paragraph in a scroll view has a box
    // that continues past the bottom of the viewport, and the bar drawn under
    // that viewport is not overlapping anything a reader can see.
    final Rect rect = _visibleRect(
      object,
    ).intersect(Rect.fromLTWH(0, 0, cell.width, ProbeCell.height));
    if (rect.width <= 0.5 || rect.height <= 0.5) continue;

    final String text = _isIcon(object) ? 'an icon' : object.text.toPlainText();
    if (text.trim().isEmpty) continue;
    painted.add((rect, text, _insideChrome(object)));
  }

  const double tolerance = 2.0;
  final List<ProbeViolation> found = <ProbeViolation>[];
  final Set<String> reported = <String>{};

  for (int i = 0; i < painted.length; i++) {
    for (int j = i + 1; j < painted.length; j++) {
      final Rect overlap = painted[i].$1.intersect(painted[j].$1);
      if (overlap.width <= tolerance || overlap.height <= tolerance) continue;
      // One of the two is on a chrome surface and the other is not, which
      // means the other is *behind* it — under an opaque tint on Android,
      // under a blur on Apple, and unreadable either way. That is a bar doing
      // its job, not two runs of text drawn through each other. A pinned bar
      // over a scrolling page is the kit's stated design, and a rule that
      // called it a defect could only ever be satisfied by deleting the
      // design. Two labels *on* the same surface still fail, which is the
      // event this rule was written for.
      if (painted[i].$3 != painted[j].$3) continue;

      String short(String text) =>
          text.length > 24 ? '${text.substring(0, 24)}…' : text;
      final String key = '${short(painted[i].$2)} / ${short(painted[j].$2)}';
      if (!reported.add(key)) continue;

      found.add(
        ProbeViolation(
          rule: 'overlap',
          surface: surface.name,
          cell: cell,
          key: key,
          detail:
              '$key are painted over each other — '
              '${overlap.width.toStringAsFixed(0)}×'
              '${overlap.height.toStringAsFixed(0)}pt of one is drawn through '
              'the other',
        ),
      );
    }
  }

  return found;
}

/// Whether [object] is the label of one choice in a mutually exclusive set.
///
/// Reads [RenderAppChoiceLabel], which `DSTab` and `DSSegment` install.
bool _insideChoiceLabel(RenderObject object) {
  RenderObject? node = object.parent;
  while (node != null) {
    if (node is RenderAppChoiceLabel) return true;
    node = node.parent;
  }
  return false;
}

/// Whether [object] is painted on a chrome surface — a bar, a sheet, a menu.
///
/// Reads [RenderAppChromeOcclusion], which `AppChromeSurface` installs. The
/// kit states the fact; this does not infer it from paint order or from
/// whether some decoration happens to be opaque.
bool _insideChrome(RenderObject object) {
  RenderObject? node = object.parent;
  while (node != null) {
    if (node is RenderAppChromeOcclusion) return true;
    node = node.parent;
  }
  return false;
}

/// `empty-padding` — a padded slot with nothing in it.
///
/// Shipped on the demo article's hero: a card whose whole content was its
/// media, handed an empty box for its child, so 48 points of card surface were
/// painted under the picture. It reads as a rendering fault, and every gate
/// passed it — the card was drawn exactly as the card was asked to draw.
///
/// Only vertical padding, and only where the child has genuinely collapsed: a
/// zero-height child under padding is a band of surface, and a band of surface
/// is either a spacer nobody named or a slot nobody filled.
List<ProbeViolation> ruleEmptyPadding(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  final List<ProbeViolation> found = <ProbeViolation>[];
  final Set<String> reported = <String>{};
  final Set<RenderObject> seen = Set<RenderObject>.identity();

  for (final RenderObject object in tester.allRenderObjects) {
    if (object is! RenderPadding) continue;
    if (!seen.add(object)) continue;
    if (!object.hasSize || object.size.height < 0.5) continue;
    if (_hiddenByOpacity(object)) continue;

    final RenderBox? child = object.child;
    if (child == null || !child.hasSize) continue;
    if (child.size.height >= 0.5) continue;

    final EdgeInsets padding = object.padding.resolve(TextDirection.ltr);
    final double band = padding.top + padding.bottom;
    if (band < 4) continue;

    final Rect rect = _globalRect(object);
    if (rect.bottom <= 0 || rect.top >= ProbeCell.height) continue;

    final String key = 'padding at ${rect.top.toStringAsFixed(0)}pt';
    if (!reported.add(key)) continue;

    found.add(
      ProbeViolation(
        rule: 'empty-padding',
        surface: surface.name,
        cell: cell,
        key: key,
        detail:
            '${band.toStringAsFixed(0)}pt of padding is drawn around a child '
            'with no height, at ${rect.top.toStringAsFixed(0)}pt down the '
            'surface — a band of surface where a slot was left empty',
      ),
    );
  }

  return found;
}

/// `baseline` — the children of one row do not share a line.
///
/// Shipped as `DSSegmentedProgress.labelled`: a tappable step got a 48-point
/// cell and an upcoming one a 24-point cell, so three labels sat 24 points
/// below the other two and the connectors ran through empty space above the
/// nodes they joined.
///
/// A row is aligned if its children share a centre, a top or a bottom — those
/// are the three lines `CrossAxisAlignment` can produce. Scattered is the
/// failure. Rows that ask for `baseline` alignment are skipped: the framework
/// has already aligned them on a line this function cannot measure from
/// outside layout.
List<ProbeViolation> ruleBaseline(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  const double tolerance = 2.0;
  final List<ProbeViolation> found = <ProbeViolation>[];

  for (final RenderObject object in tester.allRenderObjects) {
    if (object is! RenderFlex) continue;
    if (object.direction != Axis.horizontal) continue;
    if (object.crossAxisAlignment == CrossAxisAlignment.baseline) continue;
    if (object.crossAxisAlignment == CrossAxisAlignment.stretch) continue;
    if (!object.hasSize) continue;

    // Checked before the boxes and independently of them: a row whose
    // children are boxes of different heights aligned to a common edge passes
    // the box check by construction, and that is the shape the shipped defect
    // took.
    final ProbeViolation? scattered = _scatteredPeerText(
      object,
      surface,
      cell,
      tolerance,
    );
    if (scattered != null) found.add(scattered);

    final List<Rect> rects = <Rect>[
      for (final RenderBox child in object.getChildrenAsList())
        if (_isVisible(child)) _globalRect(child),
    ];
    if (rects.length < 2) continue;

    // A child as tall as the row cannot be misaligned against anything — it
    // is the row. Measuring it as a sibling makes every row with one filling
    // child look scattered.
    final double rowHeight = object.size.height;
    final List<Rect> siblings = <Rect>[
      for (final Rect rect in rects)
        if (rect.height < rowHeight - tolerance) rect,
    ];
    if (siblings.length < 2) continue;

    bool shares(double Function(Rect) line) {
      final Iterable<double> values = siblings.map(line);
      return values.reduce((a, b) => a > b ? a : b) -
              values.reduce((a, b) => a < b ? a : b) <=
          tolerance;
    }

    if (shares((Rect r) => r.center.dy) ||
        shares((Rect r) => r.top) ||
        shares((Rect r) => r.bottom)) {
      continue;
    }

    final Iterable<double> centres = siblings.map((Rect r) => r.center.dy);
    final double spread =
        centres.reduce((a, b) => a > b ? a : b) -
        centres.reduce((a, b) => a < b ? a : b);
    found.add(
      ProbeViolation(
        rule: 'baseline',
        surface: surface.name,
        cell: cell,
        key: 'row of ${siblings.length}',
        detail:
            '${siblings.length} children of one row share no centre, top or '
            'bottom line — their centres are spread over '
            '${spread.toStringAsFixed(1)}pt',
      ),
    );
  }

  return found;
}

/// Peers of one row, whose text sits on different lines.
///
/// The box check above passes a row whose children are boxes of different
/// heights aligned to a common edge — which is exactly the shape defect 1
/// took: a tappable step got a 48-point cell and an upcoming one a 24-point
/// cell, their tops lined up, and the labels inside them did not.
///
/// Only text of one size is compared. Two strings at one size in one row are
/// peers and belong on a line; a title beside a caption is a hierarchy, and
/// requiring those to line up would fail every list tile in the kit.
ProbeViolation? _scatteredPeerText(
  RenderFlex row,
  ProbeSurface surface,
  ProbeCell cell,
  double tolerance,
) {
  final List<Rect> rects = <Rect>[];
  double? size;

  for (final RenderBox child in row.getChildrenAsList()) {
    if (!_isVisible(child)) continue;
    final RenderParagraph? paragraph = _lastParagraph(child);
    if (paragraph == null || !_isVisible(paragraph)) return null;

    final double fontSize = paragraph.text.style?.fontSize ?? 16;
    if (size == null) {
      size = fontSize;
    } else if ((size - fontSize).abs() > 0.1) {
      return null;
    }
    rects.add(_globalRect(paragraph));
  }
  if (rects.length < 2) return null;

  // One line each, or nothing to say. A label that has wrapped to two lines
  // where its neighbours have not is a wrapping story: the column that holds
  // it grew, and the platform re-centred it. That is a different complaint
  // from two labels of one size on one line sitting at two heights, and
  // grading it here would fail every nav bar at a raised text scale.
  final Iterable<double> heights = rects.map((Rect r) => r.height);
  if (heights.reduce((a, b) => a > b ? a : b) -
          heights.reduce((a, b) => a < b ? a : b) >
      tolerance) {
    return null;
  }

  bool shares(double Function(Rect) line) {
    final Iterable<double> values = rects.map(line);
    return values.reduce((a, b) => a > b ? a : b) -
            values.reduce((a, b) => a < b ? a : b) <=
        tolerance;
  }

  if (shares((Rect r) => r.top) || shares((Rect r) => r.center.dy)) return null;

  final Iterable<double> tops = rects.map((Rect r) => r.top);
  final double spread =
      tops.reduce((a, b) => a > b ? a : b) -
      tops.reduce((a, b) => a < b ? a : b);
  return ProbeViolation(
    rule: 'baseline',
    surface: surface.name,
    cell: cell,
    key: 'peer text of ${rects.length}',
    detail:
        '${rects.length} labels of one size in one row sit on different '
        'lines — ${spread.toStringAsFixed(1)}pt apart. Their boxes line up; '
        'what is inside them does not',
  );
}

/// The last word painted anywhere under [box], in paint order.
///
/// Two choices in one line, and both were paid for.
///
/// **Icons are skipped**, because an icon is a glyph from an icon font and so
/// arrives as a paragraph like any other. The first paragraph under a nav
/// destination is its icon, and comparing those compares the glyph row —
/// which the platform aligns, and which shifts when a label underneath it
/// wraps. Every nav bar failed for a reason that had nothing to do with this
/// rule.
///
/// **The last rather than the first**, because a cell puts its label under
/// whatever the cell is about. On the labelled step meter, the finished steps
/// draw a tick and the upcoming ones draw their number, so the *first* word in
/// a cell was the label in some cells and the step number in others — five
/// strings of one size, twenty-nine points apart, and none of it a defect. The
/// label is the last thing in every one of those cells.
RenderParagraph? _lastParagraph(RenderObject box) {
  if (box is RenderParagraph) {
    final String? family = box.text.style?.fontFamily;
    if (family != null && family.contains('MaterialIcons')) return null;
    return box;
  }
  RenderParagraph? found;
  box.visitChildren((RenderObject child) {
    found = _lastParagraph(child) ?? found;
  });
  return found;
}

/// `fold` — the surface's subject starts below half of the first screenful.
///
/// Shipped as the component page: 348 of its first 844 points went to an app
/// bar, an eyebrow, a summary and a note identical on all fifty pages, and the
/// component the page exists to show started under all of it.
List<ProbeViolation> ruleFold(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  final Finder? subject = surface.subject;
  if (subject == null) return const <ProbeViolation>[];

  // Measured at the text scales a layout is expected to *fit*, not at 2.0.
  // Doubling the type doubles the chrome along with everything else, and
  // every platform's own contract at that setting is that content scrolls
  // more. A fold rule applied there would only ever say "the text is big".
  if (cell.textScale > 1.3) return const <ProbeViolation>[];

  final Iterable<Element> matches = subject.evaluate();
  if (matches.isEmpty) {
    return <ProbeViolation>[
      ProbeViolation(
        rule: 'fold',
        surface: surface.name,
        cell: cell,
        key: 'subject',
        detail:
            'the declared subject (${surface.subjectDescription ?? subject}) '
            'is not on the surface at all',
      ),
    ];
  }

  final double top = _globalRect(matches.first.renderObject! as RenderBox).top;
  const double fold = ProbeCell.height / 2;
  if (top <= fold) return const <ProbeViolation>[];

  return <ProbeViolation>[
    ProbeViolation(
      rule: 'fold',
      surface: surface.name,
      cell: cell,
      key: 'subject',
      detail:
          '${surface.subjectDescription ?? 'the subject'} starts at '
          '${top.toStringAsFixed(0)}pt of ${ProbeCell.height.toInt()} — '
          'below the halfway line at ${fold.toInt()}pt',
    ),
  ];
}

/// `dead-band` — a screen whose pinned action bar floats over a void.
///
/// A pinned bar is the archetype's answer to a primary action that must not
/// scroll. It is not an answer to *what is above it*: when the content ends
/// far short of the bar, the screen is a form at the top, a button at the
/// bottom, and a quarter of a phone of nothing in between.
///
/// Shipped as the booking form. Every field reserved a helper line it could
/// never fill, and under the last of them 247 points — 29% of a 390x844
/// phone — were white. Every other rule passed it: nothing here had ever
/// asked whether a screen was *empty*, only whether it was broken. What paid
/// it off was `DSTextField.reserveHelper` and a panel saying what else is on
/// the day, which is the question the void was sitting on.
///
/// Only applies to a surface that has nothing more to show: if anything
/// scrolls, the space under the content is the next screenful arriving, not
/// dead space.
List<ProbeViolation> ruleDeadBand(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  // Doubling the type is the reader asking for a longer page, and every
  // platform's contract at that setting is that content scrolls more. A rule
  // about empty space applied there would only ever say "the text is big".
  if (cell.textScale > 1.3) return const <ProbeViolation>[];

  final Iterable<Element> bars = find.byType(DSPinnedActionBar).evaluate();
  if (bars.isEmpty) return const <ProbeViolation>[];

  // Something left to scroll to is not a void.
  for (final ScrollableState state in tester.stateList<ScrollableState>(
    find.byType(Scrollable),
  )) {
    if (state.position.hasContentDimensions &&
        state.position.maxScrollExtent > 0.5) {
      return const <ProbeViolation>[];
    }
  }

  final double barTop = _globalRect(bars.first.renderObject! as RenderBox).top;

  double bottom = 0;
  void walk(RenderObject object) {
    if (object is RenderParagraph && _isVisible(object)) {
      final Rect rect = _globalRect(object);
      if (rect.bottom <= barTop + 0.5) {
        bottom = math.max(bottom, rect.bottom);
      }
    }
    object.visitChildren(walk);
  }

  final RenderObject? root = tester.binding.rootElement?.renderObject;
  if (root == null) return const <ProbeViolation>[];
  walk(root);
  if (bottom == 0) return const <ProbeViolation>[];

  final double band = barTop - bottom;
  if (band <= _deadBandFloor) return const <ProbeViolation>[];

  return <ProbeViolation>[
    ProbeViolation(
      rule: 'dead-band',
      surface: surface.name,
      cell: cell,
      key: 'tail',
      detail:
          'the content ends at ${bottom.toStringAsFixed(0)}pt and the pinned '
          'bar starts at ${barTop.toStringAsFixed(0)}pt — '
          '${band.toStringAsFixed(0)}pt of nothing, with nothing left to '
          'scroll to',
    ),
  ];
}

/// How much room may sit between the last line of content and a pinned bar.
///
/// A gap is not a defect: the bar needs air over it, and a form that ends
/// exactly on the button reads as cramped. A sixth of a median phone is where
/// air becomes a hole.
const double _deadBandFloor = 140;

/// The surfaces of the kit, and which step of the ladder each one is.
///
/// The rule below is written against equality, so what matters is that two
/// things that are the same step carry the same number — a card is a card
/// whether or not it is a media card, and a dialog and a modal are one idiom
/// presented two ways.
const Map<String, int> surfaceElevations = <String, int>{
  'DSCard': 1,
  'DSMediaHero': 1,
  'DSMediaRow': 1,
  'DSMediaTile': 1,
  // `DSOverlaySurface` is deliberately absent: it is what `DSBottomSheet` and
  // `DSDialog` are *made of*, so giving it a step of its own would flag every
  // sheet in the kit for being built out of one surface rather than two.
  'DSBottomSheet': 2,
  'DSDialog': 3,
};

/// `row-air` — a row is taller than the kit's own spec predicts.
///
/// [DSListTile] deliberately passed no `minTileHeight`, on the reasoning that
/// `ListTile`'s own minimum already clears both platforms' tap floor and that
/// handing it `ComponentSpec.minTapTarget` would *lower* every row. That is
/// true of the tap floor and it is the wrong number: the kit already declares
/// what a row is, in `ComponentSpec.listRowMinHeight`, and no widget read it.
/// So the height came from Material's `_defaultTileHeight` — 56 for one line,
/// 72 for two — and the kit's own `contentPadding` was added on top of it.
/// Nine settings rows measured 64pt around a 19pt line, the account row 80,
/// and `SpaceSpec.density` at 0.9 moved a row by eight tenths of a point,
/// because the token scale was never what owned the height.
///
/// Absolute, not graded against [knownDebt]. The number a row should be is
/// not a matter of taste that a ledger has to hold open — it is
/// `listRowMinHeight`, or what the row's own content needs, whichever is
/// larger. Anything above that is height nobody asked for.
List<ProbeViolation> ruleRowAir(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  // The same carve-out `fold` and `dead-band` make, for the same reason and
  // with more force here: above 1.6x [DSListTile] *restructures* — the
  // trailing control drops under the text and the chevron is dropped — so a
  // row at 2.0x is not a taller version of the row this rule grades, it is a
  // different layout. Measuring its air against a one-line floor would only
  // ever report the rearrangement.
  if (cell.textScale > 1.3) return const <ProbeViolation>[];

  final double floor = AppTheme.spec.component.listRowMinHeight;
  final List<ProbeViolation> found = <ProbeViolation>[];
  final Set<String> reported = <String>{};

  final Iterable<Element> rows = find.byType(DSListTile).evaluate();
  int onScreen = 0;
  int measured = 0;

  for (final Element element in rows) {
    final RenderObject? object = element.renderObject;
    if (object is! RenderBox || !_isVisible(object)) continue;

    final Rect rect = _globalRect(object);
    // Off this screenful, or a row the surface has scrolled away: a height
    // that is not on screen is not what the rule is about.
    if (rect.bottom <= 0 || rect.top >= ProbeCell.height) continue;
    onScreen++;

    final double? content = _contentExtent(object, rect);
    if (content == null) continue;
    measured++;

    // What the row is allowed to be: its floor, or its content plus the one
    // padding budget the row owns — `verticalPadding` per side — whichever is
    // larger. Both numbers come from the spec the row itself reads, so this
    // is the kit's own arithmetic rather than a tolerance chosen to make a
    // count go green. A row taller than both is carrying height from
    // somewhere outside the kit, which is exactly what it was carrying.
    final double padding =
        DSListTileStyle.resolve(element, DSTone.neutral).verticalPadding! * 2;
    final double expected = math.max(floor, content + padding);
    if (rect.height <= expected + 1) continue;

    final String key = _rowKey(object);
    if (!reported.add(key)) continue;

    found.add(
      ProbeViolation(
        rule: 'row-air',
        surface: surface.name,
        cell: cell,
        key: key,
        detail:
            'the row "$key" is ${rect.height.toStringAsFixed(0)}pt tall around '
            '${content.toStringAsFixed(0)}pt of content. The spec asks for '
            '${expected.toStringAsFixed(0)} — listRowMinHeight is '
            '${floor.toStringAsFixed(0)} and the content plus the row\'s own '
            'padding is ${(content + padding).toStringAsFixed(0)} — so '
            '${(rect.height - expected).toStringAsFixed(0)}pt of it is height '
            'nothing in the kit asked for',
      ),
    );
  }

  // Anti-vacuity. A rule that measures nothing reports nothing, and a rule
  // that reports nothing reads exactly like a rule that passed. If the surface
  // mounted rows and not one of them yielded a measurement, that is the rule
  // being broken rather than the kit being right.
  if (onScreen > 0 && measured == 0) {
    found.add(
      ProbeViolation(
        rule: 'row-air',
        surface: surface.name,
        cell: cell,
        key: 'vacuous',
        detail:
            'the surface has $onScreen DSListTile(s) on screen and row-air '
            'measured none of them — the rule is not reading the render tree',
      ),
    );
  }

  return found;
}

/// How much of a row's height its content actually claims.
///
/// The union of everything the row draws that is *not* the row itself: its
/// title, its subtitle, a leading glyph, a switch on the trailing edge. A box
/// as tall as the row is the row's own background, ink well or splash, and
/// measuring the content against those would only ever say a row is exactly
/// as tall as it is.
double? _contentExtent(RenderBox row, Rect rowRect) {
  double? top;
  double? bottom;

  void walk(RenderObject object) {
    if (object is RenderBox && _isVisible(object) && !identical(object, row)) {
      final Rect rect = _globalRect(object);
      final bool fillsTheRow = rect.height >= rowRect.height - 0.5;
      final bool leaf = !_hasBoxChild(object);
      if (!fillsTheRow && leaf) {
        top = top == null ? rect.top : math.min(top!, rect.top);
        bottom = bottom == null ? rect.bottom : math.max(bottom!, rect.bottom);
      }
    }
    object.visitChildren(walk);
  }

  walk(row);
  if (top == null || bottom == null) return null;
  return bottom! - top!;
}

bool _hasBoxChild(RenderObject object) {
  bool found = false;
  object.visitChildren((RenderObject child) {
    if (child is RenderBox) found = true;
  });
  return found;
}

/// The row, named by the first thing written on it.
String _rowKey(RenderBox row) {
  String? first;
  void walk(RenderObject object) {
    if (first != null) return;
    if (object is RenderParagraph && !_isIcon(object) && _isVisible(object)) {
      final String text = object.text.toPlainText().trim();
      if (text.isNotEmpty) {
        first = text.length > 30 ? '${text.substring(0, 30)}…' : text;
        return;
      }
    }
    object.visitChildren(walk);
  }

  walk(row);
  return first ?? 'an unlabelled row';
}

/// How much of a control's height its label and glyphs actually claim.
///
/// Not [_contentExtent], which throws away any box as tall as the thing it is
/// measuring — in a row that box is the background or the ink well, but in a
/// button it is very often the label itself. `order_placed` is where that
/// showed: at 2.0x text "Track order" wraps, the paragraph grows to the full
/// height of the pill, the row heuristic discarded it as chrome, and what was
/// left to measure was the 20-point icon beside it. The rule then reported 54
/// points of air on a button that was exactly as tall as its own two lines.
///
/// So this unions the text and the glyphs and nothing else: every visible
/// paragraph however tall, plus any leaf box shorter than the control, which
/// is an icon, a spinner or a badge.
double? _controlContentExtent(RenderBox control) {
  double? top;
  double? bottom;
  final Rect controlRect = _globalRect(control);

  void take(Rect rect) {
    top = top == null ? rect.top : math.min(top!, rect.top);
    bottom = bottom == null ? rect.bottom : math.max(bottom!, rect.bottom);
  }

  void walk(RenderObject object) {
    if (object is RenderBox &&
        _isVisible(object) &&
        !identical(object, control)) {
      final Rect rect = _globalRect(object);
      if (object is RenderParagraph) {
        take(rect);
      } else if (!_hasBoxChild(object) &&
          rect.height < controlRect.height - 0.5) {
        take(rect);
      }
    }
    object.visitChildren(walk);
  }

  walk(control);
  if (top == null || bottom == null) return null;
  return bottom! - top!;
}

/// `control-air` — a button or a floating action button is taller than the
/// token the kit declares for it.
///
/// `row-air` grades one component. This grades the other two the user presses,
/// and it exists because the defect `row-air` found was never about rows: a
/// painted dimension had come from somewhere outside the spec, and every gate
/// stayed green because no gate compared the two.
///
/// The comparison it makes is exact rather than approximate. Each control on
/// screen is asked which size it *is* — `DSButtonStyle.sizeOf` resolves an
/// explicit size or the ambient [DSScope]; a [DSFab] carries its own, and a
/// label is what makes it extended — and the answer names one token in
/// [ComponentSpec]. What the control may then be is that token, the tap floor
/// [DSTapTarget] inflates the box to, or the height the control's own content
/// needs when a label wraps. A control taller than all three is carrying
/// height nothing in the kit asked for.
///
/// The tap floor is in that list deliberately, and it is the whole reason the
/// numbers this rule reads are what they are. `buttonHeight` was 48 — exactly
/// `minTapTarget` — so every button in the app painted the accessibility
/// minimum around a 19-point label, sixty per cent air, while the token's own
/// doc comment said a control may paint shorter than the floor because
/// [DSTapTarget] already holds the gesture area. `sm` did that. `md`, which is
/// nearly every button in the app, did not.
List<ProbeViolation> ruleControlAir(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  final ComponentSpec component = AppTheme.spec.component;
  final double floor = component.minTapTarget;
  final List<ProbeViolation> found = <ProbeViolation>[];
  final Set<String> reported = <String>{};

  int onScreen = 0;
  int measured = 0;

  void grade(Element element, double token, String what, String key) {
    final RenderObject? object = element.renderObject;
    if (object is! RenderBox || !_isVisible(object)) return;

    final Rect rect = _globalRect(object);
    if (rect.bottom <= 0 || rect.top >= ProbeCell.height) return;
    onScreen++;

    final double? content = _controlContentExtent(object);
    if (content == null) return;
    measured++;

    // A wrapped label is the one honest reason a control outgrows its token:
    // the button never ellipsises, because a truncated action label is an
    // unknown action. Height beyond that is not the label's.
    final double expected = math.max(math.max(token, floor), content);
    if (rect.height <= expected + 1) return;
    if (!reported.add(key)) return;

    found.add(
      ProbeViolation(
        rule: 'control-air',
        surface: surface.name,
        cell: cell,
        key: key,
        detail:
            '$what "$key" is ${rect.height.toStringAsFixed(0)}pt tall around '
            '${content.toStringAsFixed(0)}pt of content. The spec asks for '
            '${expected.toStringAsFixed(0)} — its own token is '
            '${token.toStringAsFixed(0)}, the tap floor is '
            '${floor.toStringAsFixed(0)} — so '
            '${(rect.height - expected).toStringAsFixed(0)}pt of it is height '
            'nothing in the kit asked for',
      ),
    );
  }

  for (final Element element in find.byType(DSButton).evaluate()) {
    final DSButton button = element.widget as DSButton;
    final double token = switch (DSButtonStyle.sizeOf(element, button.size)) {
      DSButtonSize.sm => component.buttonHeightSm,
      DSButtonSize.md => component.buttonHeight,
      DSButtonSize.lg => component.buttonHeightLg,
    };
    grade(element, token, 'the button', button.label);
  }

  for (final Element element in find.byType(DSFab).evaluate()) {
    final DSFab fab = element.widget as DSFab;
    // There is one size, so extended and non-extended buttons are graded
    // against the same token.
    grade(
      element,
      component.fabSize,
      'the floating action button',
      fab.label ?? fab.semanticLabel ?? 'unlabelled',
    );
  }

  // Anti-vacuity, for the reason `row-air` carries one: a rule that measured
  // nothing reads exactly like a rule that passed.
  if (onScreen > 0 && measured == 0) {
    found.add(
      ProbeViolation(
        rule: 'control-air',
        surface: surface.name,
        cell: cell,
        key: 'vacuous',
        detail:
            'the surface has $onScreen button(s) on screen and control-air '
            'measured none of them — the rule is not reading the render tree',
      ),
    );
  }

  return found;
}

/// `nesting` — a surface drawn inside a surface of the same elevation.
///
/// Shipped as `showDSCustomModal`, which wrapped its builder in a modal and
/// was handed another modal holding a card: three stacked surfaces, two drag
/// handles, and the content inset twice. That function is gone — plan 18
/// folded it into the sheet and plan 19 into the dialog — and the rule stays,
/// because the shape it catches is not specific to it.
List<ProbeViolation> ruleNesting(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  final List<ProbeViolation> found = <ProbeViolation>[];

  for (final Element element in tester.allElements) {
    final String type = element.widget.runtimeType.toString();
    final int? level = surfaceElevations[type];
    if (level == null) continue;

    String? offender;
    element.visitAncestorElements((Element ancestor) {
      final String ancestorType = ancestor.widget.runtimeType.toString();
      if (surfaceElevations[ancestorType] == level) {
        offender = ancestorType;
        return false;
      }
      return true;
    });
    if (offender == null) continue;

    found.add(
      ProbeViolation(
        rule: 'nesting',
        surface: surface.name,
        cell: cell,
        key: '$type in $offender',
        detail:
            'a $type is drawn inside a $offender — both are elevation step '
            '$level, so the inner one adds an inset and a shadow and no '
            'information',
      ),
    );
  }

  return found;
}

/// The width every instance of one overlay kind resolved to, across the run.
///
/// `width-band` is the one rule that cannot be decided from a single surface:
/// it is about two presentations disagreeing, so it collects here and is
/// asserted once at the end of the walk.
final Map<String, Map<ProbeCell, Set<double>>> overlayWidths =
    <String, Map<ProbeCell, Set<double>>>{};

/// Records the rendered width of every overlay on the current surface.
///
/// Shipped as three widths for one idea: the structured modal capped at 400,
/// the custom one at infinity, and the dialog at the screen minus 48.
void recordOverlayWidths(WidgetTester tester, ProbeCell cell) {
  for (final Element element in tester.allElements) {
    final String type = element.widget.runtimeType.toString();
    if (!surfaceElevations.containsKey(type)) continue;
    if (surfaceElevations[type]! < 2) continue;

    final RenderObject? object = element.renderObject;
    if (object is! RenderBox || !_isVisible(object)) continue;

    overlayWidths
        .putIfAbsent(type, () => <ProbeCell, Set<double>>{})
        .putIfAbsent(cell, () => <double>{})
        .add(double.parse(object.size.width.toStringAsFixed(1)));
  }
}

/// The root of the semantics tree, whichever pipeline owner is holding it.
///
/// Walked rather than read off the binding: the owner tree has a node per
/// view, and the one owner that has semantics is not always the root.
SemanticsNode? rootSemanticsNode(WidgetTester tester) {
  SemanticsNode? found;
  void visit(PipelineOwner owner) {
    found ??= owner.semanticsOwner?.rootSemanticsNode;
    owner.visitChildren(visit);
  }

  visit(tester.binding.rootPipelineOwner);
  return found;
}

/// `width-band` — one kind of overlay resolving to more than one width.
///
/// The only rule that cannot be decided from a single surface: it is about two
/// presentations of one idea disagreeing, so it reads what the walk recorded
/// rather than a tree. Shipped as three widths for one surface — the
/// structured modal capped at 400, the custom one at infinity, and the dialog
/// at the screen minus 48.
List<ProbeViolation> ruleWidthBand() {
  final List<ProbeViolation> found = <ProbeViolation>[];

  overlayWidths.forEach((String type, Map<ProbeCell, Set<double>> byCell) {
    byCell.forEach((ProbeCell cell, Set<double> widths) {
      if (widths.length < 2) return;
      final List<double> sorted = widths.toList()..sort();
      found.add(
        ProbeViolation(
          rule: 'width-band',
          surface: type,
          cell: cell,
          key: type,
          detail:
              'resolves to ${sorted.map((double w) => '${w}pt').join(', ')} — '
              'one idiom measured more than one way is not one idiom',
        ),
      );
    });
  });

  return found;
}

/// `target` — an interactive element's hit box is under the tap floor.
///
/// Read from the semantics tree rather than from widget types, so it covers a
/// control the kit does not own and cannot be defeated by a new one. Anything
/// the framework says can be tapped is measured; a list of types would only
/// ever cover the controls somebody remembered to add to it.
List<ProbeViolation> ruleTarget(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  final SemanticsNode? root = rootSemanticsNode(tester);
  if (root == null) return const <ProbeViolation>[];

  final double floor = AppTheme.spec.component.minTapTarget;
  final List<ProbeViolation> found = <ProbeViolation>[];
  final Set<String> reported = <String>{};

  // The viewports a control can be scrolled half out of, measured from the
  // render tree.
  //
  // A scrolling viewport's clip does not reach the semantics tree in a form
  // this rule can use. On the last tab of a scrollable `DSTabBar`,
  // `parentSemanticsClipRect` is an *ancestor's* — sixty points wider than
  // the strip — while `rect` has already been cut down to the 26 points of
  // the tab that show; on a stepper resting on the bottom edge of a form's
  // scroll view, the same pair says the clip is the whole screen and the
  // control is 46 points tall, while the render tree has it laid out at a
  // full 48. Both read as a small control rather than as a control that is
  // partly scrolled off, which is the fact the rule already says it does not
  // want to report. The viewport's own bounds are in the render tree, so they
  // are read from there.
  final List<(Rect, Axis)> viewports = <(Rect, Axis)>[];
  for (final Element element in tester.allElements) {
    if (element.widget is! Scrollable) continue;
    final ScrollableState state =
        (element as StatefulElement).state as ScrollableState;
    if (!state.position.hasContentDimensions) continue;
    if (state.position.maxScrollExtent <= 0.5) continue;
    final RenderObject? box = element.findRenderObject();
    if (box is! RenderBox || !box.hasSize) continue;
    viewports.add((
      box.localToGlobal(Offset.zero) & box.size,
      state.position.axis,
    ));
  }

  void walk(SemanticsNode node, Matrix4 inherited, Rect clipAbove) {
    final Matrix4 transform = node.transform == null
        ? inherited
        : (inherited.clone()..multiply(node.transform!));
    final SemanticsData data = node.getSemanticsData();

    // The clip in force for this node, in screen coordinates, and the one its
    // children inherit. Carried down rather than read per node: a control is
    // just as cut off by a clip three ancestors up as by its own parent's,
    // and only the nearest one is on the node itself.
    //
    // `parentSemanticsClipRect` is expressed in the coordinate system of the
    // node that carries it, which is the same space `rect` is in — so it is
    // the node's own transform that puts it on the screen, not its parent's.
    final Rect? ownClip = node.parentSemanticsClipRect;
    final Rect clip = ownClip == null
        ? clipAbove
        : clipAbove.intersect(MatrixUtils.transformRect(transform, ownClip));

    final bool tappable = data.hasAction(SemanticsAction.tap);
    final bool hidden = data.flagsCollection.isHidden;
    // A text field is not measured, because its node is not its target. The
    // field's semantics merge into the editable text's, so `rect` is the run
    // of text — 25 points of it — while the box a finger has to hit is the
    // decoration drawn around it, which the semantics tree does not describe
    // at all. Grading the node measured the text and reported the field.
    final bool field = data.flagsCollection.isTextField;
    if (tappable && !hidden && !field) {
      final Rect rect = MatrixUtils.transformRect(transform, node.rect);
      // Only controls nothing is cutting off. A semantics rect is the
      // control's box intersected with every clip above it, so a button half
      // under the fold measures as a short button and a chip half out of a
      // scrolling strip measures as an 11-point one — facts about the scroll
      // position rather than about the control. A box touching the edge of a
      // clip above it is the box that is being cut, and it is measured
      // instead in the cells of the matrix where it sits in the open.
      //
      // The tolerance is 1.5 rather than 0.5 because the intersection is
      // rounded on its way through the layer tree: a 48-point button cut by
      // one point reports 47, which is a fact about the scroll offset and not
      // about the button, and a 0.5 tolerance called it a defect.
      const double touching = 1.5;
      // Per axis, not per box. A tab spans the full width of the bar, so its
      // left and right edges sit on the screen's — and a whole-box test read
      // that as "cut off" and never measured the 42-point height that is the
      // actual defect. A dimension is a fact about the control only on the
      // axis where nothing is cutting it, so each axis is decided alone.
      bool scrolledOut(Axis axis) => viewports.any(((Rect, Axis) viewport) {
        final (Rect box, Axis along) = viewport;
        if (along != axis || !box.overlaps(rect)) return false;
        return axis == Axis.horizontal
            ? rect.left <= box.left + touching ||
                  rect.right >= box.right - touching
            : rect.top <= box.top + touching ||
                  rect.bottom >= box.bottom - touching;
      });

      final bool cutHorizontally =
          rect.left <= clip.left + touching ||
          rect.right >= clip.right - touching ||
          scrolledOut(Axis.horizontal);
      final bool cutVertically =
          rect.top <= clip.top + touching ||
          rect.bottom >= clip.bottom - touching ||
          scrolledOut(Axis.vertical);

      final bool whollyVisible =
          rect.top >= -0.5 &&
          rect.left >= -0.5 &&
          rect.bottom <= ProbeCell.height + 0.5 &&
          rect.right <= cell.width + 0.5;
      final bool tooNarrow = !cutHorizontally && rect.width < floor - 0.5;
      final bool tooShort = !cutVertically && rect.height < floor - 0.5;
      if (whollyVisible &&
          rect.width > 0.5 &&
          rect.height > 0.5 &&
          (tooNarrow || tooShort)) {
        final String what = data.label.isEmpty
            ? 'an unlabelled control'
            : '"${data.label}"';
        if (reported.add('$what${rect.size}')) {
          found.add(
            ProbeViolation(
              rule: 'target',
              surface: surface.name,
              cell: cell,
              key: what,
              detail:
                  '$what can be tapped at ${rect.width.toStringAsFixed(0)}'
                  '×${rect.height.toStringAsFixed(0)}pt, under the '
                  '${floor.toInt()}pt floor',
            ),
          );
        }
      }
    }

    node.visitChildren((SemanticsNode child) {
      walk(child, transform, clip);
      return true;
    });
  }

  // The screen is the outermost clip. Nothing declares it as one — the render
  // view simply stops painting — so a control whose visible remainder ends on
  // the edge of the viewport reported that remainder as its size. A chip
  // resting twenty points above the bottom of a scrolling page measured as a
  // twenty-point chip, which is a fact about the scroll offset.
  walk(
    root,
    Matrix4.identity(),
    Rect.fromLTWH(0, 0, cell.width, ProbeCell.height),
  );
  return found;
}

/// `dual-axis` — the surface itself scrolls sideways as well as down.
///
/// A chip strip that scrolls inside a page is not this: it is a control with
/// its own axis, and it is everywhere. The failure is the *page* having two
/// axes, which is what makes content unreachable — you cannot pan and scroll
/// at once with one thumb.
List<ProbeViolation> ruleDualAxis(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  final List<ProbeViolation> found = <ProbeViolation>[];

  for (final Element element in tester.allElements) {
    if (element.widget is! Scrollable) continue;
    final ScrollableState state =
        (element as StatefulElement).state as ScrollableState;
    if (!state.position.hasContentDimensions) continue;
    if (state.position.axis != Axis.horizontal) continue;
    if (state.position.maxScrollExtent <= 0.5) continue;

    // A horizontal scroller with a vertical one *inside* it is a page with
    // two axes; a horizontal scroller inside a vertical page is a control.
    bool nestsVertical = false;
    void look(Element candidate) {
      if (nestsVertical) return;
      if (candidate.widget is Scrollable) {
        final ScrollableState inner =
            (candidate as StatefulElement).state as ScrollableState;
        if (inner.position.hasContentDimensions &&
            inner.position.axis == Axis.vertical &&
            inner.position.maxScrollExtent > 0.5) {
          nestsVertical = true;
          return;
        }
      }
      candidate.visitChildren(look);
    }

    element.visitChildren(look);
    if (!nestsVertical) continue;

    found.add(
      ProbeViolation(
        rule: 'dual-axis',
        surface: surface.name,
        cell: cell,
        key: 'page',
        detail:
            'the surface scrolls ${state.position.maxScrollExtent.toStringAsFixed(0)}pt '
            'sideways and scrolls down inside that — one thumb cannot do both',
      ),
    );
  }

  return found;
}

/// `contrast` — rendered text against the surface it is actually painted on.
///
/// `palette-lint` already checks the palette's own pairs. This checks what was
/// drawn: a token can be compliant and still be used on the wrong background,
/// and the pair that ships is the drawn one.
List<ProbeViolation> ruleContrast(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  final List<ProbeViolation> found = <ProbeViolation>[];
  final Set<String> reported = <String>{};
  final List<Rect> inactive = _inactiveRegions(tester);

  for (final RenderObject object in tester.allRenderObjects) {
    if (object is! RenderParagraph) continue;
    if (!_isVisible(object)) continue;
    if (_hiddenByOpacity(object)) continue;
    if (_inside(inactive, object)) continue;

    final TextStyle? style = object.text.style;

    // An icon is a glyph from an icon font, so it arrives here as a
    // paragraph. It is a graphic, and graphics are graded against a different
    // floor by a different rule — reading one as 13-point body text would
    // fail every icon in the kit for being an icon.
    if (style?.fontFamily?.contains('MaterialIcons') ?? false) continue;

    final Color? foreground = style?.color;
    if (foreground == null || foreground.a < 1.0) continue;

    // The worst stop, not the average one: a string over a ramp has to be
    // readable everywhere it is painted, and the end that fails is the end
    // somebody reads.
    final List<Color> backgrounds = _backgroundsBehind(object);
    if (backgrounds.isEmpty) continue;

    Color background = backgrounds.first;
    double ratio = contrastRatio(foreground, background);
    for (final Color candidate in backgrounds.skip(1)) {
      final double candidateRatio = contrastRatio(foreground, candidate);
      if (candidateRatio < ratio) {
        ratio = candidateRatio;
        background = candidate;
      }
    }

    final double fontSize = style?.fontSize ?? 16;
    final bool bold = (style?.fontWeight?.value ?? 400) >= 700;
    final bool large = fontSize >= 24 || (bold && fontSize >= 18.66);
    final double required = large ? 3.0 : 4.5;
    if (ratio >= required - 0.005) continue;

    final String text = object.text.toPlainText();
    final String excerpt = text.length > 32
        ? '${text.substring(0, 32)}…'
        : text;
    if (!reported.add('$excerpt$foreground$background')) continue;

    found.add(
      ProbeViolation(
        rule: 'contrast',
        surface: surface.name,
        cell: cell,
        key: excerpt,
        detail:
            '"$excerpt" at ${fontSize.toStringAsFixed(0)}pt renders '
            '${ratio.toStringAsFixed(2)}:1 — ${_hex(foreground)} on '
            '${_hex(background)} — ${required.toStringAsFixed(1)}:1 is the '
            'floor',
      ),
    );
  }

  return found;
}

/// Every part of the screen belonging to a control that is switched off.
///
/// WCAG 2.2 exempts these in as many words: SC 1.4.3 does not apply to "text
/// or images of text that are part of an inactive user interface component".
/// It is not a loophole — a disabled control is *supposed* to recede, and
/// holding it to 4.5:1 is asking a kit to make "you cannot use this" as loud
/// as "you can". The rule read four of them as defects, and the fix each one
/// implied was to make the disabled state harder to tell from the live one.
///
/// Read from the semantics tree rather than from widget types, for the same
/// reason the tap floor is: it is the one place every control in the kit and
/// every control it does not own both declare the same fact.
List<Rect> _inactiveRegions(WidgetTester tester) {
  final SemanticsNode? root = rootSemanticsNode(tester);
  if (root == null) return const <Rect>[];
  final List<Rect> found = <Rect>[];

  void walk(SemanticsNode node, Matrix4 inherited) {
    final Matrix4 transform = node.transform == null
        ? inherited
        : (inherited.clone()..multiply(node.transform!));
    if (node.getSemanticsData().flagsCollection.isEnabled == Tristate.isFalse) {
      found.add(MatrixUtils.transformRect(transform, node.rect));
    }
    node.visitChildren((SemanticsNode child) {
      walk(child, transform);
      return true;
    });
  }

  walk(root, Matrix4.identity());
  return found;
}

/// True when [object] is drawn inside one of [regions].
///
/// By centre rather than by overlap: a label that merely touches the edge of a
/// disabled control is not part of it, and a rule that excused everything
/// adjacent to a disabled thing would excuse most of a settings screen.
bool _inside(List<Rect> regions, RenderObject object) {
  if (regions.isEmpty) return false;
  final RenderBox box = object as RenderBox;
  if (!box.hasSize) return false;
  final Offset centre = MatrixUtils.transformPoint(
    box.getTransformTo(null),
    box.size.center(Offset.zero),
  );
  return regions.any((Rect region) => region.contains(centre));
}

/// The colour as a designer writes it, so a failure names two roles rather
/// than two ratios.
String _hex(Color colour) =>
    '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// True when something above [object] is fading it in or out.
///
/// A half-faded entrance is not a contrast defect; it is a frame of an
/// animation, and grading one would make the rule depend on when the probe
/// happened to look.
bool _hiddenByOpacity(RenderObject object) {
  RenderObject? node = object;
  while (node != null) {
    if (node is RenderAnimatedOpacityMixin && node.opacity.value < 0.999) {
      return true;
    }
    if (node is RenderOpacity && node.opacity < 0.999) return true;
    node = node.parent;
  }
  return false;
}

/// The number of candidate backgrounds one string is allowed to have.
///
/// Every gradient in the ancestry multiplies the count, so a tree with three
/// five-stop ramps in it would ask for 125 answers to a question that has one
/// useful one. Past the cap the honest answer is that this is not readable
/// from the render tree, which is what the rest of this walk says by returning
/// nothing.
const int _maxBackgroundCandidates = 24;

/// Every colour [object] could be sitting on, composited to opacity.
///
/// A list rather than a colour, because a gradient is not one background. A
/// string laid over a ramp is painted on every stop of it, and it has to clear
/// the floor against the worst one — the ramp's own midpoint is generous by
/// construction, and grading against it is how a label that disappears at one
/// end of a hero passes.
///
/// Before this read gradients at all it resolved a background by walking up
/// for a `BoxDecoration.color`. A gradient has none, so the walk continued and
/// graded the string against whatever opaque layer was further back. That was
/// silent in both directions: a label unreadable over the pale end of a ramp
/// passed against the dark box behind it, and a legible one over a dark ramp
/// failed against the page.
List<Color> _backgroundsBehind(RenderObject object) {
  // A candidate that is not yet opaque is still accumulating; one that is has
  // reached the bottom of what is painted and is an answer.
  List<Color?> pending = <Color?>[null];
  final List<Color> settled = <Color>[];
  RenderObject child = object;
  RenderObject? node = object.parent;

  while (node != null && pending.isNotEmpty) {
    // A layer painted by hand is a layer this cannot read. Reporting the
    // colour *behind* the custom painter as the background is how a selected
    // segment on its own pill measures as white on white: the pill is drawn,
    // not decorated. Unknown is the honest answer, and the rule says nothing
    // rather than something false.
    //
    // Only a *background* painter, though. `CustomPaint` draws `painter`
    // behind its child and `foregroundPainter` in front of it, so a node that
    // has only the second one cannot be what the text is sitting on. Giving up
    // on both is why this rule graded nothing at all on a real screen: every
    // `Material` in the kit inserts a `RenderCustomPaint` whose `painter` is
    // null and whose `foregroundPainter` is Flutter's own `_ShapeBorderPainter`
    // — it draws the border over the child — and every card, button and sheet
    // in the app is wrapped in one. All twenty-six strings on the dashboard
    // were ungraded, the gradient hero included.
    if (node is RenderCustomPaint && node.painter != null) {
      return const <Color>[];
    }

    // A stack, unless the branch we came up is the one painted first. What is
    // behind a later child is a sibling layer, not an ancestor, and walking
    // past it reports the colour of the wrong thing — a selected segment
    // sitting on its own thumb measured as white on white.
    //
    // The first child has no such sibling under it: everything else in the
    // stack is painted on top. Giving up on every stack instead made the rule
    // silent about every `DSCard` in the kit, which wraps its body in one so a
    // selection badge can sit over it — the dashboard's gradient hero
    // included, which is the surface this rule most needs to be able to read.
    if (node is RenderStack && !identical(node.firstChild, child)) {
      return const <Color>[];
    }

    final List<Color> layers = _layerColours(node);
    if (layers.isNotEmpty) {
      if (pending.length * layers.length > _maxBackgroundCandidates) {
        return const <Color>[];
      }
      final List<Color?> next = <Color?>[];
      for (final Color? accumulated in pending) {
        for (final Color layer in layers) {
          // A fully transparent stop is a hole, not a background: it is what
          // makes a scrim a scrim. It contributes nothing and the walk
          // continues to whatever shows through it.
          if (layer.a <= 0) {
            next.add(accumulated);
            continue;
          }
          final Color blended = accumulated == null
              ? layer
              : Color.alphaBlend(accumulated, layer);
          if (blended.a >= 1.0) {
            settled.add(blended);
          } else {
            next.add(blended);
          }
        }
      }
      pending = next;
    }
    child = node;
    node = node.parent;
  }

  // A candidate that never reached an opaque layer is unknown, and unknown is
  // not graded.
  return settled;
}

/// The colours one render object paints behind its child.
///
/// One entry for a flat fill, one per stop for a gradient. `BoxDecoration`
/// treats `color` and `gradient` as mutually exclusive, so this is a choice
/// between them rather than a merge.
List<Color> _layerColours(RenderObject node) {
  if (node is RenderDecoratedBox) {
    final Decoration decoration = node.decoration;
    if (decoration is BoxDecoration) {
      return _gradientOrColour(decoration.gradient, decoration.color);
    }
    if (decoration is ShapeDecoration) {
      return _gradientOrColour(decoration.gradient, decoration.color);
    }
    return const <Color>[];
  }
  if (node is RenderPhysicalModel) return <Color>[node.color];
  if (node is RenderPhysicalShape) return <Color>[node.color];
  return const <Color>[];
}

/// The distinct stops of [gradient], or [colour] when there is no gradient.
///
/// Distinct because a ramp that repeats a stop — the usual way of holding a
/// colour flat over part of a scrim — would otherwise multiply the candidate
/// count for no new answer.
List<Color> _gradientOrColour(Gradient? gradient, Color? colour) {
  if (gradient != null && gradient.colors.isNotEmpty) {
    final List<Color> stops = <Color>[];
    for (final Color stop in gradient.colors) {
      if (!stops.contains(stop)) stops.add(stop);
    }
    return stops;
  }
  return colour == null ? const <Color>[] : <Color>[colour];
}

/// WCAG 2.1 relative luminance contrast, on colours already composited.
double contrastRatio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double lighter = la > lb ? la : lb;
  final double darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color colour) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(colour.r) +
      0.7152 * channel(colour.g) +
      0.0722 * channel(colour.b);
}

/// `tour-art-semantics` — a tour's drawing is in the screen reader's path.
///
/// A slide's illustration says what its headline and body already say. Left in
/// the semantics tree it is read out as a list of sample figures — the numbers
/// on a drawn invoice, the labels on a drawn list — before the words that mean
/// something. [DSTourSlide] wraps its art in an [ExcludeSemantics]; a sequence
/// composed by hand out of raw canvases does not.
///
/// Scoped by the indicator rather than by [DSTourSlide]. Asking "is this
/// canvas inside a slide" would make a rule that can never fail — the slide is
/// the thing that does the excluding, so every canvas it contains is silent by
/// construction, and a hand-rolled sequence contains no slide to find. A
/// [DSTourDots] on the surface is what says this drawing is one of a run
/// rather than a specimen on its own in the catalog, where there is no
/// headline for it to duplicate.
///
/// The test is the rendered semantics tree, not the widget tree: what matters
/// is whether the drawn strings actually reach a label, however they got
/// there.
List<ProbeViolation> ruleTourArtSemantics(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  final Finder canvases = find.byType(DSTourCanvas);
  final int count = canvases.evaluate().length;
  if (count == 0) return const <ProbeViolation>[];
  if (find.byType(DSTourDots).evaluate().isEmpty) {
    return const <ProbeViolation>[];
  }

  final Set<String> spoken = <String>{};
  void collect(SemanticsNode node) {
    final String label = node.getSemanticsData().label;
    if (label.isNotEmpty) spoken.add(label);
    node.visitChildren((SemanticsNode child) {
      collect(child);
      return true;
    });
  }

  final SemanticsNode? root = rootSemanticsNode(tester);
  if (root == null) return const <ProbeViolation>[];
  collect(root);

  final List<ProbeViolation> found = <ProbeViolation>[];
  for (int i = 0; i < count; i++) {
    final Iterable<String> drawn = find
        .descendant(of: canvases.at(i), matching: find.byType(Text))
        .evaluate()
        .map((Element e) => (e.widget as Text).data ?? '')
        .where((String text) => text.isNotEmpty)
        .where(
          (String text) => spoken.any((String label) => label.contains(text)),
        );
    if (drawn.isEmpty) continue;

    found.add(
      ProbeViolation(
        rule: 'tour-art-semantics',
        surface: surface.name,
        cell: cell,
        key: 'slide art #${i + 1}',
        detail:
            'the drawing on this slide is read aloud as "${drawn.first}", '
            'before the headline that says the same thing. Wrap it in '
            'ExcludeSemantics, or draw it through DSTourSlide, which already '
            'does',
      ),
    );
  }

  return found;
}

/// `tour-progress-label` — the position indicator is unreadable.
///
/// [DSTourDots] has no tap target and excludes its own marks from semantics —
/// six-point dots read out one by one are noise. What replaces them is a
/// single label, `Page 2 of 4`, and without it a screen-reader user has no way
/// at all to know how long the sequence is or how far through it they are.
///
/// The label is looked for anywhere in the rendered semantics tree rather than
/// read off the indicator's own node. `getSemantics` returns the nearest
/// *enclosing* node, so inside a catalog story — where the card merges its
/// title and note with everything under it — it answered with the story's
/// prose and failed a component that was labelled correctly.
List<ProbeViolation> ruleTourProgressLabel(
  WidgetTester tester,
  ProbeSurface surface,
  ProbeCell cell,
) {
  final Finder indicators = find.byType(DSTourDots);
  final int count = indicators.evaluate().length;
  if (count == 0) return const <ProbeViolation>[];

  final Set<String> spoken = <String>{};
  void collect(SemanticsNode node) {
    final String label = node.getSemanticsData().label;
    if (label.isNotEmpty) spoken.add(label);
    node.visitChildren((SemanticsNode child) {
      collect(child);
      return true;
    });
  }

  final SemanticsNode? root = rootSemanticsNode(tester);
  if (root != null) collect(root);

  final List<ProbeViolation> found = <ProbeViolation>[];
  for (int i = 0; i < count; i++) {
    final DSTourDots dots =
        indicators.at(i).evaluate().single.widget as DSTourDots;
    final int page = dots.position.round().clamp(0, dots.count - 1) + 1;
    final String wanted = 'Page $page of ${dots.count}';
    if (spoken.any((String label) => label.contains(wanted))) continue;

    found.add(
      ProbeViolation(
        rule: 'tour-progress-label',
        surface: surface.name,
        cell: cell,
        key: 'indicator #${i + 1}',
        detail:
            'nothing on this surface reads out "$wanted", so how long the '
            'sequence is and how far through it you are cannot be heard at '
            'all. The position indicator has to carry that label',
      ),
    );
  }

  return found;
}
