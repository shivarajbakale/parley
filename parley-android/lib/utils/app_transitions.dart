import 'package:flutter/material.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Route transitions that are not the platform's own.
///
/// [DesignSpec.themeFor] sets `pageTransitionsTheme`, which is what every
/// ordinary push gets — the Cupertino slide on Apple, Material 3's fade
/// forwards elsewhere. This is for the one route that wants a different
/// gesture: list → detail, which is a step *along an axis* rather than a new
/// page, and reads as one when it is drawn as one.
///
/// A builder rather than a namespace of constants: the timing comes from
/// `context.design.motion` at build time, so an identity that runs the app
/// brisk or languid moves this transition with everything else.
abstract final class AppTransitions {
  /// Material's shared-axis (X) transition.
  ///
  /// The incoming page slides a short distance from the trailing edge and
  /// fades through once the slide is underway; the page being covered drifts
  /// the other way and fades out. The fades are intervals rather than the
  /// whole duration, which is the signature — two pages at full opacity at
  /// the same moment is a cross-dissolve, and reads as a dissolve.
  ///
  /// Matches [RouteTransitionsBuilder], so it drops straight into
  /// `CustomTransitionPage(transitionsBuilder: AppTransitions.sharedAxis)`.
  static Widget sharedAxis(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final motion = context.design.motion;

    // A fraction of the page's width rather than a number of points: the
    // travel has to read the same on a phone and on a tablet, and 30 points
    // on a 1024-point page is a twitch.
    const travel = 0.075;

    final enterSlide = Tween<Offset>(
      begin: const Offset(travel, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: motion.emphasize));
    final enterFade = CurvedAnimation(
      parent: animation,
      curve: Interval(0.3, 1, curve: motion.enter),
    );

    final exitSlide =
        Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-travel, 0),
        ).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: motion.emphasize),
        );
    final exitFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: Interval(0, 0.7, curve: motion.exit),
      ),
    );

    return SlideTransition(
      position: exitSlide,
      child: FadeTransition(
        opacity: exitFade,
        child: SlideTransition(
          position: enterSlide,
          child: FadeTransition(opacity: enterFade, child: child),
        ),
      ),
    );
  }
}
