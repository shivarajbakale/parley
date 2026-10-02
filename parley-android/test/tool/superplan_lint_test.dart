import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/super_plan.dart';
import '../../tool/superplan_lint.dart';

/// The gate is pointed at a temporary tree rather than at this repository, so
/// each rule can be shown failing without breaking the project it protects. A
/// lint only ever exercised by damaging the real tree is a lint nobody
/// exercises.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('superplan_lint_test');
    Directory('${root.path}/lib').createSync();
    // Copy the generated DS catalog into the test root so S6 stays quiet
    // for the valid fixtures; tests that exercise the missing-catalog
    // failure path delete this file before running.
    Directory('${root.path}/tool/fixtures').createSync(recursive: true);
    File('${root.path}/tool/fixtures/ds-catalog.json').writeAsStringSync(
      File('tool/fixtures/ds-catalog.json').readAsStringSync(),
    );
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'feature-001', 'status': 'in_progress', 'notes': 'TODO stub'},
        ],
      }),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  Map<String, Object?> validSuperPlan({List<String>? tabNames}) => {
    'app': {
      'name': 'X',
      'oneLiner': 'x',
      'problem': 'p',
      'targetUsers': 'u',
      'industry': 'productivity',
      'mvp': {
        'in': ['a'],
        'out': <String>[],
      },
    },
    'decisions': [
      {'question': 'Does it need auth?', 'answer': 'No', 'source': 'user'},
    ],
    'navigation': {
      'tabs': tabNames ?? ['Home'],
      'ascii': 'home',
    },
    'modules': {
      'auth': 'none',
      'onboarding': 'none',
      'paywall': 'none',
      'analytics': 'none',
      'push': 'none',
    },
    'routes': [
      {
        'id': 'home',
        'route': '/',
        'name': 'Home',
        'tab': tabNames?.first ?? 'Home',
        'archetype': 'form',
        'primaryAction': 'Save',
        'purpose': 'home',
        'lookAndFeel': {
          'panels': [
            {
              'fields': [
                {'label': 'x', 'placeholder': 'y'},
              ],
            },
          ],
        },
        // New-shape (flutter-045): every route carries top-level
        // `components[]` and `layout`. Form archetype cites DSTextField +
        // DSPinnedActionBar so S7 stays quiet.
        'components': [
          {
            'kit': 'DSTextField',
            'purpose': 'edit a value',
            'region': 'body.form',
            'why': 'the kit owns the label / helper / validation contract',
          },
          {
            'kit': 'DSPinnedActionBar',
            'purpose': 'Save above safe area',
            'region': 'footer',
            'why': 'the Form archetype only legal primary placement',
          },
        ],
        'layout': {
          'regions': [
            {'name': 'header', 'kit': 'DSCompactAppBar'},
            {
              'name': 'body.form',
              'kits': ['DSTextField'],
            },
            {'name': 'footer', 'kit': 'DSPinnedActionBar'},
          ],
          'pinned': ['header', 'footer'],
        },
        'states': {'loading': 'x', 'empty': 'x', 'error': 'x', 'success': 'x'},
        'sprint': {'order': 1, 'size': 'S'},
      },
    ],
  };

  void writeSuperPlan(Map<String, Object?> plan) =>
      File('${root.path}/SUPERPLAN.json').writeAsStringSync(jsonEncode(plan));

  void writeRendered(String md) =>
      File('${root.path}/SUPERPLAN.md').writeAsStringSync(md);

  String rulesOf(List<Violation> v) => v.map((x) => x.rule).join(',');

  test('a project with no superplan has nothing to say', () {
    // Inert on a fresh scaffold. A gate that fails before anybody has planned
    // anything is a gate people disable on day one.
    expect(lintSuperPlans(root), isEmpty);
  });

  test('a superplan that will not validate fails S1', () {
    writeSuperPlan({'app': null, 'routes': []});
    final v = lintSuperPlans(root);
    expect(rulesOf(v), contains('S1'));
  });

  test('a superplan that is not JSON fails S1 with the parse error', () {
    File('${root.path}/SUPERPLAN.json').writeAsStringSync('{ nope');
    final v = lintSuperPlans(root);
    expect(rulesOf(v), 'S1');
    expect(v.single.message, contains('not valid JSON'));
  });

  test('a valid, registered, freshly rendered superplan passes', () {
    writeSuperPlan(validSuperPlan());
    writeRendered(
      renderSuperPlanMarkdown(
        jsonDecode(File('${root.path}/SUPERPLAN.json').readAsStringSync())
            as Map<String, Object?>,
      ),
    );
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {
            'id': 'feature-001',
            'status': 'passing',
            'notes': 'First feature. route:home',
          },
        ],
      }),
    );
    expect(lintSuperPlans(root), isEmpty);
  });

  test('a hand-edited SUPERPLAN.md fails S2', () {
    writeSuperPlan(validSuperPlan());
    writeRendered('Someone fixed a typo in the rendered doc.\n');
    // Register the home route so S4 does not fire ahead of S2 — the lint
    // catches the hand-edit before it gets to "and what track is this on".
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {
            'id': 'feature-001',
            'status': 'passing',
            'notes': 'Built route:home already.',
          },
        ],
      }),
    );
    final v = lintSuperPlans(root);
    expect(rulesOf(v), 'S2');
    expect(v.single.message, contains('does not match a fresh render'));
  });

  test('an orphan SUPERPLAN.md fails S3', () {
    writeRendered('Rendered doc with no source.\n');
    final v = lintSuperPlans(root);
    expect(rulesOf(v), 'S3');
    expect(v.single.message, contains('no SUPERPLAN.json'));
  });

  test('a route with no feature and no deferral fails S4', () {
    writeSuperPlan(validSuperPlan());
    writeRendered(
      renderSuperPlanMarkdown(
        jsonDecode(File('${root.path}/SUPERPLAN.json').readAsStringSync())
            as Map<String, Object?>,
      ),
    );
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'feature-001', 'status': 'in_progress', 'notes': 'TODO stub'},
        ],
      }),
    );
    final v = lintSuperPlans(root);
    expect(rulesOf(v), 'S4');
    expect(v.single.message, contains('home'));
  });

  test('a route that is deferred via app.mvp.out does not fail S4', () {
    final p = validSuperPlan();
    (p['app'] as Map)['mvp'] = {
      'in': ['a'],
      'out': ['route:home'],
    };
    writeSuperPlan(p);
    writeRendered(
      renderSuperPlanMarkdown(
        jsonDecode(File('${root.path}/SUPERPLAN.json').readAsStringSync())
            as Map<String, Object?>,
      ),
    );
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'feature-001', 'status': 'in_progress', 'notes': 'TODO stub'},
        ],
      }),
    );
    expect(lintSuperPlans(root), isEmpty);
  });

  test('a deferral that explains itself still defers', () {
    // Authors write `route:x — why it is deferred`, because the reason is
    // the useful half. Matching the token exactly meant an explained
    // deferral did not defer, and S4 then told the author to do the thing
    // they had already done.
    final p = validSuperPlan();
    (p['app'] as Map)['mvp'] = {
      'in': ['a'],
      'out': [
        'route:home — needs accounts and a moderation story; not before v2',
      ],
    };
    writeSuperPlan(p);
    writeRendered(
      renderSuperPlanMarkdown(
        jsonDecode(File('${root.path}/SUPERPLAN.json').readAsStringSync())
            as Map<String, Object?>,
      ),
    );
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'feature-001', 'status': 'in_progress', 'notes': 'TODO stub'},
        ],
      }),
    );
    expect(lintSuperPlans(root), isEmpty);
  });

  test('a feature that references a route that does not exist fails S5', () {
    writeSuperPlan(validSuperPlan());
    writeRendered(
      renderSuperPlanMarkdown(
        jsonDecode(File('${root.path}/SUPERPLAN.json').readAsStringSync())
            as Map<String, Object?>,
      ),
    );
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {
            'id': 'feature-001',
            'status': 'passing',
            'notes': 'Built route:home already; also tried route:ghost',
          },
        ],
      }),
    );
    final v = lintSuperPlans(root);
    expect(rulesOf(v), contains('S5'));
    expect(v.firstWhere((x) => x.rule == 'S5').message, contains('ghost'));
  });

  test('S6: missing catalog fails the lint', () {
    File('${root.path}/tool/fixtures/ds-catalog.json').deleteSync();
    writeSuperPlan(validSuperPlan());
    writeRendered(
      renderSuperPlanMarkdown(
        jsonDecode(File('${root.path}/SUPERPLAN.json').readAsStringSync())
            as Map<String, Object?>,
      ),
    );
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'f-1', 'status': 'passing', 'notes': 'route:home'},
        ],
      }),
    );
    final v = lintSuperPlans(root);
    expect(rulesOf(v), contains('S6'));
    expect(
      v.firstWhere((x) => x.rule == 'S6').message,
      contains('make ds-catalog'),
    );
  });

  test('S7: form archetype missing DSPinnedActionBar fails the lint', () {
    final plan = validSuperPlan();
    final routes = (plan['routes'] as List).cast<Map<String, Object?>>();
    routes[0]['components'] = [
      {
        'kit': 'DSTextField',
        'purpose': 'edit',
        'region': 'body.form',
        'why': 'the kit owns the label / helper contract',
      },
      // DSPinnedActionBar deliberately absent.
    ];
    routes[0]['layout'] = {
      'regions': [
        {'name': 'header', 'kit': 'DSCompactAppBar'},
        {
          'name': 'body.form',
          'kits': ['DSTextField'],
        },
      ],
    };
    writeSuperPlan(plan);
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'f-1', 'status': 'passing', 'notes': 'route:home'},
        ],
      }),
    );
    final v = lintSuperPlans(root).where((x) => x.rule == 'S7').toList();
    expect(v.length, 1, reason: 'expected exactly one S7 violation');
    expect(v.single.message, contains('DSPinnedActionBar'));
  });

  test('S7: collection archetype missing DSDismissibleTile fails', () {
    final plan = validSuperPlan(tabNames: ['Home']);
    plan['routes'] = [
      {
        'id': 'list',
        'route': '/list',
        'name': 'List',
        'tab': 'Home',
        'archetype': 'collection',
        'primaryAction': 'Add',
        'purpose': 'list stuff',
        'lookAndFeel': {
          'panels': [
            {
              'kind': 'list',
              'search': 'q',
              'filters': ['All'],
              'swipe': 'archive',
              'swipeTwin': 'overflow',
              'rows': [
                ['a', '1'],
              ],
            },
          ],
        },
        'components': [
          {
            'kit': 'DSSearchBar',
            'purpose': 'q',
            'region': 'body.scroll',
            'why': 'in-place search',
          },
          // DSDismissibleTile deliberately absent.
        ],
        'layout': {
          'regions': [
            {'name': 'header', 'kit': 'DSCompactAppBar'},
            {
              'name': 'body.list',
              'kits': ['DSSearchBar'],
            },
          ],
        },
        'states': {
          'loading': 'l',
          'empty': 'e',
          'error': 'r',
          'success': 's',
          'zeroResults': 'nothing',
        },
        'sprint': {'order': 1, 'size': 'S'},
      },
    ];
    writeSuperPlan(plan);
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'f-1', 'status': 'passing', 'notes': 'route:list'},
        ],
      }),
    );
    final v = lintSuperPlans(root).where((x) => x.rule == 'S7').toList();
    expect(
      v.length,
      greaterThanOrEqualTo(1),
      reason: 'expected at least one S7 violation',
    );
    expect(v.first.message, contains('DSDismissibleTile'));
  });

  test('S7: insight archetype missing DSChart fails', () {
    // The plot is the archetype. An insight that cites no chart is a stat
    // tile with a paragraph under it, whatever the plan calls it.
    final plan = validSuperPlan(tabNames: ['Home']);
    plan['routes'] = [
      {
        'id': 'recap',
        'route': '/recap',
        'name': 'Your week',
        'tab': 'Home',
        'archetype': 'insight',
        'purpose': 'hand the week back',
        'headline': '4h 12m',
        'comparison': '18% more than last week',
        'period': 'Mon 25 to Sun 31 August',
        'reading': 'Tuesday carried the week.',
        'handover': '/library',
        'lookAndFeel': {
          'panels': [
            {'kind': 'chart', 'title': 'Minutes per day'},
          ],
        },
        'components': [
          {
            'kit': 'DSStatTile',
            'purpose': 'the figure',
            'region': 'body.figure',
            'why': 'the value, its delta and its note in one block',
          },
          // DSChart deliberately absent.
        ],
        'layout': {
          'regions': [
            {'name': 'header', 'kit': 'DSCompactAppBar'},
            {
              'name': 'body.figure',
              'kits': ['DSStatTile'],
            },
          ],
        },
        'states': {'loading': 'l', 'empty': 'e', 'error': 'r', 'success': 's'},
        'sprint': {'order': 1, 'size': 'S'},
      },
    ];
    writeSuperPlan(plan);
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'f-1', 'status': 'passing', 'notes': 'route:recap'},
        ],
      }),
    );
    final v = lintSuperPlans(root).where((x) => x.rule == 'S7').toList();
    expect(
      v.length,
      greaterThanOrEqualTo(1),
      reason: 'expected at least one S7 violation',
    );
    expect(v.first.message, contains('DSChart'));
  });

  test('S7: schedule archetype missing DSDateStrip fails', () {
    // The grid is the archetype and the strip is how another day is reached.
    // A schedule that cites neither is an agenda, and an agenda is a
    // collection.
    final plan = validSuperPlan(tabNames: ['Home']);
    plan['routes'] = [
      {
        'id': 'day',
        'route': '/day',
        'name': 'Today',
        'tab': 'Home',
        'archetype': 'schedule',
        'purpose': 'show the shape of the day',
        'window': '08:00 to 20:00, widened by anything outside it',
        'empty': 'Nothing today. Add the first thing.',
        'create': 'the plus in the header opens a new event',
        'lookAndFeel': {
          'panels': [
            {'kind': 'day', 'slots': []},
          ],
        },
        'components': [
          {
            'kit': 'DSTimeGrid',
            'purpose': 'the day',
            'region': 'body.day',
            'why': 'the shape of the day is read from the grid',
          },
          // DSDateStrip deliberately absent.
        ],
        'layout': {
          'regions': [
            {'name': 'header', 'kit': 'DSCompactAppBar'},
            {
              'name': 'body.day',
              'kits': ['DSTimeGrid'],
            },
          ],
        },
        'states': {'loading': 'l', 'empty': 'e', 'error': 'r', 'success': 's'},
        'sprint': {'order': 1, 'size': 'S'},
      },
    ];
    writeSuperPlan(plan);
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'f-1', 'status': 'passing', 'notes': 'route:day'},
        ],
      }),
    );
    final v = lintSuperPlans(root).where((x) => x.rule == 'S7').toList();
    expect(v.length, greaterThanOrEqualTo(1));
    expect(v.first.message, contains('DSDateStrip'));
  });

  test('S7: conversation archetype missing DSComposer fails', () {
    // The composer is the archetype. A thread whose input is a `DSTextField`
    // in the body is a form with a transcript above it.
    final plan = validSuperPlan(tabNames: ['Home']);
    plan['routes'] = [
      {
        'id': 'thread',
        'route': '/thread',
        'name': 'Thread',
        'tab': 'Home',
        'archetype': 'conversation',
        'purpose': 'answer the question the user asked',
        'composer': 'Message',
        'retry': 'Try again',
        'empty': 'Ask anything',
        'lookAndFeel': {
          'panels': [
            {
              'kind': 'transcript',
              'title': 'Thread',
              'turns': [
                {'author': 'them', 'text': 'One'},
                {'author': 'me', 'text': 'Two'},
              ],
            },
          ],
        },
        'components': [
          {
            'kit': 'DSChatBubble',
            'purpose': 'one turn',
            'region': 'body.thread',
            'why': 'the side and the state are how a transcript is read',
          },
          // DSComposer deliberately absent.
        ],
        'layout': {
          'regions': [
            {'name': 'header', 'kit': 'DSCompactAppBar'},
            {
              'name': 'body.thread',
              'kits': ['DSChatBubble'],
            },
          ],
        },
        'states': {'loading': 'l', 'empty': 'e', 'error': 'r', 'success': 's'},
        'sprint': {'order': 1, 'size': 'S'},
      },
    ];
    writeSuperPlan(plan);
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'f-1', 'status': 'passing', 'notes': 'route:thread'},
        ],
      }),
    );
    final v = lintSuperPlans(root).where((x) => x.rule == 'S7').toList();
    expect(
      v.length,
      greaterThanOrEqualTo(1),
      reason: 'expected at least one S7 violation',
    );
    expect(v.first.message, contains('DSComposer'));
  });

  test('S7: shelf archetype missing DSMediaTile fails', () {
    // The rail is the archetype, and the tile is what a rail is made of. A
    // shelf whose rails cite `DSCard` is a dashboard laid sideways.
    final plan = validSuperPlan(tabNames: ['Home']);
    plan['routes'] = [
      {
        'id': 'browse',
        'route': '/browse',
        'name': 'Browse',
        'tab': 'Home',
        'archetype': 'shelf',
        'purpose': 'what the app chose, ranked',
        'lookAndFeel': {
          'panels': [
            {
              'kind': 'rail',
              'title': 'Continue watching',
              'items': ['A', 'B'],
            },
            {
              'kind': 'rail',
              'title': 'New this week',
              'items': ['C', 'D'],
            },
          ],
        },
        'components': [
          {
            'kit': 'DSMediaHero',
            'purpose': 'the featured item',
            'region': 'body.hero',
            'why': 'one item the screen leads with',
          },
          // DSMediaTile deliberately absent.
        ],
        'layout': {
          'regions': [
            {'name': 'header', 'kit': 'DSCompactAppBar'},
            {
              'name': 'body.hero',
              'kits': ['DSMediaHero'],
            },
          ],
        },
        'states': {'loading': 'l', 'empty': 'e', 'error': 'r', 'success': 's'},
        'sprint': {'order': 1, 'size': 'S'},
      },
    ];
    writeSuperPlan(plan);
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'f-1', 'status': 'passing', 'notes': 'route:browse'},
        ],
      }),
    );
    final v = lintSuperPlans(root).where((x) => x.rule == 'S7').toList();
    expect(
      v.length,
      greaterThanOrEqualTo(1),
      reason: 'expected at least one S7 violation',
    );
    expect(v.first.message, contains('DSMediaTile'));
  });

  test('S7: session archetype missing DSMediaSurface fails', () {
    // A session draws playback state, and `DSMediaSurface` is the only thing
    // in the kit that does. A player built from `DSImage` has no state to
    // show and no place to show it.
    final plan = validSuperPlan(tabNames: ['Home']);
    plan['routes'] = [
      {
        'id': 'player',
        'route': '/player',
        'name': 'Now playing',
        'tab': 'Home',
        'archetype': 'session',
        'purpose': 'the thing that is happening',
        'nowPlaying': 'Release 4.2 — Changelog',
        'transport': ['Back 15', 'Play', 'Forward 30'],
        'escape': 'A down-chevron; the audio keeps playing',
        'lookAndFeel': {
          'panels': [
            {'kind': 'stage', 'title': 'Release 4.2'},
          ],
        },
        'components': [
          {
            'kit': 'DSSlider',
            'purpose': 'the scrubber',
            'region': 'body.transport',
            'why': 'a seek target at the 44-point floor',
          },
          // DSMediaSurface deliberately absent.
        ],
        'layout': {
          'regions': [
            {'name': 'header', 'kit': 'DSCompactAppBar'},
            {
              'name': 'body.transport',
              'kits': ['DSSlider'],
            },
          ],
        },
        'states': {'loading': 'l', 'empty': 'e', 'error': 'r', 'success': 's'},
        'sprint': {'order': 1, 'size': 'S'},
      },
    ];
    writeSuperPlan(plan);
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'f-1', 'status': 'passing', 'notes': 'route:player'},
        ],
      }),
    );
    final v = lintSuperPlans(root).where((x) => x.rule == 'S7').toList();
    expect(
      v.length,
      greaterThanOrEqualTo(1),
      reason: 'expected at least one S7 violation',
    );
    expect(v.first.message, contains('DSMediaSurface'));
  });

  test('S7: offer archetype missing DSPinnedActionBar fails', () {
    // However the plan rows are drawn, the primary is pinned. A purchase
    // button that scrolls away is one the user hunts for, and a paywall's
    // whole job is that they do not.
    final plan = validSuperPlan(tabNames: ['Home']);
    plan['routes'] = [
      {
        'id': 'paywall',
        'route': '/paywall',
        'name': 'Go Pro',
        'tab': 'Home',
        'archetype': 'offer',
        'purpose': 'sell the subscription',
        'outcome': 'every note, on every device, with no cap',
        'primaryAction': 'Start 7-day free trial',
        'billing': 'GBP 39 a year from 14 March. Cancel in Settings.',
        'restore': 'Restore purchases',
        'terms': 'Terms and Privacy',
        'lookAndFeel': {
          'panels': [
            {
              'kind': 'plans',
              'title': 'Choose a plan',
              'plans': [
                {'period': 'Yearly', 'price': 'GBP 39'},
                {'period': 'Monthly', 'price': 'GBP 4.99'},
              ],
            },
          ],
        },
        'components': [
          {
            'kit': 'DSCard',
            'purpose': 'plan row',
            'region': 'body.plans',
            'why': 'a selectable row at card weight',
          },
          // DSPinnedActionBar deliberately absent.
        ],
        'layout': {
          'regions': [
            {'name': 'header', 'kit': 'DSCompactAppBar'},
            {
              'name': 'body.plans',
              'kits': ['DSCard'],
            },
          ],
        },
        'states': {'loading': 'l', 'empty': 'e', 'error': 'r', 'success': 's'},
        'sprint': {'order': 1, 'size': 'S'},
      },
    ];
    writeSuperPlan(plan);
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'f-1', 'status': 'passing', 'notes': 'route:paywall'},
        ],
      }),
    );
    final v = lintSuperPlans(root).where((x) => x.rule == 'S7').toList();
    expect(
      v.length,
      greaterThanOrEqualTo(1),
      reason: 'expected at least one S7 violation',
    );
    expect(v.first.message, contains('DSPinnedActionBar'));
  });

  group('S8: the interview happened', () {
    void registerHome() {
      File('${root.path}/feature_list.json').writeAsStringSync(
        jsonEncode({
          'features': [
            {'id': 'feature-001', 'status': 'passing', 'notes': 'route:home'},
          ],
        }),
      );
    }

    void render(Map<String, Object?> p) {
      writeSuperPlan(p);
      writeRendered(
        renderSuperPlanMarkdown(
          jsonDecode(File('${root.path}/SUPERPLAN.json').readAsStringSync())
              as Map<String, Object?>,
        ),
      );
      registerHome();
    }

    test('a plan with no decisions[] at all fails S8', () {
      // This is the state every superplan was in before this rule existed:
      // valid, rendered, gated — and written without asking anyone.
      final p = validSuperPlan();
      p.remove('decisions');
      render(p);
      expect(lintSuperPlans(root).join('\n'), contains('no `decisions[]`'));
    });

    test('a plan where every decision is assumed fails S8', () {
      final p = validSuperPlan();
      p['decisions'] = [
        {
          'question': 'Does it need auth?',
          'answer': 'No',
          'source': 'assumed',
          'why': 'Nothing in the MVP needs an identity',
        },
      ];
      render(p);
      expect(
        lintSuperPlans(root).join('\n'),
        contains('without asking them anything'),
      );
    });

    test('one user-answered decision is enough to pass S8', () {
      final p = validSuperPlan();
      p['decisions'] = [
        {'question': 'Does it need auth?', 'answer': 'No', 'source': 'user'},
        {
          'question': 'Offline?',
          'answer': 'Yes',
          'source': 'assumed',
          'why': 'The library is useless without it',
        },
      ];
      render(p);
      expect(lintSuperPlans(root), isEmpty);
    });
  });
}
