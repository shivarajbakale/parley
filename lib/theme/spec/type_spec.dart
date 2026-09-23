import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The type system, as data.
///
/// Sizes are grown from one [baseSize] and one [ratio] rather than typed
/// fifteen times, so changing the ratio re-proportions the whole app and the
/// steps stay in relation to each other. A hand-typed scale drifts the first
/// time somebody needs "just a bit bigger" for one screen.
@immutable
class TypeSpec {
  final String family;

  /// The face used for display and headline roles. Often the same as
  /// [family]; an editorial identity pairs a display serif with a text sans.
  final String displayFamily;
  final List<String> fallback;

  /// The size of `bodyMedium`. Everything else is a power of [ratio] from it.
  ///
  /// 14.08: 12.8 (16 taken down a fifth) raised 10% across the app. This is the one number that
  /// re-proportions the app: the fifteen steps are powers of [ratio] around
  /// it, tracking is expressed as a fraction of it, and line heights are
  /// multiples, so moving it moves every role and leaves every relationship
  /// between them where it was. There are no hardcoded sizes in `lib/` for it
  /// to miss.
  ///
  /// It sat at 16 for a long time, and the argument for 16 was a good one:
  /// `bodyMedium` is what Flutter hands any widget that does not name a role,
  /// Apple sets body at 17pt and Material at 16sp, and the scale's first
  /// value of 14 put every unstyled paragraph under both platforms. That
  /// argument answers "how large should unstyled running text be on a phone
  /// held at arm's length", and it is still the right answer to that
  /// question.
  ///
  /// It is not the question this app is answering. The screens are dense —
  /// lists, metric strips, settings rows, cards with three lines of
  /// supporting copy — and at 16 the interface spent its first screenful on
  /// fewer rows than the reader wanted to see. Coming down a fifth buys back
  /// roughly a quarter more content per screen. The cost is real and worth
  /// naming: `bodyMedium` is now 12.8pt, under both platform defaults, and
  /// `bodySmall` is 11.5pt in a supporting grey. Small grey type is still the
  /// most reliable sign of an interface composed on a monitor, which is why
  /// the colour floors below are enforced by the probe rather than trusted —
  /// a smaller scale makes the contrast gates matter more, not less.
  ///
  /// The reader's own text scale is untouched by this. Anything running copy
  /// still grows without a ceiling; only the roles that truncate are clamped,
  /// by [controlScaleCeiling] and [titleScaleCeiling].
  final double baseSize;

  /// The size the `display*` and `headline*` steps grow from.
  ///
  /// A second anchor, not a second scale: the ratio and the fifteen steps are
  /// shared, and this only says which size step zero sits at for the loud
  /// half of the family. 16 — where [baseSize] used to be — so the roles a
  /// page is titled with are exactly the sizes they were before the scale
  /// came down.
  ///
  /// The two anchors exist because "make the text smaller" turned out to mean
  /// two different things at the two ends of the scale. Running copy, labels
  /// and controls at 16 were larger than the screens needed, and taking them
  /// down a fifth buys back most of a row per screenful. A page title is not
  /// competing for that space — there is one of it — and shrinking it with
  /// everything else cost the hierarchy without buying anything back. One
  /// anchor could not express that; nor could a hand-tuned [override], which
  /// gives up the ratio entirely.
  ///
  /// The roles this reaches are the four on a display or headline step:
  /// `display`, `pageTitle`, `screenTitle` and `metric`. `sectionTitle` sits
  /// on `titleMedium` and follows [baseSize] with the rest of the running
  /// text, which is the right side of the line for a heading *inside* the
  /// content rather than one naming the page.
  final double displayBase;

  /// The interval between adjacent steps. 1.10, down from 1.15 at launch and
  /// 1.13 after the first tightening. Both earlier values put the top of the
  /// scale in poster territory — 53pt then 43pt for `displayLarge` — and a
  /// page whose title eats a fifth of the first screenful has spent its most
  /// valuable space on a word the user already knows.
  ///
  /// At 1.10 `displayLarge` lands at 35pt, `headlineMedium` at 24.4pt and
  /// `titleLarge` at 20.4pt, while `bodyMedium` stays at the [baseSize] (16)
  /// because it is the pivot the scale grows from in both directions. The
  /// trade is deliberate and one-directional: the loud roles get quieter,
  /// body and label stay where the platform standards put them, and the
  /// sub-base roles come *up* slightly (`bodySmall` 14.0 to 14.4,
  /// `labelSmall` 13.0 to 13.6) because compressing toward the pivot lifts
  /// everything below it. Small grey type getting a third of a point back is
  /// the right side of that trade.
  ///
  /// Contrast is held, not assumed. The probe's WCAG "large text" test is
  /// `>= 24pt, or >= 18.66pt at weight 700`, so a size change can move a
  /// string from a 3:1 floor to a 4.5:1 one without anybody editing a colour.
  /// Taking [baseSize] down a fifth would have moved `screenTitle` across it —
  /// `headlineSmall` falls from 22.3pt to 17.9pt and loses the bold-large
  /// exemption — which is one of the reasons the loud roles are anchored to
  /// [displayBase] instead and did not move at all. Every display and
  /// headline step is the size it has always been, at [headlineWeight] (700),
  /// and the exemption holds. `display` is the exception, and it is safe for
  /// the other reason: it sits on `displayMedium` at 31.8pt, and above 24pt
  /// the 3:1 floor applies at any weight, Light included.
  final double ratio;

  /// The role weights, and the one step above them.
  ///
  /// **Every weight here must exist in the bundled face.** A `TextStyle` that
  /// asks for a weight the font does not ship is not an error — the engine
  /// picks a neighbouring face for you, and which neighbour it picks is a
  /// property of the font-matching algorithm rather than a decision anyone on
  /// the team made. Satoshi ships 300 / 400 / 500 / 700 / 900 and has no
  /// Semibold, so `w600` here silently rendered every title and every label in
  /// the app at a weight nobody chose. `test/theme/type_manifest_test.dart`
  /// now fails the build on it, reading the manifest out of `pubspec.yaml`.
  final FontWeight displayWeight;

  /// The weight of the `headline*` steps, when it differs from
  /// [displayWeight].
  ///
  /// One token used to cover both families, which was fine while both wanted
  /// Bold. It stopped being fine when `display` went to Light: the display
  /// steps are 25pt and up, where a light face reads as composed, and the
  /// headline steps are 18-21pt, where the same face reads as thin. A page
  /// title at 19.5pt in Light is not a refinement, it is a legibility
  /// regression, and it would also drop out of the probe's `>= 18.66pt at
  /// weight 700` exemption and be graded at 4.5:1 against a colour chosen for
  /// 3:1.
  ///
  /// Null means "whatever [displayWeight] is", which is what the identities
  /// that set a display weight of their own already assume.
  final FontWeight? headlineWeight;

  final FontWeight titleWeight;
  final FontWeight bodyWeight;
  final FontWeight labelWeight;

  /// One step heavier than the role's own weight, for the word in a line that
  /// carries the meaning: the selected step, the value in a metric, the label
  /// on a filled button.
  ///
  /// A token rather than a `copyWith` at each call site. Ten components
  /// independently typed `FontWeight.w600` for exactly this, which is one
  /// decision made once and copied nine times — and all ten were asking for
  /// the weight Satoshi does not have.
  final FontWeight emphasisWeight;

  /// Letter-spacing at [baseSize], and how much of it is removed as type
  /// grows. Large type set at body tracking always looks loose; this is the
  /// one typographic rule that most separates a designed screen from a
  /// default one.
  final double tracking;
  final double trackingTightening;

  /// Extra tracking on the label roles, in logical pixels at [baseSize].
  ///
  /// Labels sit at or below base, where the tightening formula gives back
  /// almost nothing — but a button label and a nav label are read as shapes
  /// at a glance rather than as running copy, and both want the letters
  /// opened up. This is the one place the scale needs a term of its own.
  final double labelTracking;

  /// Line height as a multiple of size, at [baseSize] and at display sizes.
  final double bodyHeight;
  final double displayHeight;

  /// Whether an eyebrow (a section's small label) is set in capitals, and how
  /// far it is tracked out when it is.
  final bool eyebrowUppercase;
  final double eyebrowTracking;

  /// How far a role that truncates may grow under the reader's text scale.
  ///
  /// Running copy has no ceiling: a paragraph must grow as far as the reader
  /// asks, and a screen that cannot show a longer paragraph is a scrolling
  /// problem. A *label* is different — a segmented control that grew to fit
  /// its longest label at 200% would stop being a segmented control, which is
  /// the distinction `AppChoiceLabel` already draws for the probe.
  ///
  /// 1.3 because five components had already reached for a limit here and one
  /// of them typed exactly this number: `ds_segmented_progress` switches its
  /// layout above `textScalerOf(context).scale(1) > 1.3`. Four others solved
  /// the same problem four other ways. One knob, so an identity that wants
  /// labels to grow further can say so once.
  final double controlScaleCeiling;

  /// How far a page or screen title may grow with the reader's text size.
  ///
  /// Looser than [controlScaleCeiling], and the two numbers answer different
  /// questions. A control has a fixed box and a ceiling keeps its label
  /// inside it. A title has no box — it wraps — so its ceiling exists only to
  /// stop a truncating role growing without limit, which is the rule
  /// [DSTextRole] states and `pageTitle` was the one role breaking.
  ///
  /// The floor for this number is the point where the title stops outranking
  /// the body it introduces. Body copy is [baseSize] and scales freely, so at
  /// a doubled text scale it is 32pt; a `headlineMedium` page title is 24.4pt,
  /// and it stays larger than that body for any ceiling above 1.31. The
  /// control ceiling of 1.3 is below that line — clamping a title there would
  /// draw the page's name *smaller* than the paragraph under it.
  final double titleScaleCeiling;

  /// The smallest size the app draws, as a share of `labelSmall`, and the
  /// point below which it stops shrinking.
  ///
  /// A share rather than another entry in [_steps], because the steps are
  /// powers of [ratio] and the identities do not share a ratio: at `ledger`'s
  /// 1.20 the step that reads as "one notch under a label" at 1.10 lands
  /// well under a timestamp and into rendering-artifact territory. A share
  /// drops every identity by the same *proportion*, and [microFloor] is the
  /// absolute line under which no identity may put a glyph however tightly
  /// its own scale is wound.
  ///
  /// The floor is 8, down from 10 with the rest of the scale. It has to move
  /// with [baseSize] or it stops being a floor and becomes a second, hidden
  /// step: at 12.8 the default identity's `labelSmall` is 10.9pt, so a floor
  /// left at 10 would have pinned `micro` within a tenth of a point of the
  /// label above it and collapsed the one distinction the role exists to
  /// draw.
  final double microScale;
  final double microFloor;

  /// An explicit theme, used instead of the generated one when present.
  ///
  /// This is how an identity keeps a hand-tuned scale that no ratio produces —
  /// including the scale this app shipped before the spec existed, which is
  /// what makes the move to a spec provably free of visual change.
  final TextTheme? override;

  const TypeSpec({
    this.family = 'Satoshi',
    this.displayFamily = 'Satoshi',
    this.fallback = const ['Roboto'],
    this.baseSize = 14.08,
    this.displayBase = 17.6,
    this.ratio = 1.10,
    this.displayWeight = FontWeight.w400,
    this.headlineWeight = FontWeight.w700,
    this.titleWeight = FontWeight.w500,
    this.bodyWeight = FontWeight.w400,
    this.labelWeight = FontWeight.w500,
    this.emphasisWeight = FontWeight.w700,
    this.tracking = 0,
    this.trackingTightening = 0.55,
    this.labelTracking = 0.15,
    this.bodyHeight = 1.45,
    this.displayHeight = 1.12,
    this.eyebrowUppercase = true,
    this.eyebrowTracking = 1.2,
    this.controlScaleCeiling = 1.3,
    this.titleScaleCeiling = 1.6,
    this.microScale = 0.82,
    this.microFloor = 8.8,
    this.override,
  });

  /// Steps from `bodyMedium`, per Material role.
  ///
  /// Fractional on purpose. The step is whatever power of [ratio] lands on
  /// the size the role wants; snapping them to halves instead would round
  /// `titleLarge` down and put it a point off `titleMedium`.
  ///
  /// Nothing here is pinned to dodge a gate. `titleMedium` briefly was: at
  /// 18.3pt it fell under the probe's 18.66pt bold WCAG line and failed six
  /// strings on `screen/blog`, so the step was raised to hold the role at 19.
  /// That was the wrong fix. The strings were the blog's category swatches,
  /// which the probe was grading against the card *behind* the swatch rather
  /// than the swatch — `_layerColour` reads `BoxDecoration.color` and a
  /// gradient-only decoration has none. The swatch is flat now, the probe
  /// reads the colour that is actually there, and the step went back to
  /// where the scale puts it. A type scale bent around a measurement artifact
  /// is a scale nobody can reason about.
  static const Map<String, double> _steps = {
    'displayLarge': 8.2,
    'displayMedium': 7.2,
    'displaySmall': 6.14,
    'headlineLarge': 5.3,
    'headlineMedium': 4.43,
    'headlineSmall': 3.5,
    'titleLarge': 2.55,
    'titleMedium': 1.39,
    'titleSmall': 0.5,
    'bodyLarge': 0.5,
    'bodyMedium': 0,
    'bodySmall': -1.1,
    'labelLarge': 0,
    'labelMedium': -1.1,
    'labelSmall': -1.73,
  };

  /// Which anchor a role grows from. Display and headline share one; every
  /// other role shares the other.
  double anchorOf(String role) =>
      role.startsWith('display') || role.startsWith('headline')
      ? displayBase
      : baseSize;

  double sizeOf(String role) =>
      anchorOf(role) * math.pow(ratio, _steps[role] ?? 0).toDouble();

  /// One notch under the smallest label: a bubble's timestamp, a delivery
  /// mark, the second of a duration.
  ///
  /// Not in the [TextTheme] because Material's fifteen roles stop at
  /// `labelSmall` and a sixteenth slot does not exist to put it in. It is
  /// reached through [DSTextRole.timestamp] rather than by a widget asking
  /// the spec for a size — the role is what a call site names, here as
  /// everywhere else.
  TextStyle get micro {
    final base = _style('labelSmall');
    final size = math.max(sizeOf('labelSmall') * microScale, microFloor);
    return base.copyWith(fontSize: size);
  }

  TextStyle _style(String role) {
    final size = sizeOf(role);
    final isHeadline = role.startsWith('headline');
    // Display and headline share a face, a line height and a tracking curve;
    // they part company only on weight, so `isDisplay` still spans both.
    final isDisplay = role.startsWith('display') || isHeadline;
    final isLabel = role.startsWith('label');
    final isTitle = role.startsWith('title');
    // Tracking tightens as size grows, in proportion to how far above base
    // this step is. Below base it loosens, which is what keeps a 11pt label
    // legible.
    // Against the role's own anchor, so a display step is tracked by how far
    // it sits above the size *its* family grows from. Measuring it against
    // [baseSize] instead would tighten the loud roles by however far the two
    // anchors have been moved apart, which is a number about the body scale.
    final anchor = anchorOf(role);
    final delta = (size - anchor) / anchor;
    return TextStyle(
      fontFamily: isDisplay ? displayFamily : family,
      fontFamilyFallback: fallback,
      fontSize: size,
      height: isDisplay ? displayHeight : bodyHeight,
      letterSpacing:
          tracking - delta * trackingTightening + (isLabel ? labelTracking : 0),
      fontWeight: isDisplay
          ? (isHeadline ? (headlineWeight ?? displayWeight) : displayWeight)
          : isTitle
          ? titleWeight
          : isLabel
          ? labelWeight
          : bodyWeight,
    );
  }

  /// The theme to install. [override] wins when an identity supplies one.
  TextTheme build() =>
      override ??
      TextTheme(
        displayLarge: _style('displayLarge'),
        displayMedium: _style('displayMedium'),
        displaySmall: _style('displaySmall'),
        headlineLarge: _style('headlineLarge'),
        headlineMedium: _style('headlineMedium'),
        headlineSmall: _style('headlineSmall'),
        titleLarge: _style('titleLarge'),
        titleMedium: _style('titleMedium'),
        titleSmall: _style('titleSmall'),
        bodyLarge: _style('bodyLarge'),
        bodyMedium: _style('bodyMedium'),
        bodySmall: _style('bodySmall'),
        labelLarge: _style('labelLarge'),
        labelMedium: _style('labelMedium'),
        labelSmall: _style('labelSmall'),
      );

  TypeSpec copyWith({
    String? family,
    String? displayFamily,
    double? baseSize,
    double? displayBase,
    double? ratio,
    double? tracking,
    double? labelTracking,
    bool? eyebrowUppercase,
    TextTheme? override,
  }) => TypeSpec(
    family: family ?? this.family,
    displayFamily: displayFamily ?? this.displayFamily,
    fallback: fallback,
    baseSize: baseSize ?? this.baseSize,
    displayBase: displayBase ?? this.displayBase,
    ratio: ratio ?? this.ratio,
    displayWeight: displayWeight,
    headlineWeight: headlineWeight,
    titleWeight: titleWeight,
    bodyWeight: bodyWeight,
    labelWeight: labelWeight,
    emphasisWeight: emphasisWeight,
    tracking: tracking ?? this.tracking,
    trackingTightening: trackingTightening,
    labelTracking: labelTracking ?? this.labelTracking,
    bodyHeight: bodyHeight,
    displayHeight: displayHeight,
    eyebrowUppercase: eyebrowUppercase ?? this.eyebrowUppercase,
    eyebrowTracking: eyebrowTracking,
    controlScaleCeiling: controlScaleCeiling,
    titleScaleCeiling: titleScaleCeiling,
    microScale: microScale,
    microFloor: microFloor,
    override: override ?? this.override,
  );
}
