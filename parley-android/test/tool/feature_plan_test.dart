import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/feature_plan.dart';

/// A validator whose own behaviour is unverified is a validator that quietly
/// stops rejecting. These tests say what it refuses, what it deliberately
/// allows, and — the part a reader cannot check by eye — that every frame it
/// draws is square.
void main() {
  Map<String, Object?> jsonOf(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

  group('the shared corpus', () {
    // `scripts/feature-plan.mjs` in create-react-app is this validator written
    // again in another language for another dialect. Two implementations of one
    // contract drift; a root test runs the Node side against this same file, so
    // a rule added to one and forgotten in the other fails on both sides.
    final corpus = jsonOf('tool/fixtures/shared-validator-cases.json');
    final cases = (corpus['cases'] as List).cast<Map<String, Object?>>();

    test('has cases, and they are not all one verdict', () {
      // A corpus that only accepts proves the validator returns a list.
      expect(cases.length, greaterThanOrEqualTo(10));
      expect(cases.where((c) => c['expect'] == 'accept'), isNotEmpty);
      expect(
        cases.where((c) => c['expect'] == 'reject').length,
        greaterThanOrEqualTo(9),
      );
    });

    for (final c in cases) {
      test('${c['case']} is ${c['expect']}ed', () {
        final errors = validateFeaturePlan(c['plan']);
        if (c['expect'] == 'accept') {
          expect(errors, isEmpty, reason: '${c['why']}');
        } else {
          expect(errors, isNotEmpty, reason: '${c['why']}');
          expect(errors.join('\n'), contains(c['match'] as String));
        }
      });
    }
  });

  group('the archetype is the rule', () {
    Map<String, Object?> surface(
      String archetype,
      List<Object?> panels, {
      Map<String, Object?>? states,
      Map<String, Object?> extra = const {},
    }) => {
      'id': 's',
      'name': 'Surface',
      'archetype': archetype,
      'panels': panels,
      // Required of every surface, so the helper supplies it: these tests are
      // about the archetype rules, and a plan that fails on a missing peak
      // never reaches them.
      'moments': const {'peak': 'the thing', 'end': 'the last thing'},
      'states':
          states ??
          const {
            'loading': 'bones',
            'empty': 'nothing here',
            'error': 'it broke',
            'success': 'it rendered',
          },
      ...extra,
    };

    List<String> check(Map<String, Object?> s) => validateFeaturePlan({
      'feature': {'id': 'x', 'title': 'X', 'problem': 'p'},
      'surfaces': [s],
    });

    test('a schedule names its window, its empty day and how to add', () {
      final errors = check(
        surface('schedule', const [
          {'kind': 'day', 'slots': []},
        ]),
      );
      final joined = errors.join('\n');
      expect(joined, contains('.window: required'));
      expect(joined, contains('.empty: required'));
      expect(joined, contains('.create: required'));
    });

    test('a complete schedule passes and draws its clash side by side', () {
      final plan = {
        'feature': {'id': 'x', 'title': 'X', 'problem': 'p'},
        'surfaces': [
          surface(
            'schedule',
            const [
              {
                'kind': 'day',
                'slots': [
                  {'at': '09:00', 'title': 'Stand-up'},
                  {'at': '10:00', 'title': 'Review', 'clash': 'Dentist'},
                ],
              },
            ],
            extra: const {
              'window': '08:00 to 20:00, widened by anything outside it',
              'empty': 'Nothing today. Add the first thing.',
              'create': 'the plus in the header opens a new event',
            },
          ),
        ],
      };
      expect(validateFeaturePlan(plan), isEmpty);

      final md = renderFeaturePlanMarkdown(plan);
      var blocks = 0;
      List<String>? current;
      for (final line in md.split('\n')) {
        if (line == '```') {
          if (current != null) {
            final box = current
                .where(
                  (l) =>
                      l.startsWith('│') ||
                      l.startsWith('┌') ||
                      l.startsWith('├') ||
                      l.startsWith('└'),
                )
                .toList();
            if (box.isNotEmpty) {
              blocks++;
              expect(
                box.map((l) => l.length).toSet(),
                hasLength(1),
                reason: 'a frame tore:\n${box.join('\n')}',
              );
            }
            current = null;
          } else {
            current = [];
          }
          continue;
        }
        current?.add(line);
      }
      expect(blocks, greaterThanOrEqualTo(1));

      // The clash is on one line, which is the claim the archetype makes.
      final clashLine = md
          .split('\n')
          .where((l) => l.contains('Review') && l.contains('Dentist'));
      expect(clashLine, isNotEmpty);
    });

    test('an editor is one document, and says what saving means', () {
      final errors = check(
        surface('editor', const [
          {'kind': 'document', 'title': 'Untitled note'},
        ]),
      );
      final joined = errors.join('\n');
      expect(joined, contains('.autosave: required'));
      expect(joined, contains('.undo: required'));
      expect(joined, contains('.exit: required'));
    });

    test('an editor pins its toolbar, not a button', () {
      final errors = check(
        surface(
          'editor',
          const [
            {'kind': 'document', 'title': 'Untitled note'},
          ],
          extra: const {
            'autosave': 'every keystroke, debounced two seconds',
            'undo': 'the last twenty edits',
            'exit': 'back keeps the draft and says so',
            'primaryAction': 'Publish',
          },
        ),
      );
      expect(errors.join('\n'), contains('pins its toolbar'));
    });

    test('a complete editor passes and draws a square frame', () {
      final plan = {
        'feature': {'id': 'x', 'title': 'X', 'problem': 'p'},
        'surfaces': [
          surface(
            'editor',
            const [
              {
                'kind': 'document',
                'title': 'Untitled note',
                'items': ['The first line', 'The second line'],
              },
            ],
            extra: const {
              'autosave': 'every keystroke, debounced two seconds',
              'undo': 'the last twenty edits',
              'exit': 'back keeps the draft and says so',
            },
          ),
        ],
      };
      expect(validateFeaturePlan(plan), isEmpty);

      final md = renderFeaturePlanMarkdown(plan);
      var blocks = 0;
      List<String>? current;
      for (final line in md.split('\n')) {
        if (line == '```') {
          if (current != null) {
            final box = current
                .where(
                  (l) =>
                      l.startsWith('│') ||
                      l.startsWith('┌') ||
                      l.startsWith('├') ||
                      l.startsWith('└'),
                )
                .toList();
            if (box.isNotEmpty) {
              blocks++;
              expect(
                box.map((l) => l.length).toSet(),
                hasLength(1),
                reason: 'a frame tore:\n${box.join('\n')}',
              );
            }
            current = null;
          } else {
            current = [];
          }
          continue;
        }
        current?.add(line);
      }
      expect(blocks, greaterThanOrEqualTo(1));
      // Wrapped at the phone's width, so the assertion reads a whole line.
      expect(md, contains('every keystroke, debounced'));
      expect(md, contains('back keeps the draft'));
    });

    test('a transcript with one voice in it is not a conversation', () {
      final errors = check(
        surface(
          'conversation',
          const [
            {
              'kind': 'transcript',
              'title': 'Thread',
              'turns': [
                {'author': 'them', 'text': 'One'},
                {'author': 'them', 'text': 'Two'},
              ],
            },
          ],
          extra: const {
            'composer': 'Message',
            'retry': 'Try again',
            'empty': 'Say hello',
          },
        ),
      );
      expect(errors.join('\n'), contains('both speakers appear'));
    });

    test('a conversation names its composer, its retry and its empty', () {
      final errors = check(
        surface('conversation', const [
          {
            'kind': 'transcript',
            'title': 'Thread',
            'turns': [
              {'author': 'them', 'text': 'One'},
              {'author': 'me', 'text': 'Two'},
            ],
          },
        ]),
      );
      final joined = errors.join('\n');
      expect(joined, contains('.composer: required'));
      expect(joined, contains('.retry: required'));
      expect(joined, contains('.empty: required'));
    });

    test('a conversation pins the composer and nothing else', () {
      final errors = check(
        surface(
          'conversation',
          const [
            {
              'kind': 'transcript',
              'title': 'Thread',
              'turns': [
                {'author': 'them', 'text': 'One'},
                {'author': 'me', 'text': 'Two'},
              ],
            },
          ],
          extra: const {
            'composer': 'Message',
            'retry': 'Try again',
            'empty': 'Say hello',
            'primaryAction': 'Send',
          },
        ),
      );
      expect(errors.join('\n'), contains('pins the composer and nothing'));
    });

    test('a complete conversation passes', () {
      expect(
        check(
          surface(
            'conversation',
            const [
              {
                'kind': 'transcript',
                'title': 'Thread',
                'turns': [
                  {'author': 'them', 'text': 'The slot moved to Thursday'},
                  {'author': 'me', 'text': 'That works', 'state': 'failed'},
                ],
              },
            ],
            extra: const {
              'composer': 'Message',
              'retry': 'Try again',
              'empty': 'Say hello',
            },
          ),
        ),
        isEmpty,
      );
    });

    test('focal without a hero is not focal', () {
      final errors = check(
        surface('focal', [
          {'kind': 'tile', 'title': 'a'},
          {'kind': 'wide', 'title': 'b'},
          {'kind': 'tile', 'title': 'c'},
        ]),
      );
      expect(errors.join('\n'), contains('focal starts with one panel'));
    });

    test('a bento of one tile size is the defect, not a layout', () {
      // This is the screen `docs/principles/screen-archetypes.md` is named
      // after: six identical tiles, no focal point, nowhere for the eye to
      // land. It is rejected at plan time rather than found in review.
      final errors = check(
        surface('focal', [
          {'kind': 'hero', 'title': 'hero'},
          {'kind': 'tile', 'title': 'a'},
          {'kind': 'tile', 'title': 'b'},
          {'kind': 'tile', 'title': 'c'},
        ]),
      );
      expect(errors.join('\n'), contains('the bento needs two sizes'));
    });

    test('a hero over a wide tile and a pair passes', () {
      expect(
        check(
          surface('focal', [
            {'kind': 'hero', 'title': 'hero'},
            {'kind': 'wide', 'title': 'wide'},
            {'kind': 'tile', 'title': 'a'},
            {'kind': 'tile', 'title': 'b'},
          ]),
        ),
        isEmpty,
      );
    });

    Map<String, Object?> collectionPanel({
      Map<String, Object?> without = const {},
    }) {
      final panel = <String, Object?>{
        'kind': 'list',
        'rows': ['one'],
        'search': 'Search',
        'filters': ['All'],
        'swipe': 'Remove',
        'swipeTwin': 'the row menu',
      };
      for (final k in without.keys) {
        panel.remove(k);
      }
      return panel;
    }

    const collectionStates = {
      'loading': 'bones',
      'empty': 'nothing here yet',
      'zeroResults': 'nothing matched',
      'error': 'it broke',
      'success': 'it rendered',
    };

    test('a collection without a swipe twin is rejected', () {
      // The swipe is invisible to a reader using VoiceOver or a switch
      // control. Requiring the twin in the plan is the cheapest place to
      // require it — the alternative is finding it in an accessibility audit.
      final errors = check(
        surface('collection', [
          collectionPanel(without: {'swipeTwin': 1}),
        ], states: collectionStates),
      );
      expect(errors.join('\n'), contains('`swipeTwin` is required'));
    });

    test('a collection owes a zero-results state as well as an empty one', () {
      final errors = check(surface('collection', [collectionPanel()]));
      expect(errors.join('\n'), contains('states.zeroResults: required'));
    });

    test('a complete collection passes', () {
      expect(
        check(
          surface('collection', [collectionPanel()], states: collectionStates),
        ),
        isEmpty,
      );
    });

    test('a detail with no named primary is rejected', () {
      final errors = check(
        surface('detail', [
          {
            'kind': 'section',
            'title': 'Overview',
            'rows': ['text'],
          },
        ]),
      );
      expect(errors.join('\n'), contains('detail pins a primary action'));
    });

    test('a form is one column — two field panels is two columns', () {
      final errors = check(
        surface(
          'form',
          [
            {
              'fields': [
                {'label': 'a'},
              ],
            },
            {
              'fields': [
                {'label': 'b'},
              ],
            },
          ],
          extra: const {'primaryAction': 'Save'},
        ),
      );
      expect(errors.join('\n'), contains('form is one column'));
    });

    test('a settings group with no eyebrow is a list', () {
      final errors = check(
        surface('settings', [
          {
            'rows': ['Name', 'Email'],
          },
        ]),
      );
      expect(errors.join('\n'), contains('panels[0].eyebrow: required'));
    });

    // --- sequence ---------------------------------------------------------

    Map<String, Object?> step(String title, String job) => {
      'kind': 'step',
      'title': title,
      'job': job,
      'body': 'one decision',
    };

    Map<String, Object?> sequence(List<Object?> panels) => surface(
      'sequence',
      panels,
      extra: const {
        'progress': 'a dot per stop',
        'back': 'returns the previous stop with its answer intact',
        'handover': 'the dashboard',
        'primaryAction': 'Next',
      },
    );

    test('a sequence of one step is a form with a progress bar on it', () {
      expect(
        check(sequence([step('Pick a goal', 'segmentation')])).join('\n'),
        contains('at least two panels'),
      );
    });

    test('a step that cannot name its job is a step nobody decided on', () {
      // The rule the flows worth copying have in common: brand, segmentation,
      // trust, activation, monetization or retention. A step matching none of
      // them exists because it was easy to build.
      expect(
        check(sequence([step('a', 'brand'), step('b', 'vibes')])).join('\n'),
        contains('panels[1].job: must be one of brand'),
      );
    });

    test('a sequence owes progress, a back and a handover', () {
      final errors = check(
        surface('sequence', [step('a', 'brand'), step('b', 'trust')]),
      ).join('\n');
      expect(errors, contains('progress: required'));
      expect(errors, contains('back: required'));
      // A sequence that ends on itself is one the user leaves.
      expect(errors, contains('handover: required'));
    });

    test('a sequence that names every job passes', () {
      expect(
        check(
          sequence([
            step('Welcome aboard', 'brand'),
            step('What brings you here?', 'segmentation'),
            step('Add your first note', 'activation'),
          ]),
        ),
        isEmpty,
      );
    });

    // --- offer ------------------------------------------------------------

    Map<String, Object?> offer(
      List<Object?> plans, {
      Map<String, Object?> extra = const {},
    }) => surface(
      'offer',
      [
        {'kind': 'plans', 'title': 'Choose a plan', 'plans': plans},
      ],
      extra: {
        'outcome': 'Every note, on every device, with no cap',
        'trial': 'Free until 14 March, then £39/year',
        'primaryAction': 'Start 7-day free trial',
        'billing': '£39 a year from 14 March. Cancel any time in Settings.',
        'restore': 'Restore purchases',
        'terms': 'Terms · Privacy',
        ...extra,
      },
    );

    const yearly = {
      'period': 'Yearly',
      'price': '£39 (£3.25/mo)',
      'badge': 'save 35%',
    };
    const monthly = {'period': 'Monthly', 'price': '£4.99'};

    test('four plans is a pricing page, not a paywall', () {
      expect(
        check(
          offer([
            yearly,
            monthly,
            {'period': 'Quarterly', 'price': '£13'},
            {'period': 'Lifetime', 'price': '£99'},
          ]),
        ).join('\n'),
        contains('between 1 and 3 plans'),
      );
    });

    test('a plan whose price is not beside its period is rejected', () {
      expect(
        check(
          offer([
            yearly,
            {'period': 'Monthly'},
          ]),
        ).join('\n'),
        contains('plans[1] needs both `period` and `price`'),
      );
    });

    test('an offer owes the outcome, the billing line, restore and terms', () {
      final errors = check(
        surface('offer', [
          {
            'kind': 'plans',
            'title': 'Plans',
            'plans': [yearly],
          },
        ]),
      ).join('\n');
      expect(errors, contains('outcome: required'));
      expect(errors, contains('billing: required'));
      // On iOS a paywall without a restore is a review rejection.
      expect(errors, contains('restore: required'));
      expect(errors, contains('terms: required'));
    });

    test('two plans with the outcome and the disclosure passes', () {
      expect(check(offer([yearly, monthly])), isEmpty);
    });

    // --- insight ------------------------------------------------------------

    Map<String, Object?> insight(
      List<Object?> panels, {
      Map<String, Object?> extra = const {},
    }) => surface(
      'insight',
      panels,
      extra: {
        'headline': '4h 12m',
        'comparison': '18% more than last week',
        'period': 'Mon 25 – Sun 31 August',
        'reading': 'Tuesday carried the week.',
        'handover': 'Library',
        ...extra,
      },
    );

    const plot = {'kind': 'chart', 'title': 'Minutes per day'};

    test('two plots on a recap is a dashboard', () {
      expect(
        check(insight([plot, plot])).join('\n'),
        contains('insight is exactly 1 panel'),
      );
    });

    test('a recap with no plot is a stat tile', () {
      expect(
        check(
          insight([
            {'kind': 'breakdown', 'title': 'Where it went'},
          ]),
        ).join('\n'),
        contains('insight is exactly 1 panel'),
      );
    });

    test(
      'an insight owes the figure, its baseline, the span and the reading',
      () {
        final errors = check(surface('insight', [plot])).join('\n');
        expect(errors, contains('headline: required'));
        expect(errors, contains('comparison: required'));
        expect(errors, contains('period: required'));
        expect(errors, contains('reading: required'));
        // A recap that ends on itself is one the reader closes.
        expect(errors, contains('handover: required'));
      },
    );

    test('an insight that pins a primary is refused', () {
      expect(
        check(insight([plot], extra: {'primaryAction': 'Continue'})).join('\n'),
        contains('an insight pins nothing'),
      );
    });

    test('one plot, one figure and one sentence passes', () {
      expect(
        check(
          insight([
            plot,
            {'kind': 'breakdown', 'title': 'Where it went'},
          ]),
        ),
        isEmpty,
      );
    });

    // --- shelf --------------------------------------------------------------

    Map<String, Object?> rail(String title, {int items = 3, String? seeAll}) =>
        {
          'kind': 'rail',
          'title': title,
          'items': List<String>.generate(items, (i) => 'Item $i'),
          if (seeAll != null) 'seeAll': seeAll,
        };

    test('one rail is a section, not a shelf', () {
      expect(
        check(surface('shelf', [rail('Continue')])).join('\n'),
        contains('at least two panels of `kind: "rail"`'),
      );
    });

    test('a rail with no reason to exist is refused', () {
      expect(
        check(
          surface('shelf', [
            rail('Continue'),
            {
              'kind': 'rail',
              'items': ['A'],
            },
          ]),
        ).join('\n'),
        contains('every rail needs a `title` saying why it is here'),
      );
    });

    test('a rail past four tiles owes a See all', () {
      expect(
        check(
          surface('shelf', [rail('Continue'), rail('New this week', items: 9)]),
        ).join('\n'),
        contains('needs `seeAll`'),
      );
      expect(
        check(
          surface('shelf', [
            rail('Continue'),
            rail('New this week', items: 9, seeAll: '/browse/new'),
          ]),
        ),
        isEmpty,
      );
    });

    test('a hero under a rail is a hero the user scrolled past', () {
      expect(
        check(
          surface('shelf', [
            rail('Continue'),
            {'kind': 'hero', 'title': 'Featured'},
            rail('New'),
          ]),
        ).join('\n'),
        contains('the hero is the first panel'),
      );
    });

    test('one hero and two named rails passes', () {
      expect(
        check(
          surface('shelf', [
            {'kind': 'hero', 'title': 'Featured'},
            rail('Continue'),
            rail('New this week'),
          ]),
        ),
        isEmpty,
      );
    });

    // --- session ------------------------------------------------------------

    Map<String, Object?> session({Map<String, Object?> extra = const {}}) =>
        surface(
          'session',
          [
            {'kind': 'stage', 'title': 'Now playing'},
          ],
          extra: {
            'nowPlaying': 'Release 4.2 — Changelog',
            'transport': const ['Back 15', 'Play', 'Forward 30'],
            'escape': 'A down-chevron; the audio keeps playing',
            ...extra,
          },
        );

    test('a session owes what is playing, its transport and its escape', () {
      final errors = check(
        surface('session', [
          {'kind': 'stage', 'title': 'Now playing'},
        ]),
      ).join('\n');
      expect(errors, contains('nowPlaying: required'));
      expect(errors, contains('transport: required'));
      expect(errors, contains('escape: required'));
    });

    test('two stages is two sessions', () {
      expect(
        check(
          surface(
            'session',
            [
              {'kind': 'stage', 'title': 'A'},
              {'kind': 'stage', 'title': 'B'},
            ],
            extra: const {
              'nowPlaying': 'x',
              'transport': ['Play'],
              'escape': 'chevron',
            },
          ),
        ).join('\n'),
        contains('exactly one panel of `kind: "stage"`'),
      );
    });

    test('a session that pins a primary is refused', () {
      expect(
        check(session(extra: {'primaryAction': 'Save'})).join('\n'),
        contains('a session pins nothing'),
      );
    });

    test('a stage, a transport and an escape passes', () {
      expect(check(session()), isEmpty);
    });

    // --- canvas -------------------------------------------------------------

    Map<String, Object?> canvas({
      List<Object?> detents = const ['peek', 'half', 'full'],
      Map<String, Object?> extra = const {},
    }) => surface('canvas', [
      {'kind': 'ground', 'title': 'The map'},
      {
        'kind': 'sheet',
        'title': 'Nearby',
        'detents': detents,
        'peek': 'The selected pin stays above the sheet',
        'rows': const ['Blue Bottle · 200m'],
      },
    ], extra: extra);

    test('a sheet that settles at one height is a panel', () {
      expect(
        check(canvas(detents: const ['full'])).join('\n'),
        contains('needs 2 to 3 named `detents`'),
      );
    });

    test('four detents is a sheet the user has to aim', () {
      expect(
        check(
          canvas(detents: const ['peek', 'third', 'half', 'full']),
        ).join('\n'),
        contains('needs 2 to 3 named `detents`'),
      );
    });

    test('a peek that says nothing about the ground is refused', () {
      expect(
        check(
          surface('canvas', [
            {'kind': 'ground', 'title': 'The map'},
            {
              'kind': 'sheet',
              'title': 'Nearby',
              'detents': const ['peek', 'full'],
            },
          ]),
        ).join('\n'),
        contains('the sheet needs `peek`'),
      );
    });

    test('a canvas that pins a primary is refused', () {
      expect(
        check(canvas(extra: {'primaryAction': 'Confirm'})).join('\n'),
        contains('a canvas pins nothing'),
      );
    });

    test('a ground and a sheet with three detents passes', () {
      expect(check(canvas()), isEmpty);
    });

    // --- confirmation -------------------------------------------------------

    Map<String, Object?> confirmation({
      Map<String, Object?> extra = const {},
    }) => surface(
      'confirmation',
      [
        {'kind': 'receipt', 'title': '2 items · £34.98'},
      ],
      extra: {
        'outcome': 'Your order is placed',
        'reference': 'Order RS-4821',
        'next': 'Arrives Thursday 12 March',
        'handover': 'Track order',
        'primaryAction': 'Track order',
        ...extra,
      },
    );

    test('a confirmation owes the outcome, the number, the date and a way '
        'onward', () {
      final errors = check(
        surface('confirmation', [
          {'kind': 'receipt', 'title': 'x'},
        ]),
      ).join('\n');
      expect(errors, contains('outcome: required'));
      expect(errors, contains('reference: required'));
      expect(errors, contains('next: required'));
      expect(errors, contains('handover: required'));
    });

    test('a confirmation with no receipt is a success page', () {
      expect(
        check(
          surface(
            'confirmation',
            [
              {'kind': 'section', 'title': 'Thanks'},
            ],
            extra: const {
              'outcome': 'Placed',
              'reference': 'RS-1',
              'next': 'Thursday',
              'handover': 'Home',
            },
          ),
        ).join('\n'),
        contains('exactly one panel of `kind: "receipt"`'),
      );
    });

    test('the outcome, the identifier, the receipt and the date passes', () {
      expect(check(confirmation()), isEmpty);
    });
  });

  group('the rendering', () {
    final plan = jsonOf('tool/fixtures/notes.feature-plan.json');

    test('the shipped fixture is a valid plan', () {
      expect(validateFeaturePlan(plan), isEmpty);
    });

    test('an invalid plan is not drawn', () {
      // A drawing of a plan nobody agreed to is worse than no drawing.
      expect(() => renderFeaturePlanMarkdown(const {}), throwsArgumentError);
    });

    test('the same plan renders the same bytes', () {
      // P2 in plan-lint compares a committed document against a fresh render.
      // That comparison is only meaningful if the render is deterministic.
      expect(renderFeaturePlanMarkdown(plan), renderFeaturePlanMarkdown(plan));
    });

    test('every frame is square', () {
      // The one property a reader cannot check by eye and that every join
      // depends on: inside a fenced block, a box-drawing line that is one
      // column short tears the whole frame.
      final md = renderFeaturePlanMarkdown(plan);
      var blocks = 0;
      List<String>? current;
      for (final line in md.split('\n')) {
        if (line == '```') {
          if (current != null) {
            final box = current
                .where(
                  (l) =>
                      l.startsWith('│') ||
                      l.startsWith('┌') ||
                      l.startsWith('├') ||
                      l.startsWith('└'),
                )
                .toList();
            if (box.isNotEmpty) {
              blocks++;
              expect(
                box.map((l) => l.length).toSet(),
                hasLength(1),
                reason: 'a frame tore:\n${box.join('\n')}',
              );
            }
            current = null;
          } else {
            current = [];
          }
          continue;
        }
        current?.add(line);
      }
      expect(blocks, greaterThanOrEqualTo(5));
    });

    test('the form primary is drawn full width, not as a centred pill', () {
      // "Bottom, full width, above the safe area" is the single clearest
      // difference from the desktop pattern. A frame that draws a short
      // centred button has agreed to something the archetype forbids.
      final md = renderFeaturePlanMarkdown(plan);
      final bar = md
          .split('\n')
          .firstWhere((l) => l.contains('[') && l.contains('Save'));
      expect(bar.trim(), startsWith('│ ['));
      expect(bar.indexOf(']'), greaterThan(bar.length - 5));
    });

    test('a pushed route draws no tab bar, a tab root does', () {
      // The tab bar is what a pushed route covers, which is the reason its
      // primary action has to be pinned rather than left to the nav.
      final md = renderFeaturePlanMarkdown(plan);
      final frames = md.split('**Phone @390**');
      expect(frames[1], contains('● Library'));
      expect(frames[2], isNot(contains('● Library')));
    });

    test('each surface prints the rules its archetype will be held to', () {
      final md = renderFeaturePlanMarkdown(plan);
      expect(md, contains('the swipe action has a tappable twin'));
      expect(md, contains('does not scroll away'));
      expect(md, contains('one column, and the primary is bottom, full width'));
      // And the two every surface owes, whatever its shape.
      expect(
        'tool/ui_lint.dart'.allMatches(md).length,
        greaterThanOrEqualTo(3),
      );
    });

    test('a conversation draws a square frame, both edges inside it', () {
      // The one body in the set that indents: a turn of mine is pushed to the
      // trailing edge by exactly the width the bubble gives up, and an
      // indent one column wide too many tears every join under it.
      const states = {
        'loading': 'a',
        'empty': 'b',
        'error': 'c',
        'success': 'd',
      };
      final md = renderFeaturePlanMarkdown({
        'feature': {'id': 'x', 'title': 'X', 'problem': 'p'},
        'surfaces': [
          {
            'id': 'thread',
            'name': 'Thread',
            'archetype': 'conversation',
            'composer': 'Message',
            'retry': 'Try again',
            'empty': 'Say hello',
            'panels': [
              {
                'kind': 'transcript',
                'title': 'Thread',
                'turns': [
                  {
                    'author': 'them',
                    'text': 'The delivery slot moved to Thursday',
                  },
                  {'author': 'me', 'text': 'Send it', 'state': 'failed'},
                ],
              },
            ],
            'moments': const {'peak': 'the thing', 'end': 'the last thing'},
            'states': states,
          },
        ],
      });

      // Per fenced block, as the frame tests above do: the document also
      // carries wider boxes of its own, and a frame only has to be square
      // against the one it is drawn in.
      var blocks = 0;
      List<String>? current;
      for (final line in md.split('\n')) {
        if (line == '```') {
          if (current != null) {
            final box = current
                .where(
                  (l) =>
                      l.startsWith('│') ||
                      l.startsWith('┌') ||
                      l.startsWith('├') ||
                      l.startsWith('└'),
                )
                .toList();
            if (box.isNotEmpty) {
              blocks++;
              expect(
                box.map((l) => l.length).toSet(),
                hasLength(1),
                reason: 'a frame tore:\n${box.join('\n')}',
              );
            }
            current = null;
          } else {
            current = [];
          }
          continue;
        }
        current?.add(line);
      }
      expect(blocks, greaterThanOrEqualTo(1));

      // The composer is drawn, and so is what a failed turn offers.
      expect(md, contains('Message'));
      expect(md, contains('not sent · Try again'));
    });

    test('the four newest archetypes draw square frames', () {
      // Same claim as the test below, for the four shapes declared together:
      // each drew its own body, and a box-drawing line one column short tears
      // every join under it inside the same fence. The shelf is the one most
      // likely to: its rails are cut at the frame's edge on purpose, so the
      // cut has to land exactly on the width.
      const states = {
        'loading': 'a',
        'empty': 'b',
        'error': 'c',
        'success': 'd',
      };
      const moments = {'peak': 'the thing', 'end': 'the last thing'};
      final md = renderFeaturePlanMarkdown({
        'feature': {'id': 'x', 'title': 'X', 'problem': 'p'},
        'surfaces': [
          {
            'id': 'browse',
            'name': 'Browse',
            'archetype': 'shelf',
            'panels': [
              {'kind': 'hero', 'title': 'The desk, and its objects'},
              {
                'kind': 'rail',
                'title': 'Continue watching',
                'items': ['Release 4.2', 'Design tokens', 'Colour'],
              },
              {
                'kind': 'rail',
                'title': 'New this week',
                'items': ['A', 'B', 'C', 'D', 'E'],
                'seeAll': '/browse/new',
              },
            ],
            'moments': moments,
            'states': states,
          },
          {
            'id': 'player',
            'name': 'Now playing',
            'archetype': 'session',
            'nowPlaying': 'Release 4.2 — Changelog',
            'transport': ['Back 15', 'Play', 'Forward 30'],
            'escape': 'A down-chevron; the audio keeps playing',
            'panels': [
              {'kind': 'stage', 'title': 'Release 4.2'},
            ],
            'moments': moments,
            'states': states,
          },
          {
            'id': 'map',
            'name': 'Nearby',
            'archetype': 'canvas',
            'panels': [
              {'kind': 'ground', 'title': 'The map'},
              {
                'kind': 'sheet',
                'title': 'Nearby',
                'detents': ['peek', 'half', 'full'],
                'peek': 'The selected pin stays above the sheet',
                'rows': ['Blue Bottle · 200m'],
              },
            ],
            'moments': moments,
            'states': states,
          },
          {
            'id': 'placed',
            'name': 'Order placed',
            'archetype': 'confirmation',
            'outcome': 'Your order is placed',
            'reference': 'Order RS-4821',
            'next': 'Arrives Thursday 12 March',
            'undo': 'You can cancel until 6pm',
            'handover': 'Track order',
            'primaryAction': 'Track order',
            'panels': [
              {'kind': 'receipt', 'title': '2 items · £34.98'},
            ],
            'moments': moments,
            'states': states,
          },
        ],
      });

      var blocks = 0;
      List<String>? current;
      for (final line in md.split('\n')) {
        if (line == '```') {
          if (current != null) {
            final box = current
                .where(
                  (l) =>
                      l.startsWith('│') ||
                      l.startsWith('┌') ||
                      l.startsWith('├') ||
                      l.startsWith('└'),
                )
                .toList();
            if (box.isNotEmpty) {
              blocks++;
              expect(
                box.map((l) => l.length).toSet(),
                hasLength(1),
                reason: 'a frame tore:\n${box.join('\n')}',
              );
            }
            current = null;
          } else {
            current = [];
          }
          continue;
        }
        current?.add(line);
      }
      expect(blocks, greaterThanOrEqualTo(4));

      // The rail's reason is on the drawing, and so is the "See all" the
      // fifth item earns it.
      expect(md, contains('Continue watching'));
      expect(md, contains('See all'));
      // A session's transport is drawn; a session's pinned bar is not.
      expect(md, contains('[ Play ]'));
      // The confirmation's identifier and its dated next step.
      expect(md, contains('Order RS-4821'));
      expect(md, contains('Arrives Thursday 12 March'));
    });

    test('the three newest archetypes draw square frames', () {
      // Both bodies were written after the frame was, and a box-drawing line
      // one column short tears every join below it inside the same fence.
      final md = renderFeaturePlanMarkdown({
        'feature': {'id': 'x', 'title': 'X', 'problem': 'p'},
        'surfaces': [
          {
            'id': 'tour',
            'name': 'Tour',
            'archetype': 'sequence',
            'progress': 'a dot per stop',
            'back': 'keeps the answer',
            'handover': 'the dashboard',
            'primaryAction': 'Next',
            'panels': [
              {'kind': 'step', 'title': 'Welcome', 'job': 'brand'},
              {'kind': 'step', 'title': 'Your goal', 'job': 'segmentation'},
            ],
            'moments': {'peak': 'the thing', 'end': 'the last thing'},
            'states': {
              'loading': 'a',
              'empty': 'b',
              'error': 'c',
              'success': 'd',
            },
          },
          {
            'id': 'paywall',
            'name': 'Go Pro',
            'archetype': 'offer',
            'outcome': 'Every note, everywhere, with no cap',
            'trial': 'Free until 14 March, then £39/year',
            'primaryAction': 'Start 7-day free trial',
            'billing': '£39 a year from 14 March. Cancel in Settings.',
            'restore': 'Restore purchases',
            'terms': 'Terms · Privacy',
            'panels': [
              {
                'kind': 'plans',
                'title': 'Choose a plan',
                'plans': [
                  {'period': 'Yearly', 'price': '£39', 'badge': 'save 35%'},
                  {'period': 'Monthly', 'price': '£4.99'},
                ],
              },
            ],
            'moments': {'peak': 'the thing', 'end': 'the last thing'},
            'states': {
              'loading': 'a',
              'empty': 'b',
              'error': 'c',
              'success': 'd',
            },
          },
          {
            'id': 'recap',
            'name': 'Your week',
            'archetype': 'insight',
            'headline': '4h 12m',
            'comparison': '18% more than last week',
            'period': 'Mon 25 – Sun 31 August',
            'reading': 'Tuesday carried the week.',
            'handover': 'the library',
            'panels': [
              {'kind': 'chart', 'title': 'Minutes per day'},
              {'kind': 'breakdown', 'title': 'Where it went'},
            ],
            'moments': {'peak': 'the thing', 'end': 'the last thing'},
            'states': {
              'loading': 'a',
              'empty': 'b',
              'error': 'c',
              'success': 'd',
            },
          },
        ],
      });
      // Per fenced block, as above: the document also draws a wider frame for
      // the route map, and one width across the whole file is not the claim.
      var blocks = 0;
      List<String>? current;
      for (final line in md.split('\n')) {
        if (line == '```') {
          if (current != null) {
            final box = current
                .where(
                  (l) =>
                      l.startsWith('│') ||
                      l.startsWith('┌') ||
                      l.startsWith('├') ||
                      l.startsWith('└'),
                )
                .toList();
            if (box.isNotEmpty) {
              blocks++;
              expect(
                box.map((l) => l.length).toSet(),
                hasLength(1),
                reason: 'a frame tore:\n${box.join('\n')}',
              );
            }
            current = null;
          } else {
            current = [];
          }
          continue;
        }
        current?.add(line);
      }
      expect(blocks, greaterThanOrEqualTo(2));

      // Every step's job is on the drawing, because a reviewer who can see
      // six steps all doing `brand` can cut five of them.
      expect(md, contains('job: brand'));
      expect(md, contains('job: segmentation'));

      // And the renewal line is drawn inside the pinned bar, under the
      // button — the adjacency the rule is about. A disclosure the pinned
      // chrome covers is one the user meets at the charge.
      final lines = md.split('\n');
      final button = lines.indexWhere(
        (l) => l.contains('Start 7-day free trial'),
      );
      final renewal = lines.indexWhere((l) => l.contains('£39 a year from'));
      expect(button, greaterThan(-1));
      expect(renewal, greaterThan(button));
      expect(
        lines.sublist(button, renewal).any((l) => l.startsWith('├')),
        isFalse,
        reason: 'the renewal line left the bar the button is in',
      );
    });

    test('the document says it is generated', () {
      // P2 exists because somebody will otherwise edit it. The document has to
      // say so on its first line, where an editor sees it.
      expect(
        renderFeaturePlanMarkdown(plan),
        startsWith('<!-- feature-plan:v1 — generated, do not hand-edit.'),
      );
    });
  });
}
