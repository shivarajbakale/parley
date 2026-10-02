import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/onboarding_page.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The heights the sheet settles at, as a fraction of the screen.
///
/// Exported so the test asserts the contract rather than three literals typed
/// a second time — a detent list that only the widget knows is a detent list a
/// test can agree with while being wrong.
const List<double> welcomeDetents = <double>[0.32, 0.6, 0.9];

/// What each detent is called. Announced on settle, so a screen reader hears
/// the sheet arrive somewhere rather than hearing nothing and being left to
/// infer it from a changed scroll extent.
const List<String> welcomeDetentLabels = <String>['Peek', 'Half', 'Full'];

/// The welcome's "see what's inside" sheet — the third tier of affordance.
///
/// The welcome screen offers three weights of action, and this is the lightest:
/// the pinned bar's primary commits to the tour, its ghost skips to sign-in,
/// and this one answers "what is in there?" without leaving the screen. A
/// question answered in place is a question that does not cost the user their
/// position in the flow, which is the whole argument for a sheet over a route.
///
/// It shows the same [onboardingStops] the tour runs, with each stop's own
/// drawing rather than a stock icon — so the preview is of the thing the button
/// is about to start, and the two cannot drift: change a stop and this changes
/// with it.
///
/// **Three detents, and they are the point.** [welcomeDetents] opens at the
/// peek, where one stop is visible and the rest is a promise; the half shows
/// two; the full shows all three. A sheet with one height would have to choose
/// between covering the screen it is previewing and being too short to preview
/// anything.
///
/// Opens the preview; returns when the sheet is dismissed.
Future<void> showWelcomeSheet(BuildContext context) {
  AppHaptics.light();
  return showDSBottomSheet<void>(
    context: context,
    header: const DSSheetHeader(
      title: 'What’s inside',
      subtitle: 'The three stops the tour runs.',
    ),
    snapPoints: welcomeDetents,
    snapLabels: welcomeDetentLabels,
    initialSnap: welcomeDetents.first,
    builder: (BuildContext context) => const WelcomeSheetBody(),
  );
}

/// The sheet's content, in its own widget so a test can mount it without a
/// route and the goldens can picture it beside the page it belongs to.
class WelcomeSheetBody extends StatelessWidget {
  const WelcomeSheetBody({super.key});

  @override
  Widget build(BuildContext context) {
    final SpaceSpec space = context.design.space;
    final TextTheme text = Theme.of(context).textTheme;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        DSGutter.of(context),
        space.md,
        DSGutter.of(context),
        space.xl,
      ),
      itemCount: onboardingStops.length,
      separatorBuilder: (BuildContext context, int index) =>
          SizedBox(height: space.lg),
      itemBuilder: (BuildContext context, int index) {
        final DSTourStop stop = onboardingStops[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // `active: true` because every row is on screen at once here.
            // The tour's art animates in as its slide arrives; a list has no
            // arrival, so the drawings are simply drawn.
            DSTourCanvas(child: stop.art(true)),
            SizedBox(width: space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(stop.headline, style: text.titleMedium),
                  SizedBox(height: space.xs),
                  DSText(stop.body, role: DSTextRole.bodySupport),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
