// ds-tier: 0 — foundation

import 'package:flutter/widgets.dart';

/// The three sizes every sized component in the kit offers.
///
/// One vocabulary rather than one enum per component: a footer that wants its
/// contents small cannot say so if every family spells "small" differently.
/// Components keep their own `DSxSize` for their own argument — this is the
/// name a *container* uses to speak to whatever it contains.
enum DSSize { sm, md, lg }

/// How tightly a container packs what is inside it.
enum DSDensity { comfortable, compact }

/// Meaning, not colour. A tone selects a palette family; it never names one.
enum DSTone { neutral, info, success, warning, error }

/// What a container is allowed to tell its contents.
///
/// The style chain in `docs/plans/00a-component-contract.plan.md` resolves an
/// appearance through four layers — the identity's `ComponentSpec`, a
/// `ThemeExtension` over a subtree, this scope, and the instance's own
/// `style:`. This is the third, and it exists because the other three cannot
/// express the commonest arrangement in a kit: *inside this footer, the
/// controls are small*.
///
/// `ComponentSpec` is app-wide, so it cannot single out one footer. A
/// `ThemeExtension` is subtree-wide but is reached through `Theme`, which is
/// heavy to nest per card. And `style:` is per instance, which is exactly the
/// repetition being removed — a row of four buttons should not repeat
/// `size: sm` four times.
///
/// ```dart
/// DSScope.merge(
///   context,
///   size: DSSize.sm,
///   child: Row(children: actions),
/// );
/// ```
///
/// Three rules keep it from becoming a second, worse theme.
///
/// **Only these four properties.** Anything else a container wants to impose
/// is the container reaching past its own boundary. Colour, padding and
/// typography stay in the style chain, where an identity can change them.
///
/// **An explicit argument always wins.** A scope supplies a default, never an
/// override, so `DSButton(size: DSButtonSize.lg)` inside a compact footer is
/// large. This is the difference between it and React's `cloneElement`, which
/// silently overwrites what the caller passed; a component reads the scope as
/// `explicit ?? DSScope.sizeOf(context) ?? theDefault`.
///
/// **Containers install it; components read it.** No screen reaches for
/// `DSScope` directly. If a screen needs one, that is a missing container.
///
/// An [InheritedWidget] is chosen over cloning children because cloning
/// reaches exactly one level deep: a footer whose actions are inside a [Wrap]
/// would lose the size, and no component should have to know how deeply it is
/// buried.
@immutable
class DSScope extends InheritedWidget {
  const DSScope({
    super.key,
    this.size,
    this.density,
    this.tone,
    this.enabled,
    required super.child,
  });

  /// The size a container suggests for the controls inside it.
  final DSSize? size;

  /// How tightly those controls are packed.
  final DSDensity? density;

  /// The meaning a container lends its contents — an error message's actions
  /// are in the error tone without each one being told.
  final DSTone? tone;

  /// A disabled container disables what it contains. Null means "no opinion",
  /// which is not the same as `true`.
  final bool? enabled;

  /// The nearest scope, or null when there is none.
  static DSScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DSScope>();

  static DSSize? sizeOf(BuildContext context) => maybeOf(context)?.size;

  static DSDensity? densityOf(BuildContext context) =>
      maybeOf(context)?.density;

  static DSTone? toneOf(BuildContext context) => maybeOf(context)?.tone;

  static bool? enabledOf(BuildContext context) => maybeOf(context)?.enabled;

  /// Installs a scope that keeps everything the enclosing one set and
  /// overrides only what is passed.
  ///
  /// Nesting has to merge rather than replace, or a footer that wants
  /// `density: compact` would silently drop the `tone` its message set two
  /// levels up — and the widget that lost it is not the widget that would be
  /// blamed.
  ///
  /// A disabled enclosing scope stays disabled: `enabled` merges by `&&`, not
  /// by "innermost wins". Re-enabling a control inside a disabled container is
  /// not a default a container may set, because the user cannot reach it.
  static Widget merge(
    BuildContext context, {
    DSSize? size,
    DSDensity? density,
    DSTone? tone,
    bool? enabled,
    required Widget child,
  }) {
    final outer = maybeOf(context);
    final outerEnabled = outer?.enabled;
    return DSScope(
      size: size ?? outer?.size,
      density: density ?? outer?.density,
      tone: tone ?? outer?.tone,
      enabled: outerEnabled == false ? false : (enabled ?? outerEnabled),
      child: child,
    );
  }

  @override
  bool updateShouldNotify(DSScope oldWidget) =>
      size != oldWidget.size ||
      density != oldWidget.density ||
      tone != oldWidget.tone ||
      enabled != oldWidget.enabled;
}

/// States that the page gutter is already applied above this point.
///
/// The kit has one rule about the page's reading edge — only [DSPage],
/// `DSFormPage` and `DSGutter` may apply it — and `ui_lint` holds screens to
/// it. A row is the exception the rule could not cover: it has to work as the
/// direct child of a scroll view with no gutter above it at all, so it applies
/// the inset itself.
///
/// Put that same row inside a page section and both insets applied. On a 390pt
/// phone the settings rows drew their icons at 40pt and their switches out to
/// 350pt while the section's own label sat at 20 and the paragraph under it
/// ran to 370, so every row on the page looked narrower than the page it was
/// on. It is not visible in a widget test that mounts the row by itself, and a
/// golden records whichever shape the page had on the day it was taken.
///
/// So the gutter is not a number a component reads, it is a question it asks:
/// *has anyone done this already?* The containers answer by wrapping what they
/// have inset in one of these.
///
/// Here rather than beside `DSGutter`, because a row is a molecule and the
/// page is a template: an import the other way round is the tier order
/// inverted, which `ui_lint` fails the build for.
class DSGutterScope extends InheritedWidget {
  const DSGutterScope({super.key, required super.child}) : _isApplied = true;

  /// Answers *not applied* below this point, regardless of what an ancestor
  /// answered — for a container that is a fresh surface rather than the page.
  ///
  /// A card is the case this exists for: [DSGutter] can mark a whole page's
  /// content as already inset, but a row inside a card sits at the card's
  /// edge, not the page's, and a card nested in an inset page inherited the
  /// page's answer with no way to say otherwise. The result was a `DSListTile`
  /// inside a `DSCard` inside a `DSGutter.sliver` skipping its own inset
  /// because *something* above it — the page, not the card — had already
  /// applied one, and its text ran to the card's bare edge.
  const DSGutterScope.reset({super.key, required super.child})
    : _isApplied = false;

  final bool _isApplied;

  /// Whether a container above [context] has already applied the page gutter.
  static bool applied(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DSGutterScope>()?._isApplied ??
      false;

  @override
  bool updateShouldNotify(DSGutterScope oldWidget) =>
      _isApplied != oldWidget._isApplied;
}

/// The extent a list row gives the well in its leading slot, so a well placed
/// in a row sizes to the row instead of to the standalone well token.
class DSRowLeadingScope extends InheritedWidget {
  const DSRowLeadingScope({
    super.key,
    required this.extent,
    required super.child,
  });

  final double extent;

  static double? extentOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DSRowLeadingScope>()?.extent;

  @override
  bool updateShouldNotify(DSRowLeadingScope oldWidget) =>
      extent != oldWidget.extent;
}
