import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The three drawings on the template's own tour.
///
/// **Replace these.** They are drawings of a generic app — a list, a detail,
/// a settled state — and the whole argument for drawing a tour in Flutter
/// rather than shipping a screenshot is that the picture is of *your* product.
/// See `.claude/skills/add-tour/SKILL.md`.
///
/// What is worth keeping is the shape: every piece is composed inside a
/// [DSTourCanvas] so it never reflows, every element is drawn still rather
/// than animated in,
/// and every colour comes from the palette.
class OnboardingListArt extends StatelessWidget {
  const OnboardingListArt({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final space = context.design.space;

    return DSTourCanvas(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.all(
            Radius.circular(context.radiusOf(AppShape.card)),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < 4; i++) ...<Widget>[
                if (i > 0) SizedBox(height: space.sm),
                _Row(space: space, emphasis: i == 0),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the drawn list.
class _Row extends StatelessWidget {
  const _Row({required this.space, required this.emphasis});

  final SpaceSpec space;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasis ? palette.secondary : palette.background,
        borderRadius: BorderRadius.all(
          Radius.circular(context.radiusOf(AppShape.tile)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(space.md),
        child: Row(
          children: <Widget>[
            Container(
              width: space.xl,
              height: space.xl,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: emphasis ? 0.9 : 0.2),
                borderRadius: BorderRadius.all(
                  Radius.circular(context.radiusOf(AppShape.control)),
                ),
              ),
            ),
            SizedBox(width: space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Rule(space: space, widthFactor: 0.7),
                  SizedBox(height: space.xs),
                  _Rule(space: space, widthFactor: 0.4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A drawn line of text.
class _Rule extends StatelessWidget {
  const _Rule({required this.space, required this.widthFactor});

  final SpaceSpec space;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: Container(
        height: space.sm,
        decoration: BoxDecoration(
          color: palette.foreground.withValues(alpha: 0.12),
          borderRadius: BorderRadius.all(
            Radius.circular(context.radiusOf(AppShape.pill)),
          ),
        ),
      ),
    );
  }
}

/// Slide two: the same object, opened.
class OnboardingDetailArt extends StatelessWidget {
  const OnboardingDetailArt({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final space = context.design.space;

    return DSTourCanvas(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.all(
            Radius.circular(context.radiusOf(AppShape.card)),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: space.xxxl * 2,
                decoration: BoxDecoration(
                  color: palette.secondary,
                  borderRadius: BorderRadius.all(
                    Radius.circular(context.radiusOf(AppShape.card)),
                  ),
                ),
              ),
              SizedBox(height: space.lg),
              for (int i = 0; i < 3; i++) ...<Widget>[
                if (i > 0) SizedBox(height: space.sm),
                _Rule(space: space, widthFactor: i == 2 ? 0.5 : 1),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Slide three: the blank app filling in with what the user gives it. This is
/// the one that uses [DSTourFillSlot], and it is the argument for the tour —
/// the app *after* is not the app *before*.
class OnboardingSetupArt extends StatelessWidget {
  const OnboardingSetupArt({super.key, required this.active});

  final bool active;

  static const List<String> _answers = <String>[
    'Ada Lovelace',
    'ada@rocketship.dev',
    'Weekly digest',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final space = context.design.space;
    final MotionSpec motion = context.design.motion;

    return DSTourCanvas(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.all(
            Radius.circular(context.radiusOf(AppShape.card)),
          ),
          border: Border.all(color: palette.borderSoft),
        ),
        child: Padding(
          padding: EdgeInsets.all(space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final (int i, String answer)
                  in _answers.indexed) ...<Widget>[
                if (i > 0) SizedBox(height: space.lg),
                SizedBox(
                  height: space.xl,
                  child: DSTourFillSlot(
                    active: active,
                    delay: motion.revealStep * (i + 1),
                    placeholderWidth: space.xxxl * 2,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DSText(answer, role: DSTextRole.body),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
