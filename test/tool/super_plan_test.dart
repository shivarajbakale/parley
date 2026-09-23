import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/super_plan.dart';

/// A validator whose own behaviour is unverified is a validator that quietly
/// stops rejecting. These tests say what the superplan validator refuses,
/// what it deliberately allows, and — the part a reader cannot check by eye —
/// that every frame it draws is square.
void main() {
  Map<String, Object?> jsonOf(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

  Map<String, Object?> route(
    String id,
    String archetype, {
    List<Object?> panels = const [],
    Map<String, Object?>? states,
    Map<String, Object?>? bestPractices,
    Map<String, Object?>? sprint,
    Map<String, Object?>? apis,
    Map<String, Object?>? lookAndFeel,
    String? tab,
    Map<String, Object?>? extra,
    List<Object?>? components,
    Map<String, Object?>? layout,
  }) {
    final s = <String, Object?>{
      'id': id,
      'route': '/$id',
      'name': id,
      'archetype': archetype,
      'purpose': 'purpose',
      if (tab != null) 'tab': tab,
      if (panels.isNotEmpty || lookAndFeel != null)
        'lookAndFeel': lookAndFeel ?? {'panels': panels},
      'states':
          states ??
          const {
            'loading': 'skeleton',
            'empty': 'nothing',
            'error': 'broke',
            'success': 'rendered',
          },
      if (bestPractices != null) 'bestPractices': bestPractices,
      if (sprint != null) 'sprint': sprint,
      if (apis != null) 'apis': apis,
      if (components != null) 'components': components,
      if (layout != null) 'layout': layout,
    };
    if (extra != null) s.addAll(extra);
    return s;
  }

  Map<String, Object?> plan(
    List<Object?> routes, {
    Map<String, Object?>? app,
  }) => {
    'app':
        app ??
        {
          'name': 'Test App',
          'oneLiner': 'one liner',
          'problem': 'problem',
          'targetUsers': 'who',
          'industry': 'productivity',
          'mvp': {
            'in': ['x'],
            'out': [],
          },
        },
    'navigation': {
      'tabs': <String>['Home'],
    },
    'modules': {
      'auth': 'none',
      'onboarding': 'none',
      'paywall': 'none',
      'analytics': 'none',
      'push': 'none',
    },
    'routes': routes,
  };

  group('the worked example', () {
    final fixture = jsonOf('tool/fixtures/habit-tracker.super-plan.json');

    test('validates', () {
      expect(validateSuperPlan(fixture), isEmpty);
    });

    test('renders every route', () {
      final md = renderSuperPlanMarkdown(fixture);
      final routes = (fixture['routes'] as List).length;
      final sections = '### '.allMatches(md).length;
      expect(sections, routes);
    });

    test('every phone-frame fence is square', () {
      // The phone frames and state grids are the rectangles that ship as the
      // review artifact. Other fences (navigation trees, file trees, blast
      // radius) are intentionally ragged because they are line-list
      // representations of structured data, not boxes. A frame that cannot
      // be diffed at a column-level is a frame that cannot be regenerated
      // safely, so this test only asserts on the ones that have to be
      // uniform.
      final md = renderSuperPlanMarkdown(fixture);
      final frameFences =
          RegExp(r'```\n(.*?)```', multiLine: true, dotAll: true)
              .allMatches(md)
              .map((m) => m.group(1)!)
              // The phone-frame fence starts with `┌` (box-drawing). State
              // grids do not (they are formed of joined boxes), so we check
              // phone frames here and trust the golden for the state grids.
              .where((f) => f.startsWith('┌'))
              .toList();
      expect(frameFences.length, greaterThanOrEqualTo(6));
      for (final f in frameFences) {
        final widths = f
            .split('\n')
            .where((l) => l.isNotEmpty)
            .map((l) => l.length)
            .toSet();
        expect(widths.length, 1, reason: 'phone frame has inconsistent widths');
      }
    });

    test('round-trips: render twice, compare bytes', () {
      final first = renderSuperPlanMarkdown(fixture);
      final second = renderSuperPlanMarkdown(fixture);
      expect(first, second);
    });

    test('matches the checked-in golden', () {
      // The golden is the review artifact: it is what a human reads when
      // they want to see what the renderer draws without running it. An
      // unread golden is a golden that silently rots, so this test is the
      // one reader that keeps it honest. Regenerate with:
      //   dart run tool/super_plan.dart tool/fixtures/habit-tracker.super-plan.json \
      //     -o tool/fixtures/super-plan-test/habit-tracker.SUPERPLAN.md
      final goldenFile = File(
        'tool/fixtures/super-plan-test/habit-tracker.SUPERPLAN.md',
      );
      expect(
        goldenFile.existsSync(),
        isTrue,
        reason: 'the worked example golden is missing',
      );
      expect(
        renderSuperPlanMarkdown(fixture),
        goldenFile.readAsStringSync(),
        reason: 'SUPERPLAN.md golden is stale — re-render the fixture',
      );
    });

    test('the golden carries the gesture and journey tables', () {
      // Sections the renderer draws but no rule required were invisible to
      // the suite until the fixture exercised them.
      final md = renderSuperPlanMarkdown(fixture);
      expect(md, contains('**Gestures ('));
      expect(md, contains('**Journeys ('));
    });
  });

  group('top-level shape', () {
    test('rejects a non-object', () {
      expect(validateSuperPlan('not an object'), [
        'plan must be a JSON object',
      ]);
    });

    test('rejects a plan with no app', () {
      final errors = validateSuperPlan({
        'navigation': {'tabs': []},
        'modules': {},
        'routes': [],
      });
      expect(errors, contains('app: required object'));
    });

    test('rejects a plan with no routes', () {
      final errors = validateSuperPlan({
        'app': {
          'name': 'x',
          'oneLiner': 'x',
          'problem': 'x',
          'targetUsers': 'x',
          'industry': 'x',
          'mvp': {'in': [], 'out': []},
        },
        'navigation': {'tabs': []},
        'modules': {
          'auth': 'none',
          'onboarding': 'none',
          'paywall': 'none',
          'analytics': 'none',
          'push': 'none',
        },
        'routes': [],
      });
      expect(errors.join('\n'), contains('routes: at least one required'));
    });

    test('a schedule route names its window, its empty day and how to add', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'day',
            'schedule',
            panels: const [
              {'kind': 'day', 'slots': []},
            ],
            sprint: const {'order': 1, 'size': 'S'},
          ),
        ]),
      );
      final joined = errors.join('\n');
      expect(joined, contains('.window: required'));
      expect(joined, contains('.empty: required'));
      expect(joined, contains('.create: required'));
    });

    test('an editor route says what saving, undo and leaving mean', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'note',
            'editor',
            panels: const [
              {'kind': 'document', 'title': 'Untitled note'},
            ],
            sprint: const {'order': 1, 'size': 'S'},
          ),
        ]),
      );
      final joined = errors.join('\n');
      expect(joined, contains('.autosave: required'));
      expect(joined, contains('.undo: required'));
      expect(joined, contains('.exit: required'));
    });

    test('a conversation route names its thread and its composer', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'thread',
            'conversation',
            panels: const [
              {
                'kind': 'transcript',
                'title': 'Thread',
                'turns': [
                  {'author': 'them', 'text': 'One'},
                  {'author': 'me', 'text': 'Two'},
                ],
              },
            ],
            sprint: const {'order': 1, 'size': 'S'},
          ),
        ]),
      );
      final joined = errors.join('\n');
      expect(joined, contains('.composer: required'));
      expect(joined, contains('.retry: required'));
      expect(joined, contains('.empty: required'));
    });

    test('a conversation with no transcript panel is not a conversation', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'thread',
            'conversation',
            panels: const [
              {'kind': 'section', 'title': 'Something else'},
            ],
            extra: const {
              'composer': 'Message',
              'retry': 'Try again',
              'empty': 'Say hello',
            },
            sprint: const {'order': 1, 'size': 'S'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('one panel of `kind: "transcript"`'));
    });

    test('rejects a missing module key', () {
      final p = plan([
        route(
          'h',
          'form',
          panels: [
            {
              'fields': [
                {'label': 'x', 'placeholder': 'y'},
              ],
            },
          ],
          sprint: {'order': 1, 'size': 'S'},
        ),
      ]);
      (p['modules'] as Map).remove('auth');
      final errors = validateSuperPlan(p);
      expect(errors.join('\n'), contains('modules.auth: required'));
    });

    test('rejects a module value that is not required/none/deferred', () {
      final p = plan([
        route(
          'h',
          'form',
          panels: [
            {
              'fields': [
                {'label': 'x', 'placeholder': 'y'},
              ],
            },
          ],
          sprint: {'order': 1, 'size': 'S'},
        ),
      ]);
      (p['modules'] as Map)['auth'] = 'sometimes';
      final errors = validateSuperPlan(p);
      expect(errors.join('\n'), contains('modules.auth'));
    });
  });

  group('V1: archetype + panel ownership', () {
    test('rejects focal without a hero', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'h',
            'focal',
            panels: [
              {'kind': 'tile', 'title': 'a'},
              {'kind': 'tile', 'title': 'b'},
              {'kind': 'tile', 'title': 'c'},
            ],
            sprint: {'order': 1, 'size': 'M'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('focal starts with one panel'));
    });

    test('rejects a bento of one tile size', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'h',
            'focal',
            panels: [
              {'kind': 'hero', 'title': 'hero'},
              {'kind': 'tile', 'title': 'a'},
              {'kind': 'tile', 'title': 'b'},
              {'kind': 'tile', 'title': 'c'},
            ],
            sprint: {'order': 1, 'size': 'M'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('bento needs two sizes'));
    });

    test('rejects an eighth archetype', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'h',
            'wizard',
            panels: [
              {'kind': 'section', 'title': 'a'},
            ],
            sprint: {'order': 1, 'size': 'M'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('must be one of focal'));
    });

    test('rejects a sequence of one step', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'tour',
            'sequence',
            panels: [
              {'kind': 'step', 'title': 'Welcome', 'job': 'brand'},
            ],
            sprint: {'order': 1, 'size': 'M'},
            extra: {
              'progress': 'a dot per stop',
              'back': 'keeps the answer',
              'handover': '/home',
              'primaryAction': 'Next',
            },
          ),
        ]),
      );
      expect(errors.join('\n'), contains('at least two panels'));
    });

    test('rejects a sequence step that cannot name its job', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'tour',
            'sequence',
            panels: [
              {'kind': 'step', 'title': 'Welcome', 'job': 'brand'},
              {'kind': 'step', 'title': 'Vibes', 'job': 'delight'},
            ],
            sprint: {'order': 1, 'size': 'M'},
            extra: {
              'progress': 'a dot per stop',
              'back': 'keeps the answer',
              'handover': '/home',
              'primaryAction': 'Next',
            },
          ),
        ]),
      );
      expect(errors.join('\n'), contains('panels[1].job: must be one of'));
    });

    test('rejects a sequence with nowhere to hand over to', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'tour',
            'sequence',
            panels: [
              {'kind': 'step', 'title': 'Welcome', 'job': 'brand'},
              {'kind': 'step', 'title': 'Goal', 'job': 'segmentation'},
            ],
            sprint: {'order': 1, 'size': 'M'},
            extra: {
              'progress': 'a dot per stop',
              'back': 'keeps the answer',
              'primaryAction': 'Next',
            },
          ),
        ]),
      );
      expect(errors.join('\n'), contains('handover: required'));
    });

    test('rejects an offer showing four plans', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'paywall',
            'offer',
            panels: [
              {
                'kind': 'plans',
                'title': 'Choose a plan',
                'plans': [
                  {'period': 'Yearly', 'price': 'GBP 39'},
                  {'period': 'Monthly', 'price': 'GBP 4.99'},
                  {'period': 'Quarterly', 'price': 'GBP 13'},
                  {'period': 'Lifetime', 'price': 'GBP 99'},
                ],
              },
            ],
            sprint: {'order': 1, 'size': 'M'},
            extra: {
              'outcome': 'every note, everywhere',
              'primaryAction': 'Start 7-day free trial',
              'billing': 'GBP 39 a year from 14 March',
              'restore': 'Restore purchases',
              'terms': 'Terms and Privacy',
            },
          ),
        ]),
      );
      expect(errors.join('\n'), contains('between 1 and 3 plans'));
    });

    test('rejects an offer with no billing disclosure', () {
      // The rule the whole archetype turns on: a renewal the pinned button
      // covers is one the user meets at the charge.
      final errors = validateSuperPlan(
        plan([
          route(
            'paywall',
            'offer',
            panels: [
              {
                'kind': 'plans',
                'title': 'Choose a plan',
                'plans': [
                  {'period': 'Yearly', 'price': 'GBP 39'},
                ],
              },
            ],
            sprint: {'order': 1, 'size': 'M'},
            extra: {
              'outcome': 'every note, everywhere',
              'primaryAction': 'Start 7-day free trial',
              'restore': 'Restore purchases',
              'terms': 'Terms and Privacy',
            },
          ),
        ]),
      );
      expect(errors.join('\n'), contains('billing: required'));
    });

    test('rejects a shelf of one rail', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'browse',
            'shelf',
            panels: [
              {
                'kind': 'rail',
                'title': 'Continue watching',
                'items': ['A', 'B'],
              },
            ],
            sprint: {'order': 1, 'size': 'M'},
          ),
        ]),
      );
      expect(
        errors.join('\n'),
        contains('at least two panels of `kind: "rail"`'),
      );
    });

    test('rejects a rail of nine tiles with no See all', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'browse',
            'shelf',
            panels: [
              {
                'kind': 'rail',
                'title': 'Continue watching',
                'items': ['A', 'B'],
              },
              {
                'kind': 'rail',
                'title': 'New this week',
                'items': ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'],
              },
            ],
            sprint: {'order': 1, 'size': 'M'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('needs `seeAll`'));
    });

    test('rejects a session that pins a primary', () {
      // The transport is the chrome. A pinned bar under a player is a second
      // bottom edge, and the two fight for the same 90 points.
      final errors = validateSuperPlan(
        plan([
          route(
            'player',
            'session',
            panels: [
              {'kind': 'stage', 'title': 'Release 4.2'},
            ],
            sprint: {'order': 1, 'size': 'M'},
            extra: {
              'nowPlaying': 'Release 4.2 — Changelog',
              'transport': ['Back 15', 'Play', 'Forward 30'],
              'escape': 'A down-chevron; the audio keeps playing',
              'primaryAction': 'Save',
            },
          ),
        ]),
      );
      expect(errors.join('\n'), contains('a session pins nothing'));
    });

    test('rejects a canvas sheet that settles at one height', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'map',
            'canvas',
            panels: [
              {'kind': 'ground', 'title': 'The map'},
              {
                'kind': 'sheet',
                'title': 'Nearby',
                'detents': ['full'],
                'peek': 'the pin stays visible',
              },
            ],
            sprint: {'order': 1, 'size': 'M'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('needs 2 to 3 named `detents`'));
    });

    test('rejects a confirmation with no identifier', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'placed',
            'confirmation',
            panels: [
              {'kind': 'receipt', 'title': '2 items · £34.98'},
            ],
            sprint: {'order': 1, 'size': 'M'},
            extra: {
              'outcome': 'Your order is placed',
              'next': 'Arrives Thursday 12 March',
              'handover': '/orders/RS-4821',
            },
          ),
        ]),
      );
      expect(errors.join('\n'), contains('reference: required'));
    });

    test('rejects an insight drawing two plots', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'recap',
            'insight',
            panels: [
              {'kind': 'chart', 'title': 'Minutes per day'},
              {'kind': 'chart', 'title': 'Minutes per shelf'},
            ],
            sprint: {'order': 1, 'size': 'M'},
            extra: {
              'headline': '4h 12m',
              'comparison': '18% more than last week',
              'period': 'Mon 25 to Sun 31 August',
              'reading': 'Tuesday carried the week.',
              'handover': '/library',
            },
          ),
        ]),
      );
      expect(errors.join('\n'), contains('insight is exactly 1 panel'));
    });

    test('rejects an insight that pins a primary', () {
      // An insight is read, not submitted. A pinned bar over a recap steals
      // the height the chart needs and implies a decision nobody asked for.
      final errors = validateSuperPlan(
        plan([
          route(
            'recap',
            'insight',
            panels: [
              {'kind': 'chart', 'title': 'Minutes per day'},
            ],
            sprint: {'order': 1, 'size': 'M'},
            extra: {
              'headline': '4h 12m',
              'comparison': '18% more than last week',
              'period': 'Mon 25 to Sun 31 August',
              'reading': 'Tuesday carried the week.',
              'handover': '/library',
              'primaryAction': 'Continue',
            },
          ),
        ]),
      );
      expect(errors.join('\n'), contains('an insight pins nothing'));
    });

    test('rejects an insight with a number and no reading of it', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'recap',
            'insight',
            panels: [
              {'kind': 'chart', 'title': 'Minutes per day'},
            ],
            sprint: {'order': 1, 'size': 'M'},
            extra: {
              'headline': '4h 12m',
              'comparison': '18% more than last week',
              'period': 'Mon 25 to Sun 31 August',
              'handover': '/library',
            },
          ),
        ]),
      );
      expect(errors.join('\n'), contains('reading: required'));
    });

    test('rejects collection without zeroResults', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'h',
            'collection',
            panels: [
              {
                'kind': 'list',
                'search': 'search',
                'filters': ['a'],
                'swipe': 'archive',
                'swipeTwin': 'overflow',
                'rows': [
                  ['a', '1'],
                ],
              },
            ],
            states: {
              'loading': 'x',
              'empty': 'x',
              'error': 'x',
              'success': 'x',
            },
            sprint: {'order': 1, 'size': 'M'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('zeroResults'));
    });
  });

  group('V2: four states', () {
    test('rejects a route missing the loading state', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'h',
            'form',
            panels: [
              {
                'fields': [
                  {'label': 'x', 'placeholder': 'y'},
                ],
              },
            ],
            states: {'empty': 'x', 'error': 'x', 'success': 'x'},
            sprint: {'order': 1, 'size': 'S'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('states.loading'));
    });
  });

  group('V3: endpoints + entities', () {
    test('rejects a duplicate endpoint across routes', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'a',
            'form',
            panels: [
              {
                'fields': [
                  {'label': 'x', 'placeholder': 'y'},
                ],
              },
            ],
            apis: {
              'endpoints': [
                {'method': 'GET', 'path': '/x', 'purpose': 'first'},
              ],
            },
            sprint: {'order': 1, 'size': 'S'},
          ),
          route(
            'b',
            'form',
            panels: [
              {
                'fields': [
                  {'label': 'x', 'placeholder': 'y'},
                ],
              },
            ],
            apis: {
              'endpoints': [
                {'method': 'GET', 'path': '/x', 'purpose': 'duplicate'},
              ],
            },
            sprint: {'order': 2, 'size': 'S'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('duplicate endpoint'));
    });

    test('rejects an entity ref that does not resolve', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'a',
            'form',
            panels: [
              {
                'fields': [
                  {'label': 'x', 'placeholder': 'y'},
                ],
              },
            ],
            apis: {
              'entities': ['Ghost'],
            },
            sprint: {'order': 1, 'size': 'S'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('Ghost'));
    });
  });

  group('V4: components need a why (new top-level components[])', () {
    test('rejects a too-short why', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'h',
            'form',
            panels: [
              {
                'fields': [
                  {'label': 'x', 'placeholder': 'y'},
                ],
              },
            ],
            components: [
              {
                'kit': 'DSButton',
                'purpose': 'p',
                'region': 'body.form',
                'why': 'short',
              },
            ],
            sprint: {'order': 1, 'size': 'S'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('why: required'));
    });

    test('rejects a missing kit', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'h',
            'form',
            panels: [
              {
                'fields': [
                  {'label': 'x', 'placeholder': 'y'},
                ],
              },
            ],
            components: [
              {
                'purpose': 'p',
                'region': 'body.form',
                'why': 'a long enough why statement here',
              },
            ],
            sprint: {'order': 1, 'size': 'S'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('kit: required'));
    });
  });

  group('V5: sprint.depends + order', () {
    test('rejects a depends that does not resolve', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'h',
            'form',
            panels: [
              {
                'fields': [
                  {'label': 'x', 'placeholder': 'y'},
                ],
              },
            ],
            sprint: {
              'order': 1,
              'size': 'S',
              'depends': ['does-not-exist'],
            },
          ),
        ]),
      );
      expect(errors.join('\n'), contains('does-not-exist'));
    });

    test('rejects a duplicate sprint.order', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'a',
            'form',
            panels: [
              {
                'fields': [
                  {'label': 'x', 'placeholder': 'y'},
                ],
              },
            ],
            sprint: {'order': 1, 'size': 'S'},
          ),
          route(
            'b',
            'form',
            panels: [
              {
                'fields': [
                  {'label': 'x', 'placeholder': 'y'},
                ],
              },
            ],
            sprint: {'order': 1, 'size': 'S'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('duplicate'));
    });

    test('rejects a sprint.size that is not S/M/L', () {
      final errors = validateSuperPlan(
        plan([
          route(
            'h',
            'form',
            panels: [
              {
                'fields': [
                  {'label': 'x', 'placeholder': 'y'},
                ],
              },
            ],
            sprint: {'order': 1, 'size': 'XL'},
          ),
        ]),
      );
      expect(errors.join('\n'), contains('S | M | L'));
    });
  });

  group('V6: navigation.tabs matches routes', () {
    test('rejects an unused tab', () {
      final p = plan([
        route(
          'h',
          'form',
          tab: 'Today',
          panels: [
            {
              'fields': [
                {'label': 'x', 'placeholder': 'y'},
              ],
            },
          ],
          sprint: {'order': 1, 'size': 'S'},
        ),
      ]);
      (p['navigation'] as Map)['tabs'] = ['Today', 'Unused'];
      final errors = validateSuperPlan(p);
      expect(errors.join('\n'), contains('Unused'));
    });

    test('rejects a route that uses an undeclared tab', () {
      final p = plan([
        route(
          'h',
          'form',
          tab: 'Phantom',
          panels: [
            {
              'fields': [
                {'label': 'x', 'placeholder': 'y'},
              ],
            },
          ],
          sprint: {'order': 1, 'size': 'S'},
        ),
      ]);
      (p['navigation'] as Map)['tabs'] = ['Today'];
      final errors = validateSuperPlan(p);
      expect(errors.join('\n'), contains('Phantom'));
    });
  });

  group('V8: kit references resolve to the catalog', () {
    test('rejects an unknown kit name', () {
      final p = plan([
        route(
          'h',
          'focal',
          panels: [
            {'kind': 'hero', 'title': 't', 'subtitle': 's'},
            {'kind': 'tile', 'title': 'a'},
            {'kind': 'wide', 'title': 'c'},
          ],
          components: [
            {
              'kit': 'DSDoesNotExist',
              'purpose': 'x',
              'region': 'body.bento',
              'why': 'a long-enough justification',
            },
          ],
          sprint: {'order': 1, 'size': 'S'},
        ),
      ]);
      final errors = validateSuperPlan(p);
      expect(errors.join('\n'), contains('DSDoesNotExist'));
    });

    test('accepts a known kit name', () {
      final p = plan([
        route(
          'h',
          'focal',
          panels: [
            {'kind': 'hero', 'title': 't', 'subtitle': 's'},
            {'kind': 'tile', 'title': 'a'},
            {'kind': 'wide', 'title': 'c'},
          ],
          components: [
            {
              'kit': 'DSListTile',
              'purpose': 'list row',
              'region': 'body.bento',
              'why': 'a long-enough justification',
            },
          ],
          sprint: {'order': 1, 'size': 'S'},
        ),
      ]);
      final errors = validateSuperPlan(p);
      expect(
        errors.where((e) => e.contains('kit')).toList(),
        isEmpty,
        reason: 'DSListTile should resolve via the catalog',
      );
    });
  });

  group('V9: region must be one of the known set', () {
    test('rejects an unknown region', () {
      final p = plan([
        route(
          'h',
          'focal',
          panels: [
            {'kind': 'hero', 'title': 't', 'subtitle': 's'},
            {'kind': 'tile', 'title': 'a'},
            {'kind': 'wide', 'title': 'c'},
          ],
          components: [
            {
              'kit': 'DSListTile',
              'purpose': 'x',
              'region': 'somewhere_else',
              'why': 'a long-enough justification',
            },
          ],
          sprint: {'order': 1, 'size': 'S'},
        ),
      ]);
      final errors = validateSuperPlan(p);
      expect(errors.join('\n'), contains('somewhere_else'));
    });

    test('accepts a known region', () {
      final p = plan([
        route(
          'h',
          'focal',
          panels: [
            {'kind': 'hero', 'title': 't', 'subtitle': 's'},
            {'kind': 'tile', 'title': 'a'},
            {'kind': 'wide', 'title': 'c'},
          ],
          components: [
            {
              'kit': 'DSListTile',
              'purpose': 'x',
              'region': 'body.bento',
              'why': 'a long-enough justification',
            },
          ],
          sprint: {'order': 1, 'size': 'S'},
        ),
      ]);
      final errors = validateSuperPlan(p);
      expect(errors.where((e) => e.contains('region')).toList(), isEmpty);
    });
  });

  group('V4b: layout regions', () {
    test('rejects a layout with no regions', () {
      final p = plan([
        route(
          'h',
          'focal',
          panels: [
            {'kind': 'hero', 'title': 't', 'subtitle': 's'},
            {'kind': 'tile', 'title': 'a'},
            {'kind': 'wide', 'title': 'c'},
          ],
          layout: <String, Object?>{},
          sprint: {'order': 1, 'size': 'S'},
        ),
      ]);
      final errors = validateSuperPlan(p);
      expect(errors.join('\n'), contains('layout.regions'));
    });

    test('accepts a layout with header + body + fab', () {
      final p = plan([
        route(
          'h',
          'focal',
          panels: [
            {'kind': 'hero', 'title': 't', 'subtitle': 's'},
            {'kind': 'tile', 'title': 'a'},
            {'kind': 'wide', 'title': 'c'},
          ],
          layout: {
            'regions': [
              {'name': 'header', 'kit': 'DSLargeAppBar'},
              {
                'name': 'body.scroll',
                'kits': ['DSListTile'],
              },
              {'name': 'fab', 'kit': 'DSFab'},
            ],
            'pinned': ['header', 'fab'],
          },
          sprint: {'order': 1, 'size': 'S'},
        ),
      ]);
      final errors = validateSuperPlan(p);
      expect(errors.where((e) => e.contains('layout')).toList(), isEmpty);
    });
  });

  group('migration back-compat', () {
    test(
      'a superplan with the legacy bestPractices.components[] is rejected',
      () {
        final p = plan([
          route(
            'h',
            'form',
            panels: [
              {
                'fields': [
                  {'label': 'x', 'placeholder': 'y'},
                ],
              },
            ],
            bestPractices: {
              'components': [
                {
                  'control': 'DSTextField',
                  'why': 'long enough',
                  'rejected': 'x',
                },
              ],
            },
            sprint: {'order': 1, 'size': 'S'},
          ),
        ]);
        final errors = validateSuperPlan(p);
        expect(errors.join('\n'), contains('bestPractices.components[]'));
        expect(errors.join('\n'), contains('pre-flutter-045'));
      },
    );
  });

  group('V4: components derived from panels', () {
    // `_routeComponents` lets an author who already drew the wireframe skip
    // repeating every kit. Nothing exercised it, so the two trees could
    // disagree about whether the derivation existed at all and still ship a
    // green suite.
    Map<String, Object?> derivedPlan() => plan([
      route(
        'h',
        'form',
        tab: 'Home',
        panels: [
          {
            'kind': 'field-set',
            'fields': [
              {'label': 'Habit name', 'placeholder': 'Drink water'},
            ],
          },
        ],
        components: const <Object?>[],
        sprint: {'order': 1, 'size': 'S'},
        extra: {'primaryAction': 'Save the habit'},
      ),
    ]);

    test('an empty components[] with panels[] is accepted', () {
      expect(validateSuperPlan(derivedPlan()), isEmpty);
    });

    test('an empty components[] with no panels[] is rejected', () {
      final p = plan([
        route(
          'h',
          'form',
          components: const <Object?>[],
          sprint: {'order': 1, 'size': 'S'},
        ),
      ]);
      expect(
        validateSuperPlan(p).join('\n'),
        contains('.components: required'),
      );
    });

    test('the render carries the derived kits, not an empty manifest', () {
      final md = renderSuperPlanMarkdown(derivedPlan());
      expect(md, contains('DSTextField'));
      expect(md, contains('Habit name'));
    });
  });

  group('V8: gestures are shaped', () {
    Map<String, Object?> withGestures(List<Object?> gestures) => plan([
      route(
        'h',
        'form',
        panels: [
          {
            'fields': [
              {'label': 'x', 'placeholder': 'y'},
            ],
          },
        ],
        sprint: {'order': 1, 'size': 'S'},
        extra: {'gestures': gestures},
      ),
    ]);

    test('a gesture with no behavior is rejected', () {
      final errors = validateSuperPlan(
        withGestures([
          {'selector': 'DSListTile', 'event': 'tap'},
        ]),
      );
      expect(errors.join('\n'), contains('gestures[0].behavior: required'));
    });

    test('a gesture that is not an object is rejected', () {
      final errors = validateSuperPlan(withGestures(['tap it']));
      expect(errors.join('\n'), contains('gestures[0]: must be an object'));
    });

    test('a complete gesture passes', () {
      final errors = validateSuperPlan(
        withGestures([
          {
            'selector': 'DSListTile',
            'event': 'tap',
            'behavior': 'pushes the detail route',
          },
        ]),
      );
      expect(errors.where((e) => e.contains('gestures')).toList(), isEmpty);
    });
  });

  group('V9: journeys are shaped', () {
    Map<String, Object?> withJourneys(List<Object?> journeys) => plan([
      route(
        'h',
        'form',
        panels: [
          {
            'fields': [
              {'label': 'x', 'placeholder': 'y'},
            ],
          },
        ],
        sprint: {'order': 1, 'size': 'S'},
        extra: {'journeys': journeys},
      ),
    ]);

    test('a journey with no trace is rejected', () {
      final errors = validateSuperPlan(
        withJourneys([
          {'name': 'Create a habit'},
        ]),
      );
      expect(errors.join('\n'), contains('journeys[0].trace: required'));
    });

    test('a journey with no name is rejected', () {
      final errors = validateSuperPlan(
        withJourneys([
          {'trace': '/a -> /b'},
        ]),
      );
      expect(errors.join('\n'), contains('journeys[0].name: required'));
    });

    test('a complete journey passes', () {
      final errors = validateSuperPlan(
        withJourneys([
          {'name': 'Create a habit', 'trace': '/habits -> /habit/new -> save'},
        ]),
      );
      expect(errors.where((e) => e.contains('journeys')).toList(), isEmpty);
    });
  });

  group('dependencies carry their justification', () {
    test('a dependency renders its `why`, not just its name', () {
      // `dependencies[]` annotates with `why`; the shared-list renderer read
      // only `note`, so every justification — including a recorded rejection
      // — vanished from the rendered document and a rejected package read
      // as a dependency.
      final p = plan([
        route(
          'h',
          'form',
          tab: 'Home',
          panels: [
            {
              'fields': [
                {'label': 'x', 'placeholder': 'y'},
              ],
            },
          ],
          sprint: {'order': 1, 'size': 'S'},
          extra: {'primaryAction': 'Save'},
        ),
      ]);
      p['dependencies'] = [
        {'name': 'fl_chart', 'why': 'REJECTED — the only chart is the ring'},
      ];
      final md = renderSuperPlanMarkdown(p);
      expect(md, contains('REJECTED — the only chart is the ring'));
    });

    test('a `note` still wins where the list uses one', () {
      final p = plan([
        route(
          'h',
          'form',
          tab: 'Home',
          panels: [
            {
              'fields': [
                {'label': 'x', 'placeholder': 'y'},
              ],
            },
          ],
          sprint: {'order': 1, 'size': 'S'},
          extra: {'primaryAction': 'Save'},
        ),
      ]);
      p['sharedEntities'] = [
        {'name': 'Habit', 'note': 'the thing being tracked'},
      ];
      expect(renderSuperPlanMarkdown(p), contains('the thing being tracked'));
    });
  });

  group('V10: the interview leaves a trace', () {
    Map<String, Object?> withDecisions(List<Object?> decisions) {
      final p = plan([
        route(
          'h',
          'form',
          tab: 'Home',
          panels: [
            {
              'fields': [
                {'label': 'x', 'placeholder': 'y'},
              ],
            },
          ],
          sprint: {'order': 1, 'size': 'S'},
          extra: {'primaryAction': 'Save'},
        ),
      ]);
      p['decisions'] = decisions;
      return p;
    }

    test('a decision with no source is rejected', () {
      final errors = validateSuperPlan(
        withDecisions([
          {'question': 'Does it need auth?', 'answer': 'No'},
        ]),
      );
      expect(errors.join('\n'), contains('decisions[0].source: required'));
    });

    test('a source outside user/assumed is rejected', () {
      final errors = validateSuperPlan(
        withDecisions([
          {'question': 'Does it need auth?', 'answer': 'No', 'source': 'maybe'},
        ]),
      );
      expect(errors.join('\n'), contains('decisions[0].source: required'));
    });

    test('an assumption with no `why` is rejected', () {
      // The whole point of recording an assumption is the reason behind it.
      final errors = validateSuperPlan(
        withDecisions([
          {'question': 'Offline?', 'answer': 'Yes', 'source': 'assumed'},
        ]),
      );
      expect(errors.join('\n'), contains('decisions[0].why: required'));
    });

    test('an assumption with a real `why` passes', () {
      final errors = validateSuperPlan(
        withDecisions([
          {
            'question': 'Offline?',
            'answer': 'Yes',
            'source': 'assumed',
            'why': 'The trail library is useless with no signal',
          },
        ]),
      );
      expect(errors.where((e) => e.contains('decisions')).toList(), isEmpty);
    });

    test('a user-answered decision needs no `why`', () {
      final errors = validateSuperPlan(
        withDecisions([
          {'question': 'Offline?', 'answer': 'Yes', 'source': 'user'},
        ]),
      );
      expect(errors.where((e) => e.contains('decisions')).toList(), isEmpty);
    });

    test('the render puts decisions above the MVP cut, and counts them', () {
      final md = renderSuperPlanMarkdown(
        withDecisions([
          {'question': 'Offline?', 'answer': 'Yes', 'source': 'user'},
          {
            'question': 'Accounts?',
            'answer': 'Not in the MVP',
            'source': 'assumed',
            'why': 'Auth is a whole seam and nothing here needs identity yet',
          },
        ]),
      );
      expect(md, contains('1 answered by you, 1 assumed'));
      expect(md.indexOf('## Decisions'), lessThan(md.indexOf('## MVP cut')));
    });

    test('the validator does not require decisions to exist', () {
      // Requiring one here would break `--check` mid-authoring. Demanding
      // an interview is the tree's business — see superplan-lint S8.
      expect(validateSuperPlan(withDecisions(const <Object?>[])), isEmpty);
    });
  });
}
