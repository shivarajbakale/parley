// super_plan — validate a superplan and draw it, before any feature is built.
//
// Why this exists
// ---------------
// `add-feature` starts writing files at step 2, so the first reviewable
// artifact for a *feature* is its `FEATURE-PLAN.md` (see
// `tool/feature_plan.dart`). What sits above that — the app-level plan that
// names every route, every shared entity, every module choice — had no
// artifact of its own. The agent filled `BLUEPRINT.md` from a one-paragraph
// app brief alone, which silently baked the user's app into one screen of
// tables and forced a per-route planning round-trip for every screen.
//
// This script is that missing artifact. Given a one-paragraph app brief the
// initializer writes `SUPERPLAN.json`; this script validates it (V1..V7) and
// renders `SUPERPLAN.md` from it. The same twelve archetypes the per-feature
// validator owns declare the per-route shape here, so the frame approved at
// the app level and the frame approved at the feature level cannot drift.
//
// Usage
// -----
//   dart run tool/super_plan.dart <plan.json>                       # print
//   dart run tool/super_plan.dart <plan.json> -o SUPERPLAN.md       # write
//   dart run tool/super_plan.dart <plan.json> --check               # validate
//
// Dependency-free: `dart:io` and `dart:convert`, nothing from pub.

import 'dart:convert';
import 'dart:io';

// --- DS catalog ------------------------------------------------------------
//
// A superplan names the components it plans to use via `kit:` references.
// The validator rejects any `kit:` that doesn't resolve to the catalog.

Map<String, Map<String, Object?>>? _catalogIndexCache;

Map<String, Map<String, Object?>> _catalogIndex() {
  final cached = _catalogIndexCache;
  if (cached != null) return cached;
  final out = <String, Map<String, Object?>>{};
  final f = File('tool/fixtures/ds-catalog.json');
  if (f.existsSync()) {
    try {
      final decoded = jsonDecode(f.readAsStringSync());
      if (decoded is Map && decoded['components'] is List) {
        for (final c in decoded['components'] as List) {
          if (c is Map && c['kit'] is String) {
            out[c['kit'] as String] = c.cast<String, Object?>();
          }
        }
      }
    } catch (_) {}
  }
  _catalogIndexCache = out;
  return out;
}

Set<String> catalogKitNames() => _catalogIndex().keys.toSet();

const _regions = <String>{
  'header',
  'body.list',
  'body.section',
  'body.scroll',
  'body.form',
  'body.bento',
  'body.eyebrow',
  'body.tile',
  'body.wide',
  'body.hero',
  'footer',
  'fab',
  'overlay',
  'pullout',
  'inset',
};

bool _isKnownRegion(String r) => _regions.contains(r);

String sStr(Object? v) => v is String ? v : '';
List<Object?> sList(Object? v) => v is List ? v : const <Object?>[];

/// Resolve the `components[]` for a route. An explicit top-level
/// `components[]` always wins; if it is missing or empty, derive the
/// manifest from `lookAndFeel.panels[]` so an author who already drew the
/// wireframe does not have to repeat every DS kit in two places.
///
/// The derivation is the *minimum* kit set for the auto-derived manifest:
/// each panel's `kind` decides the kit that fits the archetype. The author
/// can always list more (gestures, journeys, additional kit entries) on top.
List<Map<String, Object?>> _routeComponents(Map r) {
  final explicit = _listOf(r['components']).whereType<Map>().toList();
  if (explicit.isNotEmpty) return explicit.cast<Map<String, Object?>>();
  final lf = r['lookAndFeel'];
  if (lf is! Map) return <Map<String, Object?>>[];
  final panels = _listOf(lf['panels']).whereType<Map>().toList();
  if (panels.isEmpty) return <Map<String, Object?>>[];

  Map<String, Object?> mk(
    String kit,
    String region, {
    String? kind,
    String purpose = '',
    String why = '',
  }) {
    return <String, Object?>{
      'kit': kit,
      'region': region,
      if (kind != null) 'kind': kind,
      'purpose': purpose,
      'why': why,
      'rejected': <String>[],
      'a11y': <String, Object?>{},
      'props': <String, Object?>{},
    };
  }

  final out = <Map<String, Object?>>[];
  for (final p in panels) {
    final kind = sStr(p['kind']);
    final title = sStr(p['title']);
    switch (kind) {
      case 'hero':
        out.add(
          mk(
            'DSCard',
            'body.hero',
            kind: kind,
            purpose: title.isEmpty ? 'Hero panel' : title,
            why: 'The hero is a DSCard at body.hero proportions',
          ),
        );
        break;
      case 'tile':
        out.add(
          mk(
            'DSListTile',
            'body.tile',
            kind: kind,
            purpose: title.isEmpty ? 'List tile row' : title,
            why: 'The four-slot row the rest of the app rows are also',
          ),
        );
        break;
      case 'wide':
        out.add(
          mk(
            'DSListTile',
            'body.wide',
            kind: kind,
            purpose: title.isEmpty ? 'Wide bento card' : title,
            why: 'DSListTile stretches full-width at body.wide',
          ),
        );
        break;
      case 'list':
        out.add(
          mk(
            'DSSearchBar',
            'body.scroll',
            kind: kind,
            purpose: 'In-place search',
            why: 'Search in place is the archetype',
          ),
        );
        out.add(
          mk(
            'DSChipGroup',
            'body.scroll',
            kind: kind,
            purpose: 'Filter chips',
            why: 'The chip strip is the active-filter affordance',
          ),
        );
        if (sStr(p['swipe']).isNotEmpty) {
          out.add(
            mk(
              'DSDismissibleTile',
              'body.list',
              kind: kind,
              purpose: '${sStr(p['swipe'])} via swipe',
              why: 'Archival swipe is a DSDismissibleTile',
            ),
          );
        }
        break;
      case 'section':
        out.add(
          mk(
            'DSSettingsSection',
            'body.section',
            kind: kind,
            purpose: title.isEmpty ? 'Section' : title,
            why:
                'Detail sections are the same grouped-inset rows Settings uses',
          ),
        );
        break;
      case 'eyebrow-row':
        out.add(
          mk(
            'DSSettingsSection',
            'body.eyebrow',
            kind: kind,
            purpose: 'Grouped rows',
            why: 'Settings-style grouped inset rows by category',
          ),
        );
        break;
      case 'field-set':
        for (final f in _listOf(p['fields']).whereType<Map>()) {
          final label = sStr(f['label']);
          out.add(
            mk(
              'DSTextField',
              'body.form',
              purpose: label.isEmpty ? 'Field' : label,
              why: 'The kit owns the label / helper / validation contract',
            ),
          );
        }
        break;
    }
  }
  return out;
}

// --- vocabulary (shared with feature_plan.dart) -----------------------------

/// The twelve shapes `docs/principles/screen-archetypes.md` declares. A
/// thirteenth archetype is a change to that document first and to this list
/// second — and to `tool/feature_plan.dart`'s list third, and to
/// `superplan_lint.dart`'s required-kit table fourth.
const archetypes = <String>[
  'focal',
  'shelf',
  'collection',
  'detail',
  'form',
  'settings',
  'sequence',
  'offer',
  'insight',
  'session',
  'canvas',
  'confirmation',
  'conversation',
  'editor',
  'schedule',
];

/// The most detents a `canvas` sheet may settle at. Mirrors the constant in
/// `tool/feature_plan.dart`: peek, half, full.
const maxCanvasDetents = 3;

/// The most tiles a `shelf` rail may hold before it owes a "See all". Mirrors
/// the constant in `tool/feature_plan.dart`: past four the rail's end is more
/// than four swipes away.
const maxRailItems = 4;

/// What a `sequence` step is allowed to be for. Mirrors the constant in
/// `tool/feature_plan.dart`: a step that cannot name one of these is a step
/// nobody decided to build.
const stepJobs = <String>[
  'brand',
  'segmentation',
  'trust',
  'activation',
  'monetization',
  'retention',
];

/// The most plots an `insight` may draw. Mirrors the constant in
/// `tool/feature_plan.dart`: a recap with two charts is a dashboard, and a
/// dashboard is a screen that gets opened once.
const maxInsightCharts = 1;

/// The most plans an `offer` may show. Four is a pricing page, and a pricing
/// page is a web idiom.
const maxOfferPlans = 3;

/// What the superplan treats as a "module" — one slot per documented cross-
/// cutting seam. The values are tri-state: `required`, `none`, or `deferred`,
/// because a superplan that names every module and never says which are in
/// the MVP is a plan with no scope.
const moduleKeys = <String>[
  'auth',
  'onboarding',
  'paywall',
  'analytics',
  'push',
];

/// The four states a route owes, plus the fifth the `collection` archetype
/// adds because nothing matched and nothing exists are two different
/// screens. Mirrors the constant in `tool/feature_plan.dart`.
const requiredStates = <String>['loading', 'empty', 'error', 'success'];
const collectionExtraState = 'zeroResults';

// --- validation -------------------------------------------------------------

/// Empty when the plan can be drawn. Every message names the path it is
/// about, because a validator that only says "invalid" sends the author back
/// to read this file.
List<String> validateSuperPlan(Object? input) {
  final e = <String>[];
  void need(bool ok, String msg) {
    if (!ok) e.add(msg);
  }

  if (input is! Map) {
    return ['plan must be a JSON object'];
  }
  final plan = input;

  String? str(Object? v) => v is String ? v : null;
  bool filled(Object? v) => v is String && v.trim().isNotEmpty;

  // --- V0: top-level shape -------------------------------------------------

  final app = plan['app'];
  need(app is Map, 'app: required object');
  if (app is Map) {
    need(filled(app['name']), 'app.name: required');
    need(filled(app['oneLiner']), 'app.oneLiner: required');
    need(
      filled(app['problem']),
      'app.problem: required — a superplan with no '
      'problem statement cannot be reviewed',
    );
    need(
      filled(app['targetUsers']),
      'app.targetUsers: required — a superplan '
      'that does not name who it is for designs for nobody',
    );
    need(
      filled(app['industry']),
      'app.industry: required — feeds '
      'docs/references/industry-conventions.md',
    );
    final mvp = app['mvp'];
    need(mvp is Map, 'app.mvp: required object');
    if (mvp is Map) {
      need(mvp['in'] is List, 'app.mvp.in: required list — what the MVP ships');
      need(
        mvp['out'] is List,
        'app.mvp.out: required list — what is '
        'deferred, so scope is explicit',
      );
    }
  }

  // --- V10: decisions are shaped ------------------------------------------

  // The interview was the one step of this primitive with no artifact, so it
  // was the one step nothing could check — and an agent filling the fields
  // the validator names had no field that said "ask". `decisions[]` is that
  // field. The validator only checks its shape; requiring one at all is the
  // tree's business, so `superplan-lint` S8 owns that.
  final decisions = _listOf(plan['decisions']);
  for (var i = 0; i < decisions.length; i++) {
    final d = decisions[i];
    if (d is! Map) {
      e.add('decisions[$i]: must be an object');
      continue;
    }
    need(
      filled(d['question']),
      'decisions[$i].question: required — what was actually in question',
    );
    need(
      filled(d['answer']),
      'decisions[$i].answer: required — the call that was made',
    );
    final source = str(d['source']);
    need(
      source == 'user' || source == 'assumed',
      'decisions[$i].source: required — `user` if they answered it, '
      '`assumed` if you decided it for them. There is no third case.',
    );
    if (source == 'assumed') {
      final why = str(d['why']);
      need(
        why != null && why.trim().length >= 12,
        'decisions[$i].why: required (>= 12 chars) when `source` is '
        '`assumed` — an assumption with no reason is a guess wearing a '
        'decision\'s clothes',
      );
    }
  }

  // --- V0b: navigation -----------------------------------------------------

  final navigation = plan['navigation'];
  need(navigation is Map, 'navigation: required object');
  if (navigation is Map) {
    final tabs = navigation['tabs'];
    need(
      tabs is List && tabs.isNotEmpty,
      'navigation.tabs: at least one tab required — a tab bar with one tab '
      'is not a tab bar, but a superplan with no tab bar is missing the home '
      'shell',
    );
  }

  // --- V0c: modules ---------------------------------------------------------

  final modules = plan['modules'];
  need(modules is Map, 'modules: required object');
  if (modules is Map) {
    for (final k in moduleKeys) {
      if (!modules.containsKey(k)) {
        need(
          false,
          'modules.$k: required — must be `required`, `none`, or '
          '`deferred` (deferral is a decision, not a missing key)',
        );
        continue;
      }
      final v = modules[k];
      need(
        v == 'required' || v == 'none' || v == 'deferred',
        'modules.$k: must be one of `required | none | deferred` '
        '(got ${jsonEncode(v)})',
      );
    }
  }

  // --- V1: routes, archetype, panel ownership ------------------------------

  final routes = plan['routes'];
  need(
    routes is List && routes.isNotEmpty,
    'routes: at least one required — a superplan with no routes is a domain '
    'model with no app',
  );

  final list = routes is List ? routes : const [];
  final routeIds = <String>{};
  final tabsDeclared = navigation is Map && navigation['tabs'] is List
      ? (navigation['tabs'] as List).map((t) => '$t').toSet()
      : <String>{};
  final tabsRouted = <String>{};
  final endpointsSeen = <String>{};
  final componentWhysSeen = <String, int>{};

  for (var i = 0; i < list.length; i++) {
    final at = 'routes[$i]';
    final r = list[i];
    if (r is! Map) {
      e.add('$at: must be an object');
      continue;
    }

    final id = str(r['id']);
    need(filled(id), '$at.id: required kebab-case identifier');
    if (id != null) {
      need(
        RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(id),
        '$at.id: $id is not kebab-case',
      );
      need(
        !routeIds.contains(id),
        '$at.id: duplicate id "$id" — every route id is unique so feature_list '
        'can reference it without ambiguity',
      );
      routeIds.add(id);
    }

    need(filled(r['route']), '$at.route: required URL path');
    need(filled(r['name']), '$at.name: required');
    need(
      filled(r['purpose']),
      '$at.purpose: required — a route with no '
      'purpose belongs in the README, not the plan',
    );

    final archetype = str(r['archetype']);
    final knownArchetype = archetype != null && archetypes.contains(archetype);
    need(
      knownArchetype,
      '$at.archetype: must be one of ${archetypes.join(' | ')} '
      '(got ${jsonEncode(r['archetype'])})',
    );

    // V1: archetype-specific panel ownership. Mirrors `feature_plan.dart`
    // V1: the panel vocabulary is shared so a route and its feature cannot
    // disagree on what a panel is.
    final lookAndFeel = r['lookAndFeel'];
    final panels = lookAndFeel is Map ? lookAndFeel['panels'] : null;
    need(
      panels is List && panels.isNotEmpty,
      '$at.lookAndFeel.panels: at least one required — a route with no '
      'panels cannot be drawn',
    );

    if (panels is List && archetype != null) {
      final boxes = panels.whereType<Map>().toList();
      String kindOf(Map p) => str(p['kind']) ?? '';

      switch (archetype) {
        case 'focal':
          need(
            boxes.isNotEmpty && kindOf(boxes.first) == 'hero',
            '$at: focal starts with one panel of `kind: "hero"` — the hero is '
            'the archetype',
          );
          final rest = boxes.skip(1).toList();
          need(
            rest.length >= 2,
            '$at: focal needs a bento under the hero — at least two more '
            'panels',
          );
          need(
            rest.map(kindOf).toSet().length >= 2,
            '$at: the bento needs two sizes. Panels of one `kind` are six '
            'identical tiles',
          );
        case 'collection':
          final lists = boxes.where((p) => kindOf(p) == 'list').toList();
          need(
            lists.length == 1,
            '$at: collection is exactly one panel of `kind: "list"` — a second '
            'list on one screen is two screens',
          );
          if (lists.length == 1) {
            final l = lists.single;
            need(
              l['rows'] is List && (l['rows'] as List).isNotEmpty,
              '$at: the list panel needs `rows`',
            );
            need(
              filled(l['search']),
              '$at: `search` is required — search in place is part of the '
              'archetype',
            );
            need(
              l['filters'] is List && (l['filters'] as List).isNotEmpty,
              '$at: `filters` is required — the chip strip is what shows which '
              'filter is active',
            );
            need(
              filled(l['swipe']),
              '$at: `swipe` is required — name the action the swipe performs',
            );
            need(
              filled(l['swipeTwin']),
              '$at: `swipeTwin` is required — the twin is the half that gets '
              'dropped, and a reader using VoiceOver never has the swipe',
            );
          }
        case 'detail':
          need(
            filled(r['primaryAction']),
            '$at: detail pins a primary action, so name it',
          );
        case 'form':
          final withFields = boxes
              .where(
                (p) => p['fields'] is List && (p['fields'] as List).isNotEmpty,
              )
              .toList();
          need(
            withFields.length == 1,
            '$at: form is one column — exactly one panel carrying `fields`',
          );
          need(
            filled(r['primaryAction']),
            '$at: form pins a full-width primary action, so name it',
          );
        case 'settings':
          for (var j = 0; j < boxes.length; j++) {
            need(
              filled(boxes[j]['eyebrow']),
              '$at.panels[$j].eyebrow: required — a settings group with no '
              'heading is a list',
            );
            need(
              boxes[j]['rows'] is List && (boxes[j]['rows'] as List).isNotEmpty,
              '$at.panels[$j].rows: required',
            );
          }
        case 'sequence':
          final steps = boxes.where((p) => kindOf(p) == 'step').toList();
          need(
            steps.length >= 2,
            '$at: sequence is at least two panels of `kind: "step"` — one '
            'step is a form with a progress bar drawn on it',
          );
          for (var j = 0; j < steps.length; j++) {
            final job = str(steps[j]['job']);
            need(
              job != null && stepJobs.contains(job),
              '$at.panels[$j].job: must be one of ${stepJobs.join(' | ')} — a '
              'step that cannot name its job is a step nobody decided to '
              'build',
            );
          }
          need(
            filled(r['progress']),
            '$at.progress: required — say how the user knows where they are',
          );
          need(
            filled(r['back']),
            '$at.back: required — say what Back does. Back that loses an '
            'answer is the defect this key exists to surface',
          );
          need(
            filled(r['handover']),
            '$at.handover: required — name the route the last step hands over '
            'to. A sequence that ends on itself is one the user leaves',
          );
        case 'shelf':
          final rails = boxes.where((p) => kindOf(p) == 'rail').toList();
          need(
            rails.length >= 2,
            '$at: a shelf is at least two panels of `kind: "rail"` — one rail '
            'is a section, and a screen of one section is a collection',
          );
          final heroes = boxes.where((p) => kindOf(p) == 'hero').toList();
          need(
            heroes.length <= 1,
            '$at: a shelf has at most one hero. Two heroes is a grid whose '
            'cells are too big',
          );
          if (heroes.length == 1) {
            need(
              identical(boxes.first, heroes.single),
              '$at: the hero is the first panel — a hero under a rail is a '
              'rail the user scrolled past to reach it',
            );
          }
          for (final rail in rails) {
            need(
              filled(rail['title']),
              '$at.lookAndFeel.panels: every rail needs a `title` saying why '
              'it is here. A rail that cannot name its reason is a rail '
              'nobody asked for',
            );
            final items = rail['items'];
            need(
              items is List && items.isNotEmpty,
              '$at.lookAndFeel.panels: rail `${rail['title']}` needs `items`',
            );
            if (items is List && items.length > maxRailItems) {
              need(
                filled(rail['seeAll']),
                '$at.lookAndFeel.panels: rail `${rail['title']}` holds '
                '${items.length} items, so it needs `seeAll` naming the route '
                'it opens. Past $maxRailItems the end is more than four '
                'swipes away',
              );
            }
          }
        case 'session':
          final stages = boxes.where((p) => kindOf(p) == 'stage').toList();
          need(
            stages.length == 1,
            '$at: session is exactly one panel of `kind: "stage"` — the thing '
            'that is happening. A second stage is a second session',
          );
          need(
            filled(r['nowPlaying']),
            '$at.nowPlaying: required — what is playing, in text. A filled '
            'bar and a picture are both silent to a screen reader',
          );
          final transport = r['transport'];
          need(
            transport is List && transport.isNotEmpty,
            '$at.transport: required — the controls, named. They read the '
            'playback state rather than keeping their own',
          );
          need(
            filled(r['escape']),
            '$at.escape: required — how the user leaves without stopping it. '
            'A down-chevron, not a back arrow',
          );
          need(
            !filled(r['primaryAction']),
            '$at.primaryAction: a session pins nothing. The transport is the '
            'chrome, and a pinned bar under a player is a second bottom edge',
          );
        case 'canvas':
          final grounds = boxes.where((p) => kindOf(p) == 'ground').toList();
          need(
            grounds.length == 1,
            '$at: canvas is exactly one panel of `kind: "ground"` — the space '
            'the controls sit over',
          );
          final sheets = boxes.where((p) => kindOf(p) == 'sheet').toList();
          need(
            sheets.length == 1,
            '$at: canvas is exactly one panel of `kind: "sheet"`. A second '
            'sheet over a map is a dialog wearing a sheet\'s shape',
          );
          if (sheets.length == 1) {
            final detents = sheets.single['detents'];
            need(
              detents is List &&
                  detents.length >= 2 &&
                  detents.length <= maxCanvasDetents,
              '$at: the sheet needs 2 to $maxCanvasDetents named `detents` — '
              'peek, half, full',
            );
            need(
              filled(sheets.single['peek']),
              '$at: the sheet needs `peek` — what stays visible on the ground '
              'at the smallest detent',
            );
          }
          need(
            !filled(r['primaryAction']),
            '$at.primaryAction: a canvas pins nothing — the sheet owns the '
            'bottom edge',
          );
        case 'confirmation':
          final receipts = boxes.where((p) => kindOf(p) == 'receipt').toList();
          need(
            receipts.length == 1,
            '$at: confirmation is exactly one panel of `kind: "receipt"` — '
            'what was ordered, booked or sent',
          );
          need(
            filled(r['outcome']),
            '$at.outcome: required — what happened, in the past tense and in '
            'the user\'s words. "Your order is placed", not "Success"',
          );
          need(
            filled(r['reference']),
            '$at.reference: required — the identifier, and it is selectable',
          );
          need(
            filled(r['next']),
            '$at.next: required — what happens next, with a date on it. '
            '"Arrives Thursday 12 March", not "soon"',
          );
          need(
            filled(r['handover']),
            '$at.handover: required — the one way onward. A confirmation is '
            'the last screen of a flow, not the last screen of the app',
          );
        case 'schedule':
          final days = boxes.where((p) => kindOf(p) == 'day').toList();
          need(
            days.length == 1,
            '$at: schedule is exactly one panel of `kind: "day"` \u2014 the grid '
            'itself',
          );
          need(
            filled(r['window']),
            '$at.window: required \u2014 the hours the day opens on, and it is a '
            'hint rather than a crop',
          );
          need(
            filled(r['empty']),
            '$at.empty: required \u2014 what a day with nothing on it says, and '
            'how it offers to be filled',
          );
          need(
            filled(r['create']),
            '$at.create: required \u2014 how something new is added to the day',
          );
        case 'editor':
          final docs = boxes.where((p) => kindOf(p) == 'document').toList();
          need(
            docs.length == 1,
            '$at: editor is exactly one panel of `kind: "document"` \u2014 the '
            'work itself',
          );
          need(
            filled(r['autosave']),
            '$at.autosave: required \u2014 what saving means here. A save state '
            'nobody can predict is one nobody trusts',
          );
          need(
            filled(r['undo']),
            '$at.undo: required \u2014 what undo covers, and how far back',
          );
          need(
            filled(r['exit']),
            '$at.exit: required \u2014 what happens on back with unsaved work',
          );
          need(
            !filled(r['primaryAction']),
            '$at.primaryAction: an editor pins its toolbar, not a button \u2014 '
            'the keyboard owns the bottom edge',
          );
        case 'conversation':
          final threads = boxes
              .where((p) => kindOf(p) == 'transcript')
              .toList();
          need(
            threads.length == 1,
            '$at: conversation is exactly one panel of `kind: "transcript"` '
            '\u2014 the thread itself',
          );
          final turns = threads.isEmpty
              ? const <Map>[]
              : _listOf(threads.single['turns']).whereType<Map>().toList();
          need(
            turns.length >= 2,
            '$at.turns: a conversation is drawn with at least two turns. One '
            'turn is a message; two are a thread',
          );
          need(
            turns.map((t) => str(t['author'])).toSet().length >= 2,
            '$at.turns: both speakers appear. A transcript with one voice in '
            'it is a list, and belongs in a collection',
          );
          need(
            filled(r['composer']),
            '$at.composer: required \u2014 what the user writes into, in the '
            'words the field shows when it is empty',
          );
          need(
            filled(r['retry']),
            '$at.retry: required \u2014 what a turn that did not send offers. '
            'The failed turn is the one thing on the screen the user can '
            'still act on',
          );
          need(
            filled(r['empty']),
            '$at.empty: required \u2014 what the screen says before the first '
            'turn',
          );
          need(
            !filled(r['primaryAction']),
            '$at.primaryAction: a conversation pins the composer and nothing '
            'else',
          );
        case 'insight':
          final plots = boxes.where((p) => kindOf(p) == 'chart').toList();
          need(
            plots.length == maxInsightCharts,
            '$at: insight is exactly $maxInsightCharts panel of `kind: '
            '"chart"` — two plots on a recap is a dashboard, and a recap '
            'with none is a stat tile',
          );
          need(
            filled(r['headline']),
            '$at.headline: required — the one figure, in the user\'s units. '
            '`4h 12m`, not `252`',
          );
          need(
            filled(r['comparison']),
            '$at.comparison: required — what the figure is measured against, '
            'drawn beside it. A number with nothing to compare it to is '
            'trivia',
          );
          need(
            filled(r['period']),
            '$at.period: required — the span the figure covers. A figure '
            'whose denominator is a guess is one the user quietly distrusts',
          );
          need(
            filled(r['reading']),
            '$at.reading: required — one sentence saying what the number '
            'means, in plain language. This is the part every analytics '
            'screen skips and the only part a person repeats to somebody '
            'else',
          );
          need(
            filled(r['handover']),
            '$at.handover: required — name the screen this recap leads to. '
            'An insight that ends on itself is one the user closes',
          );
          need(
            !filled(r['primaryAction']),
            '$at.primaryAction: an insight pins nothing and submits nothing. '
            'The handover is an ordinary control at the end of the scroll, '
            'so name it in `handover` and leave this out',
          );
        case 'offer':
          final priced = boxes.where((p) => kindOf(p) == 'plans').toList();
          need(
            priced.length == 1,
            '$at: offer is exactly one panel of `kind: "plans"` — two plan '
            'tables on one screen is a pricing page',
          );
          if (priced.length == 1) {
            final raw = priced.single['plans'];
            final rows = raw is List
                ? raw.whereType<Map>().toList()
                : const <Map>[];
            need(
              rows.isNotEmpty && rows.length <= maxOfferPlans,
              '$at: between 1 and $maxOfferPlans plans — four is a pricing '
              'page, not a paywall',
            );
            for (var j = 0; j < rows.length; j++) {
              need(
                filled(rows[j]['period']) && filled(rows[j]['price']),
                '$at: plans[$j] needs both `period` and `price` — a plan '
                'whose price is not beside its period is the row a user '
                'misreads',
              );
            }
          }
          need(
            filled(r['outcome']),
            '$at.outcome: required — what the user gets, in their words, not '
            'what the tier is called',
          );
          need(
            filled(r['primaryAction']),
            '$at: offer pins a primary naming the purchase, so name it. '
            '"Continue" is not the name of a purchase',
          );
          need(
            filled(r['billing']),
            '$at.billing: required — renewal amount, charge date and how to '
            'cancel, in plain language, drawn adjacent to the primary',
          );
          need(
            filled(r['restore']),
            '$at.restore: required — say where Restore purchases lives. On '
            'iOS a paywall without it is a review rejection',
          );
          need(
            filled(r['terms']),
            '$at.terms: required — say where terms and privacy live',
          );
      }
    }

    // --- V2: four states (+ zeroResults for collection) --------------------

    final states = r['states'];
    for (final st in requiredStates) {
      need(
        states is Map && filled(states[st]),
        '$at.states.$st: required — every async surface renders all four '
        'states',
      );
    }
    if (archetype == 'collection') {
      need(
        states is Map && filled(states[collectionExtraState]),
        '$at.states.$collectionExtraState: required for a collection — '
        'nothing matched and nothing exists are two different screens',
      );
    }

    // --- V3: endpoints unique + entity refs resolve ------------------------

    final apis = r['apis'];
    if (apis is Map) {
      for (
        var j = 0;
        j < (apis['endpoints'] as List? ?? const []).length;
        j++
      ) {
        final ep = (apis['endpoints'] as List)[j];
        if (ep is! Map) {
          e.add('$at.apis.endpoints[$j]: must be an object');
          continue;
        }
        need(filled(ep['path']), '$at.apis.endpoints[$j].path: required');
        need(filled(ep['method']), '$at.apis.endpoints[$j].method: required');
        final method = str(ep['method'])?.toUpperCase() ?? '';
        final path = str(ep['path']) ?? '';
        if (path.isNotEmpty) {
          final key = '$method $path';
          need(
            !endpointsSeen.contains(key),
            '$at.apis.endpoints[$j]: duplicate endpoint "$key" — endpoints '
            'across the superplan are unique so a route never quietly '
            'depends on the same URL meaning two things',
          );
          endpointsSeen.add(key);
        }
      }
    }

    // --- V4: every component has a `why` -----------------------------------

    // Backwards-compat: pre-flutter-045 used `bestPractices.components[]`.
    // Surface a clear migration message rather than silently failing.
    final legacyComponents = r['bestPractices'] is Map
        ? (r['bestPractices'] as Map)['components']
        : null;
    final newComponents = r['components'];
    if (legacyComponents is List && legacyComponents.isNotEmpty) {
      need(
        false,
        '$at: `bestPractices.components[]` is the pre-flutter-045 shape. '
        'Move every entry to top-level `components[]` with `kit`, '
        '`purpose`, `region`, `why` and `a11y` fields.',
      );
    }
    final componentsList = newComponents is List ? newComponents : <Object?>[];
    if (componentsList.isEmpty) {
      // Components are required unless the route already carries
      // `lookAndFeel.panels[]` — the renderer derives a kit manifest
      // from the panel kinds so an author does not have to repeat the
      // same kit info in two places.
      final lfForDerivation = r['lookAndFeel'];
      final panelsForDerivation = lfForDerivation is Map
          ? _listOf(lfForDerivation['panels']).whereType<Map>().toList()
          : const <Map>[];
      if (panelsForDerivation.isEmpty) {
        need(
          false,
          '$at.components: required — at least one DS component per route, '
          'either explicitly in `components[]` or derivable from '
          '`lookAndFeel.panels[]` (the renderer does the derivation).',
        );
      }
    }
    for (var j = 0; j < componentsList.length; j++) {
      final c = componentsList[j];
      if (c is! Map) {
        e.add('$at.components[$j]: must be an object');
        continue;
      }
      need(
        filled(c['kit']),
        '$at.components[$j].kit: required — the DS component name',
      );
      need(filled(c['purpose']), '$at.components[$j].purpose: required');
      final why = str(c['why']);
      need(
        why != null && why.trim().length >= 12,
        '$at.components[$j].why: required (>= 12 chars)',
      );
      final region = str(c['region']);
      if (region != null && region.isNotEmpty) {
        need(
          _isKnownRegion(region),
          '$at.components[$j].region: "$region" is not a known region. '
          'Use one of: ${_regions.join(", ")}',
        );
      }
      final kit = str(c['kit']);
      if (kit != null && kit.isNotEmpty) {
        final catalog = _catalogIndex();
        if (catalog.isNotEmpty && !catalog.containsKey(kit)) {
          need(
            false,
            '$at.components[$j].kit: "$kit" is not in the DS catalog '
            '(tool/fixtures/ds-catalog.json)',
          );
        }
        componentWhysSeen.update('$at/$kit', (n) => n + 1, ifAbsent: () => 1);
      }
    }

    // --- V7: layout regions are valid --------------------------------------
    final layout = r['layout'];
    if (layout is Map) {
      final regions = layout['regions'];
      if (regions is! List || regions.isEmpty) {
        need(
          false,
          '$at.layout.regions: required list — a screen with no regions '
          'is a screen with no skeleton',
        );
      } else {
        for (var j = 0; j < regions.length; j++) {
          final reg = regions[j];
          if (reg is! Map) continue;
          final name = str(reg['name']) ?? '';
          final kit = str(reg['kit']);
          final kits = reg['kits'] is List ? reg['kits'] as List : const [];
          if (name.isNotEmpty) {
            final first = name.split('.').first;
            need(
              _regions.contains(name) || _regions.contains(first),
              '$at.layout.regions[$j].name: "$name" is not a known region',
            );
          }
          if (kit == null && kits.isEmpty) {
            need(
              false,
              '$at.layout.regions[$j]: required `kit` (single) or `kits` '
              '(list)',
            );
          }
          if (kit != null) {
            final catalog = _catalogIndex();
            if (catalog.isNotEmpty && !catalog.containsKey(kit)) {
              need(
                false,
                '$at.layout.regions[$j].kit: "$kit" is not in the DS '
                'catalog',
              );
            }
          }
          for (var k = 0; k < kits.length; k++) {
            final kKit = str(kits[k]);
            if (kKit == null) continue;
            final cleanKit = kKit.replaceFirst(RegExp(r'\s+×\s+\d+$'), '');
            final catalog = _catalogIndex();
            if (catalog.isNotEmpty && !catalog.containsKey(cleanKit)) {
              need(
                false,
                '$at.layout.regions[$j].kits[$k]: "$cleanKit" is not '
                'in the DS catalog',
              );
            }
          }
        }
      }
    }

    // --- V8: gestures are shaped ------------------------------------------

    // The renderer draws a gesture table from these entries. Until this rule
    // existed the table was the only reader, so a gesture missing its
    // `behavior` rendered as a blank cell instead of failing the plan.
    final gesturesList = _listOf(r['gestures']).toList();
    for (var j = 0; j < gesturesList.length; j++) {
      final g = gesturesList[j];
      if (g is! Map) {
        e.add('$at.gestures[$j]: must be an object');
        continue;
      }
      need(
        filled(g['selector']),
        '$at.gestures[$j].selector: required — what the finger lands on',
      );
      need(
        filled(g['event']),
        '$at.gestures[$j].event: required — tap, longPress, swipe, drag',
      );
      need(
        filled(g['behavior']),
        '$at.gestures[$j].behavior: required — what the gesture does',
      );
    }

    // --- V9: journeys are shaped ------------------------------------------

    final journeysList = _listOf(r['journeys']).toList();
    for (var j = 0; j < journeysList.length; j++) {
      final jr = journeysList[j];
      if (jr is! Map) {
        e.add('$at.journeys[$j]: must be an object');
        continue;
      }
      need(filled(jr['name']), '$at.journeys[$j].name: required');
      need(
        filled(jr['trace']),
        '$at.journeys[$j].trace: required — the path through the app, '
        'one string',
      );
    }

    // --- V6: tabs union ----------------------------------------------------

    final tab = str(r['tab']);
    if (tab != null && tab.isNotEmpty) {
      tabsRouted.add(tab);
    }
  }

  if (navigation is Map) {
    final declared = tabsDeclared;
    final missing = declared.difference(tabsRouted);
    final extra = tabsRouted.difference(declared);
    for (final t in missing) {
      e.add(
        'navigation.tabs: "$t" is declared but no route uses it — drop '
        'it from navigation.tabs, or mark the route with `tab: "$t"`',
      );
    }
    for (final t in extra) {
      e.add(
        'navigation.tabs: route uses `tab: "$t"` but it is not in '
        'navigation.tabs — add it to navigation.tabs, or remove the '
        'route\'s `tab` field if the route is pushed (not a tab root)',
      );
    }
  }

  // --- V5: sprint.depends + sprint.order -----------------------------------

  final ordersSeen = <int, String>{};
  for (var i = 0; i < list.length; i++) {
    final at = 'routes[$i]';
    final r = list[i];
    if (r is! Map) continue;
    final sprint = r['sprint'];
    if (sprint is! Map) {
      e.add('$at.sprint: required object');
      continue;
    }
    final order = sprint['order'];
    need(order is int, '$at.sprint.order: required integer');
    if (order is int) {
      need(
        !ordersSeen.containsKey(order),
        '$at.sprint.order: $order is a duplicate — every route has a unique '
        'sprint order so the build sequence is unambiguous',
      );
      ordersSeen[order] = str(r['id']) ?? at;
    }
    final depends = sprint['depends'];
    if (depends is List) {
      for (var j = 0; j < depends.length; j++) {
        final dep = str(depends[j]);
        need(
          dep != null && routeIds.contains(dep),
          '$at.sprint.depends[$j]: "$dep" does not resolve to a route id '
          'in this plan — sprint dependencies are routes, not anything else',
        );
      }
    }
    final size = sprint['size'];
    need(
      size == 'S' || size == 'M' || size == 'L',
      '$at.sprint.size: must be one of `S | M | L` (got ${jsonEncode(size)})',
    );
  }

  // --- V3b: shared entity refs resolve --------------------------------------

  final sharedEntities = plan['sharedEntities'];
  final sharedNames = <String>{};
  if (sharedEntities is List) {
    for (var i = 0; i < sharedEntities.length; i++) {
      final e = sharedEntities[i];
      if (e is! Map) continue;
      final n = str(e['name']);
      if (n != null) sharedNames.add(n);
    }
  }

  for (var i = 0; i < list.length; i++) {
    final r = list[i];
    if (r is! Map) continue;
    final apis = r['apis'];
    if (apis is! Map) continue;
    final entities = apis['entities'];
    if (entities is! List) continue;
    for (var j = 0; j < entities.length; j++) {
      final ent = entities[j];
      if (ent is Map) {
        final n = str(ent['name']);
        // An inline entity (no `name` of its own but fields of its own) is
        // fine. A reference-by-name must resolve to a sharedEntity.
        if (n != null && ent['fields'] == null) {
          need(
            sharedNames.contains(n),
            'routes[$i].apis.entities[$j]: "$n" references an entity that is '
            'not in sharedEntities[] — inline the fields here, or add it to '
            'sharedEntities[]',
          );
        }
        continue;
      }
      if (ent is String) {
        need(
          sharedNames.contains(ent),
          'routes[$i].apis.entities[$j]: "$ent" references a shared entity '
          'that is not declared in sharedEntities[]',
        );
      }
    }
  }

  return e;
}

// --- ascii primitives (shared with feature_plan.dart) -----------------------

/// The phone. 38 columns outer, which is the widest frame that still sits
/// inside a fenced block in a terminal-width diff. Same number as the
/// per-feature renderer — the two are visually the same artifact at two
/// levels, and matching widths makes them stack.
const _phoneW = 38;
const _bodyW = _phoneW - 4;

const _minBodyRows = 16;

String _pad(Object? s, int n) {
  final t = '${s ?? ''}';
  if (t.length > n) {
    return n <= 1 ? t.substring(0, n) : '${t.substring(0, n - 1)}…';
  }
  return t + ' ' * (n - t.length);
}

String _centre(Object? s, int n) {
  final t = '${s ?? ''}';
  if (t.length >= n) return _pad(t, n);
  final left = (n - t.length) ~/ 2;
  return ' ' * left + t + ' ' * (n - t.length - left);
}

String _rule(int n) => '─' * n;

List<String> _boxOf(int w, List<String> rows) {
  final inner = w - 2;
  final out = <String>['┌${_rule(inner)}┐'];
  for (final r in rows) {
    out.add(r == '---' ? '├${_rule(inner)}┤' : '│${_pad(r, inner)}│');
  }
  out.add('└${_rule(inner)}┘');
  return out;
}

List<String> _hjoin(List<List<String>> blocks, [int gap = 1]) {
  final widths = blocks
      .map((b) => b.fold<int>(0, (m, l) => l.length > m ? l.length : m))
      .toList();
  final height = blocks.fold<int>(0, (m, b) => b.length > m ? b.length : m);
  final spacer = ' ' * gap;
  final out = <String>[];
  for (var i = 0; i < height; i++) {
    final row = <String>[];
    for (var j = 0; j < blocks.length; j++) {
      row.add(_pad(i < blocks[j].length ? blocks[j][i] : '', widths[j]));
    }
    out.add(row.join(spacer).replaceAll(RegExp(r'\s+$'), ''));
  }
  return out;
}

List<String> _columnize(List<Object?> rows, int width) {
  if (rows.isEmpty) return const [];
  final cells = rows
      .map((r) => (r is List ? r : [r]).map((v) => '${v ?? ''}').toList())
      .toList();
  final cols = cells.fold<int>(0, (m, c) => c.length > m ? c.length : m);
  final w = <int>[];
  for (var c = 0; c < cols; c++) {
    w.add(
      cells.fold<int>(
        0,
        (m, r) => (c < r.length ? r[c].length : 0) > m ? r[c].length : m,
      ),
    );
  }
  return cells.map((r) {
    final parts = <String>[];
    for (var c = 0; c < cols; c++) {
      final v = c < r.length ? r[c] : '';
      parts.add(c == cols - 1 && cols > 1 ? v.padLeft(w[c]) : _pad(v, w[c]));
    }
    return _pad(parts.join('  ').trimRight(), width);
  }).toList();
}

List<Object?> _listOf(Object? v) => v is List ? v : const [];
String _str(Object? v) => v is String ? v : '';

// --- panels (per-route rendering) -------------------------------------------

List<String> _panelBox(Map p, int w) {
  final inner = w - 2;
  final rows = <String>[];
  if (_str(p['eyebrow']).isNotEmpty) {
    rows.add(' ${_pad(_str(p['eyebrow']).toUpperCase(), inner - 2)} ');
  }
  if (_str(p['title']).isNotEmpty) {
    final badge = _str(p['badge']).isNotEmpty ? _str(p['badge']) : '';
    final title = _str(p['title']);
    final line = badge.isEmpty
        ? _pad(title, inner - 2)
        : '${_pad(title, inner - 2 - badge.length - 1)} $badge';
    rows.add(' $line ');
    if (_str(p['subtitle']).isNotEmpty) {
      rows.add(' ${_pad(_str(p['subtitle']), inner - 2)} ');
    }
    if (_listOf(p['rows']).isNotEmpty || _listOf(p['fields']).isNotEmpty) {
      rows.add(' ${_rule(inner - 2)} ');
    }
  }
  for (final line in _columnize(_listOf(p['rows']), inner - 2)) {
    rows.add(' $line ');
  }
  final fields = _listOf(p['fields']).whereType<Map>().toList();
  if (fields.isNotEmpty) {
    for (final f in fields) {
      rows.add(' ${_pad(_str(f['label']), inner - 2)} ');
      rows.add(' [ ${_pad(_str(f['placeholder']), inner - 6)} ]');
      if (_str(f['helper']).isNotEmpty) {
        rows.add(' ${_pad(_str(f['helper']), inner - 2)} ');
      }
    }
  }
  if (_str(p['footer']).isNotEmpty) {
    rows.add(' ${_rule(inner - 2)} ');
    rows.add(' ${_pad(_str(p['footer']), inner - 2)} ');
  }
  final actions = _listOf(p['actions']).map((a) => '[ $a ]').join('  ');
  if (actions.isNotEmpty) {
    rows.add(' ${_pad(actions, inner - 2)} ');
  }
  return _boxOf(w, rows);
}

List<String> _focalBody(Map r) {
  final panels = _listOf(
    (r['lookAndFeel'] as Map?)?['panels'],
  ).whereType<Map>().toList();
  final out = <String>[];
  if (panels.isNotEmpty) {
    out.addAll(_panelBox(panels.first, _bodyW));
    out.add('');
  }
  final rest = panels.skip(1).toList();
  var i = 0;
  while (i < rest.length) {
    final p = rest[i];
    if (_str(p['kind']) == 'tile' &&
        i + 1 < rest.length &&
        _str(rest[i + 1]['kind']) == 'tile') {
      const left = (_bodyW - 1) ~/ 2;
      out.addAll(
        _hjoin([
          _panelBox(p, left),
          _panelBox(rest[i + 1], _bodyW - 1 - left),
        ], 1),
      );
      i += 2;
    } else {
      out.addAll(_panelBox(p, _bodyW));
      i += 1;
    }
    if (i < rest.length) out.add('');
  }
  return out;
}

List<String> _collectionBody(Map r) {
  final panels = _listOf(
    (r['lookAndFeel'] as Map?)?['panels'],
  ).whereType<Map>().toList();
  final list = panels.firstWhere(
    (p) => _str(p['kind']) == 'list',
    orElse: () => panels.isEmpty ? <String, Object?>{} : panels.first,
  );
  final out = <String>[];
  out.add('[ ⌕ ${_pad(_str(list['search']), _bodyW - 6)} ]');
  out.add('');
  final chips = _listOf(list['filters']).map((f) => '( $f )').toList();
  final strip = <String>[];
  var line = '';
  for (final c in chips) {
    if (line.isNotEmpty && line.length + 1 + c.length > _bodyW) {
      strip.add('$line ▸');
      line = '';
      break;
    }
    line = line.isEmpty ? c : '$line $c';
  }
  if (line.isNotEmpty) strip.add(_pad(line, _bodyW));
  out.addAll(strip);
  out.add('');
  out.add(_rule(_bodyW));
  for (final row in _columnize(_listOf(list['rows']), _bodyW - 2)) {
    out.add(' $row');
    out.add(_rule(_bodyW));
  }
  if (_str(list['swipe']).isNotEmpty) {
    out.add('');
    out.add(_pad('◂ swipe: ${list['swipe']}', _bodyW));
    out.add(_pad('  also on: ${list['swipeTwin']}', _bodyW));
  }
  for (final p in panels.where((p) => !identical(p, list))) {
    out.add('');
    out.addAll(_panelBox(p, _bodyW));
  }
  return out;
}

List<String> _detailBody(Map r) {
  final out = <String>[];
  for (final p in _listOf(
    (r['lookAndFeel'] as Map?)?['panels'],
  ).whereType<Map>()) {
    out.addAll(_panelBox(p, _bodyW));
    out.add('');
  }
  if (out.isNotEmpty) out.removeLast();
  return out;
}

List<String> _formBody(Map r) {
  final out = <String>[];
  for (final p in _listOf(
    (r['lookAndFeel'] as Map?)?['panels'],
  ).whereType<Map>()) {
    final fields = _listOf(p['fields']).whereType<Map>().toList();
    if (_str(p['title']).isEmpty && fields.isNotEmpty) {
      for (final f in fields) {
        out.add(_pad(_str(f['label']), _bodyW));
        out.add('[ ${_pad(_str(f['placeholder']), _bodyW - 4)} ]');
        if (_str(f['helper']).isNotEmpty) {
          out.add(_pad(_str(f['helper']), _bodyW));
        }
        out.add('');
      }
      if (out.isNotEmpty) out.removeLast();
    } else {
      out.addAll(_panelBox(p, _bodyW));
    }
    out.add('');
  }
  if (out.isNotEmpty) out.removeLast();
  return out;
}

List<String> _settingsBody(Map r) {
  final out = <String>[];
  for (final p in _listOf(
    (r['lookAndFeel'] as Map?)?['panels'],
  ).whereType<Map>()) {
    out.add(_pad(_str(p['eyebrow']).toUpperCase(), _bodyW));
    final box = Map<String, Object?>.from(p);
    box.remove('eyebrow');
    final footer = _str(box.remove('footer'));
    out.addAll(_panelBox(box, _bodyW));
    if (footer.isNotEmpty) {
      for (final l in _wrap(footer, _bodyW)) {
        out.add(_pad(l, _bodyW));
      }
    }
    out.add('');
  }
  if (out.isNotEmpty) out.removeLast();
  return out;
}

/// The progress row, then one box per step with the job it does printed under
/// it — a reviewer looking at six steps all labelled `brand` can cut five of
/// them, and a reviewer reading a page count cannot.
List<String> _sequenceBody(Map r) {
  final steps = _listOf(
    (r['lookAndFeel'] as Map?)?['panels'],
  ).whereType<Map>().where((p) => _str(p['kind']) == 'step').toList();
  final out = <String>[];
  final dots = List<String>.generate(
    steps.length,
    (i) => i == 0 ? '●' : '○',
  ).join(' ');
  out.add(_pad('$dots  ${_str(r['progress'])}', _bodyW));
  out.add('');
  for (var i = 0; i < steps.length; i++) {
    final box = Map<String, Object?>.from(steps[i]);
    final job = _str(box.remove('job'));
    box['title'] = '${i + 1}. ${_str(box['title'])}';
    // The copy is what the step actually asks, and a step drawn as a title
    // alone is a page count with a name on it. Wrapped into `rows` rather
    // than `subtitle`, which is one truncated line.
    final body = _str(box.remove('body'));
    if (body.isNotEmpty && _listOf(box['rows']).isEmpty) {
      box['rows'] = _wrap(body, _bodyW - 6);
    }
    out.addAll(_panelBox(box, _bodyW));
    out.add(_pad('   job: $job', _bodyW));
    out.add('');
  }
  out.add(_pad('◂ back: ${_str(r['back'])}', _bodyW));
  out.add(_pad('▸ then: ${_str(r['handover'])}', _bodyW));
  return out;
}

/// Outcome, dated trial, plans, then the proof — in that order, because the
/// The figure with its comparison on the same line, the period under it, the
/// plot, then the sentence. Mirrors `_insightBody` in `feature_plan.dart`:
/// the comparison is drawn inside the figure's box so a plan cannot show the
/// two separated, which is the defect the rule names.
List<String> _insightBody(Map r) {
  final panels = _listOf(r['panels']).whereType<Map>().toList();
  final plot = panels.firstWhere(
    (p) => _str(p['kind']) == 'chart',
    orElse: () => <String, Object?>{},
  );
  final out = <String>[];
  out.addAll(
    _boxOf(_bodyW, <String>[
      ' ${_pad(_str(r['headline']), _bodyW - 4)} ',
      ' ${_pad('${_str(r['comparison'])}  \u00b7  ${_str(r['period'])}', _bodyW - 4)} ',
    ]),
  );
  if (plot.isNotEmpty) {
    out.add('');
    out.addAll(_panelBox(plot, _bodyW));
  }
  out.add('');
  for (final l in _wrap('\u201c${_str(r['reading'])}\u201d', _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  for (final p in panels.where((p) => !identical(p, plot))) {
    out.add('');
    out.addAll(_panelBox(p, _bodyW));
  }
  out.add('');
  out.add(_pad('\u25b8 then: ${_str(r['handover'])}', _bodyW));
  return out;
}

/// order is the archetype. The billing line and the footer links belong to
/// the frame, drawn under the pinned primary, which is the adjacency the rule
/// is about.
List<String> _offerBody(Map r) {
  final panels = _listOf(
    (r['lookAndFeel'] as Map?)?['panels'],
  ).whereType<Map>().toList();
  final plans = panels.firstWhere(
    (p) => _str(p['kind']) == 'plans',
    orElse: () => panels.isEmpty ? <String, Object?>{} : panels.first,
  );
  final out = <String>[];
  for (final l in _wrap(_str(r['outcome']), _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  if (_str(r['trial']).isNotEmpty) {
    out.add('');
    out.add(_pad('⌛ ${_str(r['trial'])}', _bodyW));
  }
  for (final row in _listOf(plans['plans']).whereType<Map>()) {
    out.add('');
    final badge = _str(row['badge']);
    final head = badge.isEmpty
        ? _str(row['period'])
        : '${_str(row['period'])}  ($badge)';
    out.addAll(
      _boxOf(_bodyW, <String>[
        ' ${_pad(head, _bodyW - 4)} ',
        ' ${_pad(_str(row['price']), _bodyW - 4)} ',
      ]),
    );
  }
  for (final p in panels.where((p) => !identical(p, plans))) {
    out.add('');
    out.addAll(_panelBox(p, _bodyW));
  }
  return out;
}

/// A hero, then rails, each cut off at the right edge so the peek — the thing
/// that tells a user the row scrolls — is what the wireframe shows. Mirrors
/// `_shelfBody` in `feature_plan.dart`.
List<String> _shelfBody(Map r) {
  final panels = _listOf(
    (r['lookAndFeel'] as Map?)?['panels'],
  ).whereType<Map>().toList();
  final out = <String>[];
  final hero = panels.firstWhere(
    (p) => _str(p['kind']) == 'hero',
    orElse: () => <String, Object?>{},
  );
  if (hero.isNotEmpty) {
    out.addAll(_panelBox(hero, _bodyW));
    out.add('');
  }
  for (final rail in panels.where((p) => _str(p['kind']) == 'rail')) {
    final seeAll = _str(rail['seeAll']);
    final title = _str(rail['title']);
    out.add(
      seeAll.isEmpty
          ? _pad(title, _bodyW)
          : '${_pad(title, _bodyW - 10)} See all \u203a',
    );
    final cells = <List<String>>[];
    for (final t in _listOf(rail['items'])) {
      cells.add(<String>[
        '\u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2510',
        '\u2502      \u2502',
        '\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2518',
        _pad('$t', 8),
      ]);
    }
    if (cells.isEmpty) {
      out.add(_pad('(no items)', _bodyW));
    } else {
      for (final l in _hjoin(cells)) {
        out.add(l.length > _bodyW ? l.substring(0, _bodyW) : _pad(l, _bodyW));
      }
    }
    out.add('');
  }
  if (out.isNotEmpty) out.removeLast();
  for (final p in panels.where(
    (p) => _str(p['kind']) != 'rail' && !identical(p, hero),
  )) {
    out.add('');
    out.addAll(_panelBox(p, _bodyW));
  }
  return out;
}

/// The stage, what is playing, the scrubber, the transport. No pinned bar,
/// because a session has none. Mirrors `_sessionBody` in `feature_plan.dart`.
List<String> _sessionBody(Map r) {
  final panels = _listOf(
    (r['lookAndFeel'] as Map?)?['panels'],
  ).whereType<Map>().toList();
  final stage = panels.firstWhere(
    (p) => _str(p['kind']) == 'stage',
    orElse: () => panels.isEmpty ? <String, Object?>{} : panels.first,
  );
  final out = <String>[];
  out.add(_pad('\u2304  ${_str(r['escape'])}', _bodyW));
  out.add('');
  if (stage.isNotEmpty) out.addAll(_panelBox(stage, _bodyW));
  out.add('');
  for (final l in _wrap(_str(r['nowPlaying']), _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  out.add('');
  out.add(
    _pad(
      '\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u25cf'
      '${'\u2500' * (_bodyW - 24)}',
      _bodyW - 12,
    ),
  );
  out.add('${_pad('1:12', _bodyW - 6)}-2:48');
  out.add('');
  // Chunked rather than joined, for the reason `_sessionBody` in
  // `feature_plan.dart` gives: a control truncated at the frame's edge is one
  // nobody notices is missing.
  var line = '';
  for (final c in _listOf(r['transport']).map((c) => '[ $c ]')) {
    if (line.isEmpty) {
      line = c;
    } else if ('$line $c'.length <= _bodyW) {
      line = '$line $c';
    } else {
      out.add(_centre(line, _bodyW));
      line = c;
    }
  }
  if (line.isNotEmpty) out.add(_centre(line, _bodyW));
  for (final p in panels.where((p) => !identical(p, stage))) {
    out.add('');
    out.addAll(_panelBox(p, _bodyW));
  }
  return out;
}

/// The ground with the sheet at its smallest detent, which is the state the
/// archetype is most often broken in. Mirrors `_canvasBody` in
/// `feature_plan.dart`.
List<String> _canvasBody(Map r) {
  final panels = _listOf(
    (r['lookAndFeel'] as Map?)?['panels'],
  ).whereType<Map>().toList();
  final ground = panels.firstWhere(
    (p) => _str(p['kind']) == 'ground',
    orElse: () => <String, Object?>{},
  );
  final sheet = panels.firstWhere(
    (p) => _str(p['kind']) == 'sheet',
    orElse: () => <String, Object?>{},
  );
  final out = <String>[];
  out.add(_centre('\u00b7 ${_str(ground['title'])} \u00b7', _bodyW));
  out.add(_centre(_str(sheet['peek']), _bodyW));
  out.add('');
  out.add('${_pad('', _bodyW - 3)}(\u2316)');
  out.add('');
  out.add(_centre('\u2581\u2581\u2581\u2581', _bodyW));
  final rows = <String>[' ${_pad(_str(sheet['title']), _bodyW - 4)} '];
  for (final row in _listOf(sheet['rows'])) {
    rows.add(' ${_pad('$row', _bodyW - 4)} ');
  }
  rows.add('---');
  rows.add(
    ' ${_pad(_listOf(sheet['detents']).join('  \u00b7  '), _bodyW - 4)} ',
  );
  out.addAll(_boxOf(_bodyW, rows));
  for (final p in panels.where(
    (p) => !identical(p, ground) && !identical(p, sheet),
  )) {
    out.add('');
    out.addAll(_panelBox(p, _bodyW));
  }
  return out;
}

/// What happened, the identifier, the receipt, then what happens next. The way
/// onward is the pinned primary and is drawn by the frame. Mirrors
/// `_confirmationBody` in `feature_plan.dart`.
List<String> _confirmationBody(Map r) {
  final panels = _listOf(
    (r['lookAndFeel'] as Map?)?['panels'],
  ).whereType<Map>().toList();
  final receipt = panels.firstWhere(
    (p) => _str(p['kind']) == 'receipt',
    orElse: () => panels.isEmpty ? <String, Object?>{} : panels.first,
  );
  final out = <String>[];
  out.addAll(
    _boxOf(_bodyW, <String>[
      ' ${_pad('\u2713  ${_str(r['outcome'])}', _bodyW - 4)} ',
      ' ${_pad(_str(r['reference']), _bodyW - 4)} ',
    ]),
  );
  out.add('');
  if (receipt.isNotEmpty) out.addAll(_panelBox(receipt, _bodyW));
  out.add('');
  for (final l in _wrap('\u25b8 next: ${_str(r['next'])}', _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  if (_str(r['undo']).isNotEmpty) {
    out.add('');
    for (final l in _wrap('\u21ba ${_str(r['undo'])}', _bodyW)) {
      out.add(_pad(l, _bodyW));
    }
  }
  out.add('');
  out.add(_pad('\u25b8 then: ${_str(r['handover'])}', _bodyW));
  for (final p in panels.where((p) => !identical(p, receipt))) {
    out.add('');
    out.addAll(_panelBox(p, _bodyW));
  }
  return out;
}

/// The thread, drawn the way it is read: oldest at the top, the newest turn
/// last and nearest the composer. Mirrors `_conversationBody` in
/// `feature_plan.dart`.
List<String> _conversationBody(Map r) {
  final panels = _listOf(r['panels']).whereType<Map>().toList();
  final thread = panels
      .where((p) => _str(p['kind']) == 'transcript')
      .firstOrNull;
  final turns = thread == null
      ? const <Map>[]
      : _listOf(thread['turns']).whereType<Map>().toList();
  const bubbleW = _bodyW - 8;
  final out = <String>[];

  for (final t in turns) {
    final mine = _str(t['author']) == 'me';
    final state = _str(t['state']);
    final rows = <String>[];
    for (final l in _wrap(_str(t['text']), bubbleW - 4)) {
      rows.add(' ${_pad(l, bubbleW - 4)} ');
    }
    if (state.isNotEmpty && state != 'sent') {
      final mark = switch (state) {
        'sending' => '⟳ sending',
        'streaming' => '▌ arriving',
        'failed' => '! not sent · ${_str(r['retry'])}',
        _ => state,
      };
      rows.add(' ${_pad(mark, bubbleW - 4)} ');
    }
    for (final l in _boxOf(bubbleW, rows)) {
      out.add(_pad(mine ? '${' ' * (_bodyW - bubbleW)}$l' : l, _bodyW));
    }
    out.add('');
  }

  if (turns.isEmpty) {
    for (final l in _wrap('(empty) ${_str(r['empty'])}', _bodyW)) {
      out.add(_pad(l, _bodyW));
    }
    out.add('');
  }

  for (final p in panels.where((p) => !identical(p, thread))) {
    out.addAll(_panelBox(p, _bodyW));
    out.add('');
  }

  const inner = _bodyW - 2;
  out.addAll(
    _boxOf(_bodyW, <String>[
      '${_pad(' ${_str(r['composer'])}', inner - 3)}↑  ',
    ]),
  );
  return out;
}

/// The work, then the bar over it. Mirrors `_editorBody` in
/// `feature_plan.dart`.
List<String> _editorBody(Map r) {
  final panels = _listOf(r['panels']).whereType<Map>().toList();
  final doc = panels.where((p) => _str(p['kind']) == 'document').firstOrNull;
  final out = <String>[];

  if (doc != null) {
    final rows = <String>[];
    for (final l in _wrap(_str(doc['title']), _bodyW - 4)) {
      rows.add(' ${_pad(l, _bodyW - 4)} ');
    }
    rows.add(' ${_pad('', _bodyW - 4)} ');
    for (final item in _listOf(doc['items']).take(3)) {
      rows.add(' ${_pad('$item', _bodyW - 4)} ');
    }
    rows.add(' ${_pad('▌', _bodyW - 4)} ');
    out.addAll(_boxOf(_bodyW, rows));
    out.add('');
  }

  for (final p in panels.where((p) => !identical(p, doc))) {
    out.addAll(_panelBox(p, _bodyW));
    out.add('');
  }

  final barRows = <String>[' ${_pad('B  I  •  ⌄${' ' * 6}↶  ↷', _bodyW - 4)} '];
  // Wrapped, not truncated: the sentence that says what saving means is the
  // one an implementer reads off the drawing.
  for (final l in _wrap('☁ ${_str(r['autosave'])}', _bodyW - 4)) {
    barRows.add(' ${_pad(l, _bodyW - 4)} ');
  }
  out.addAll(_boxOf(_bodyW, barRows));
  out.add('');
  for (final l in _wrap('↶ undo: ${_str(r['undo'])}', _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  for (final l in _wrap('← back: ${_str(r['exit'])}', _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  return out;
}

/// A day: the strip that picks it, then the hours. Mirrors `_scheduleBody` in
/// `feature_plan.dart`.
List<String> _scheduleBody(Map r) {
  final panels = _listOf(r['panels']).whereType<Map>().toList();
  final day = panels.where((p) => _str(p['kind']) == 'day').firstOrNull;
  final out = <String>[];

  out.addAll(
    _boxOf(_bodyW, <String>[
      ' ${_pad('‹  M  T  W [T] F  S  S  ›', _bodyW - 4)} ',
    ]),
  );
  out.add('');
  for (final l in _wrap('⌚ ${_str(r['window'])}', _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  out.add('');

  final slots = day == null
      ? const <Object?>[]
      : _listOf(day['slots']).whereType<Map>().toList();
  const half = (_bodyW - 1) ~/ 2;
  for (final slot in slots) {
    final at = _str((slot as Map)['at']);
    final title = _str(slot['title']);
    final clash = _str(slot['clash']);
    if (clash.isEmpty) {
      for (final l in _boxOf(_bodyW, <String>[
        ' ${_pad('$at  $title', _bodyW - 4)} ',
      ])) {
        out.add(_pad(l, _bodyW));
      }
    } else {
      final left = _boxOf(half, <String>[' ${_pad(title, half - 4)} ']);
      final right = _boxOf(half, <String>[' ${_pad(clash, half - 4)} ']);
      for (final row in _hjoin(<List<String>>[left, right])) {
        out.add(_pad(row, _bodyW));
      }
    }
    out.add('');
  }

  if (slots.isEmpty) {
    for (final l in _wrap('(empty) ${_str(r['empty'])}', _bodyW)) {
      out.add(_pad(l, _bodyW));
    }
    out.add('');
  }

  for (final l in _wrap('+ ${_str(r['create'])}', _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  return out;
}

List<String> _bodyFor(Map r) {
  switch (_str(r['archetype'])) {
    case 'focal':
      return _focalBody(r);
    case 'collection':
      return _collectionBody(r);
    case 'detail':
      return _detailBody(r);
    case 'form':
      return _formBody(r);
    case 'sequence':
      return _sequenceBody(r);
    case 'offer':
      return _offerBody(r);
    case 'insight':
      return _insightBody(r);
    case 'shelf':
      return _shelfBody(r);
    case 'session':
      return _sessionBody(r);
    case 'canvas':
      return _canvasBody(r);
    case 'confirmation':
      return _confirmationBody(r);
    case 'conversation':
      return _conversationBody(r);
    case 'editor':
      return _editorBody(r);
    case 'schedule':
      return _scheduleBody(r);
    default:
      return _settingsBody(r);
  }
}

List<String> _phone(Map r, {List<Object?> tabs = const []}) {
  const inner = _phoneW - 2;
  final archetype = _str(r['archetype']);
  final large = archetype == 'detail' || archetype == 'collection';
  final pushed = _str(r['tab']).isEmpty;

  final out = <String>['┌${_rule(inner)}┐'];
  out.add('│${_pad(' 9:41', inner - 10)}${_pad('▮▮▮  ▮▮', 10)}│');
  out.add('├${_rule(inner)}┤');

  final leading = pushed ? ' ‹ ' : '   ';
  final trailing = _listOf(r['secondaryActions']).isEmpty ? '   ' : ' ⋯ ';
  final barTitle = large ? '' : _str(r['name']);
  out.add('│$leading${_pad(barTitle, inner - 6)}$trailing│');

  final body = <String>[];
  if (large) {
    body.add(_str(r['name']));
    if (_str(r['subtitle']).isNotEmpty) body.add(_str(r['subtitle']));
    body.add('');
  }
  body.addAll(_bodyFor(r));
  while (body.length < _minBodyRows) {
    body.add('');
  }

  out.add('├${_rule(inner)}┤');
  for (final l in body) {
    out.add('│ ${_pad(l, inner - 2)} │');
  }

  final primary = _str(r['primaryAction']);
  const pinned = <String>{
    'detail',
    'form',
    'sequence',
    'offer',
    'confirmation',
  };
  if (primary.isNotEmpty && pinned.contains(archetype)) {
    out.add('├${_rule(inner)}┤');
    final icon = archetype == 'detail' ? '[ ● ] ' : '';
    final w = inner - 2 - icon.length;
    out.add('│ $icon[${_centre(primary, w - 2)}] │');
    if (archetype == 'offer') {
      // Under the button, inside the same bar. A renewal line the pinned
      // chrome covers is one the user meets at the charge instead of the tap.
      for (final l in _wrap(_str(r['billing']), inner - 2)) {
        out.add('│ ${_pad(l, inner - 2)} │');
      }
      out.add(
        '│ ${_pad('${_str(r['restore'])}  ·  ${_str(r['terms'])}', inner - 2)} │',
      );
    }
  } else if (primary.isNotEmpty) {
    out.add('│ ${_pad('', inner - 2 - 14)}${_pad('( + $primary )', 14)} │');
  }

  if (tabs.isNotEmpty && !pushed) {
    out.add('├${_rule(inner)}┤');
    final active = _str(r['tab']);
    final each = (inner - 2) ~/ tabs.length;
    final cells = StringBuffer();
    for (var i = 0; i < tabs.length; i++) {
      final label = '${tabs[i] == active ? '●' : '○'} ${tabs[i]}';
      cells.write(
        _centre(label, i == tabs.length - 1 ? inner - 2 - each * i : each),
      );
    }
    out.add('│ ${_pad(cells.toString(), inner - 2)} │');
  }
  out.add('│${_centre(_rule(12), inner)}│');
  out.add('└${_rule(inner)}┘');
  return out;
}

List<String> _wrap(String text, int n) {
  final words = text.split(RegExp(r'\s+'));
  final lines = <String>[];
  var line = '';
  for (final w in words) {
    if ('$line $w'.trim().length > n) {
      if (line.isNotEmpty) lines.add(line.trim());
      line = w;
    } else {
      line = '$line $w'.trim();
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines;
}

List<String> _statesGrid(Map r) {
  const w = 24;
  final states = r['states'] is Map ? r['states'] as Map : const {};
  final labels = <String>['loading', 'empty'];
  final notes = <String>['skeleton mirrors rows', 'one action, 3 lines max'];
  final bodies = <List<String>>[
    [
      '▓▓▓▓▓▓▓▓▓  ▓▓▓▓',
      '▓▓▓▓▓▓▓▓▓  ▓▓▓▓',
      '▓▓▓▓▓▓▓▓▓  ▓▓▓▓',
      '▓▓▓▓▓▓▓▓▓  ▓▓▓▓',
    ],
    [
      ..._wrap(_str(states['empty']), w - 4),
      if (_str(r['primaryAction']).isNotEmpty) ...[
        '',
        '[ ${r['primaryAction']} ]',
      ],
    ],
  ];
  if (_str(states['zeroResults']).isNotEmpty) {
    labels.add('zero results');
    notes.add('clears the filter');
    bodies.add([
      ..._wrap(_str(states['zeroResults']), w - 4),
      '',
      '[ Clear filters ]',
    ]);
  }
  labels.add('error');
  notes.add('retry, never a raw error');
  bodies.add([
    '⚠',
    ..._wrap(_str(states['error']), w - 4),
    '',
    '[ Try again ]',
  ]);

  final tall = bodies.fold<int>(0, (m, b) => b.length > m ? b.length : m);
  final cells = <List<String>>[];
  for (var i = 0; i < bodies.length; i++) {
    final rows = [
      ...bodies[i],
      ...List.filled(tall - bodies[i].length, ''),
    ].map((l) => ' ${_pad(l, w - 3)}').toList();
    cells.add([
      _centre(labels[i], w),
      ..._boxOf(w, rows),
      _centre(notes[i], w),
    ]);
  }
  return _hjoin(cells, 3);
}

String _fence(List<String> lines) =>
    '```\n${lines.join('\n').replaceAll(RegExp(r'[ \t]+$', multiLine: true), '')}\n```';

// --- markdown ----------------------------------------------------------------

List<String> _renderRoute(Map r, List<Object?> tabs) {
  final out = <String>[];
  final route = _str(r['route']);
  out.add('### ${r['name']}${route.isEmpty ? '' : ' · `$route`'}');
  out.add('');
  final purpose = _str(r['purpose']);
  out.add(
    'Archetype: `${r['archetype']}`${purpose.isEmpty ? '' : ' — $purpose'}',
  );
  out.add('');
  out.add('**Phone @390**');
  out.add('');
  out.add(_fence(_phone(r, tabs: tabs)));
  out.add('');
  out.add('**States**');
  out.add('');
  out.add(_fence(_statesGrid(r)));
  out.add('');
  out.add('Success: ${(r['states'] as Map)['success']}');
  out.add('');

  // Look & feel — header / motion / dark mode (the four dimensions that
  // describe what the screen looks like, beyond the wireframe).
  final lookAndFeel = r['lookAndFeel'] is Map
      ? r['lookAndFeel'] as Map
      : const <String, Object?>{};
  if (lookAndFeel.isNotEmpty) {
    out.add('**Look & feel**');
    out.add('');
    for (final key in ['header', 'motion', 'darkMode']) {
      final v = _str(lookAndFeel[key]);
      if (v.isNotEmpty) {
        out.add('- **${_humanise(key)}:** $v');
      }
    }
    out.add('');
  }

  // Layout — the screen's skeleton, region by region, with kit names.
  // This is the second artifact per route: the visual frame above shows
  // the *content*; this section below shows the *structure* that holds it.
  final layoutR = r['layout'] is Map ? r['layout'] as Map : const {};
  if (layoutR.isNotEmpty) {
    final regions = _listOf(layoutR['regions']).whereType<Map>().toList();
    if (regions.isNotEmpty) {
      out.add('**Layout (region → kit)**');
      out.add('');
      out.add('| Region | Kit | Purpose |');
      out.add('| --- | --- | --- |');
      for (final reg in regions) {
        final name = _str(reg['name']);
        final kit = _str(reg['kit']);
        final kits = _listOf(
          reg['kits'],
        ).map((k) => _str(k)).where((s) => s.isNotEmpty);
        final kitCol = kit.isNotEmpty
            ? '`$kit`'
            : (kits.isNotEmpty ? kits.map((k) => '`$k`').join(', ') : '—');
        final purpose = _str(reg['purpose']);
        out.add('| `$name` | $kitCol | ${purpose.isEmpty ? '—' : purpose} |');
      }
      final scrollStrategy = _str(layoutR['scrollStrategy']);
      final pinned = _listOf(layoutR['pinned']).map((p) => '`$p`').toList();
      final safeTop = layoutR['safeAreaTop'] == true ? '✓ top' : '';
      final safeBottom = layoutR['safeAreaBottom'] == true ? '✓ bottom' : '';
      final meta = <String>[
        if (scrollStrategy.isNotEmpty) 'scroll `$scrollStrategy`',
        if (pinned.isNotEmpty) 'pinned: ${pinned.join(', ')}',
        if (safeTop.isNotEmpty) 'safe area $safeTop',
        if (safeBottom.isNotEmpty) 'safe area $safeBottom',
      ];
      if (meta.isNotEmpty) {
        out.add('');
        out.add(meta.join(' · '));
      }
      out.add('');
    }
  }

  // Components — the per-screen manifest. New richer shape, drawn from
  // the catalog so a superplan cannot cite a `kit:` that doesn't exist.
  final componentsR = _routeComponents(r);
  if (componentsR.isNotEmpty) {
    out.add('**Components (${componentsR.length})**');
    out.add('');
    out.add('| Kit | Region | Purpose | Why | Not |');
    out.add('| --- | --- | --- | --- | --- |');
    final catalog = _catalogIndex();
    for (final c in componentsR) {
      final kit = _str(c['kit']);
      final entry = catalog[kit];
      final kindHint = entry != null ? ' _(${_str(entry['kind'])})_' : '';
      final region = _str(c['region']);
      final why = _str(c['why']);
      final rejected = _listOf(
        c['rejected'],
      ).whereType<String>().where((s) => s.isNotEmpty).toList();
      final purpose = _str(c['purpose']);
      out.add(
        '| `$kit`$kindHint | `${region.isEmpty ? '—' : region}` '
        '| ${purpose.isEmpty ? '—' : purpose} '
        '| $why '
        '| ${rejected.isEmpty ? '—' : rejected.map((r) => '`$r`').join(', ')} |',
      );
    }
    out.add('');
  }

  // Best practices — accessibility / design-system rules / verification /
  // non-goals. Components moved to top-level `components[]` in flutter-045.
  final bestPractices = r['bestPractices'] is Map
      ? r['bestPractices'] as Map
      : const <String, Object?>{};
  if (bestPractices.isNotEmpty) {
    for (final key in const [
      'accessibility',
      'designSystemRules',
      'verification',
      'nonGoals',
    ]) {
      final list = _listOf(bestPractices[key]);
      if (list.isEmpty) continue;
      out.add('**Best practices — ${_humanise(key)}**');
      out.add('');
      for (final item in list) {
        out.add('- $item');
      }
      out.add('');
    }
  }

  // Gestures — selector → event → behavior per route.
  final gestures = _listOf(r['gestures']).whereType<Map>().toList();
  if (gestures.isNotEmpty) {
    out.add('**Gestures (${gestures.length})**');
    out.add('');
    out.add('| Selector | Event | Behaviour | Haptic |');
    out.add('| --- | --- | --- | --- |');
    for (final g in gestures) {
      final selector = _str(g['selector']);
      final event = _str(g['event']);
      final behaviour = _str(g['behavior']);
      final haptic = _str(g['haptic']);
      out.add(
        '| `$selector` | `$event` | $behaviour | '
        '${haptic.isEmpty ? '—' : haptic} |',
      );
    }
    out.add('');
  }

  // Journeys — user flows that pass through this route.
  final journeys = _listOf(r['journeys']).whereType<Map>().toList();
  if (journeys.isNotEmpty) {
    out.add('**Journeys (${journeys.length})**');
    out.add('');
    for (final j in journeys) {
      final name = _str(j['name']);
      final trace = _str(j['trace']);
      final happy = j['happy'] == true ? ' ✓ happy path' : '';
      out.add('- **$name**$happy');
      if (trace.isNotEmpty) {
        out.add('  - `$trace`');
      }
    }
    out.add('');
  }

  // APIs — entities, endpoints, providers, integration.
  final apis = r['apis'] is Map ? r['apis'] as Map : const <String, Object?>{};
  if (apis.isNotEmpty) {
    out.add('**APIs required**');
    out.add('');
    final entities = _listOf(apis['entities']).whereType<Map>().toList();
    final entityNames = _listOf(apis['entities'])
        .map((e) => _str(e is Map ? e['name'] : e))
        .where((n) => n.isNotEmpty)
        .toSet();
    if (entities.isNotEmpty || entityNames.isNotEmpty) {
      out.add('- **Entities:** ${entityNames.join(', ')}');
    }
    final endpoints = _listOf(apis['endpoints']).whereType<Map>().toList();
    if (endpoints.isNotEmpty) {
      out.add('');
      out.add('| Method | Path | Auth | Purpose |');
      out.add('| --- | --- | --- | --- |');
      for (final e in endpoints) {
        out.add(
          '| ${e['method']} | `${e['path']}` | '
          '${e['auth'] == true ? 'yes' : 'no'} | ${_str(e['purpose'])} |',
        );
      }
    }
    final providers = _listOf(apis['providers']);
    if (providers.isNotEmpty) {
      out.add('');
      out.add('- **Providers:** ${providers.join(', ')}');
    }
    final integration = _listOf(apis['integration']).whereType<Map>().toList();
    if (integration.isNotEmpty) {
      out.add('');
      out.add('| From | To | Note |');
      out.add('| --- | --- | --- |');
      for (final i in integration) {
        out.add(
          '| `${_str(i['from'])}` | `${_str(i['to'])}` | ${_str(i['note'])} |',
        );
      }
    }
    out.add('');
  }

  // Blast radius — same shape as the per-feature renderer.
  final blast = r['blastRadius'];
  if (blast is Map) {
    final lines = <String>[];
    void tree(String label, List<Object?> files) {
      if (files.isEmpty) return;
      if (lines.isNotEmpty) lines.add('');
      lines.add('$label (${files.length})');
      for (var i = 0; i < files.length; i++) {
        lines.add('  ${i == files.length - 1 ? '└──' : '├──'} ${files[i]}');
      }
    }

    tree('new', _listOf(blast['new']));
    tree('changed', _listOf(blast['changed']));
    if (lines.isNotEmpty) {
      out.add('**Blast radius**');
      out.add('');
      out.add(_fence(lines));
      out.add('');
    }
  }

  // Sprint — order, depends, size, gate.
  final sprint = r['sprint'] is Map
      ? r['sprint'] as Map
      : const <String, Object?>{};
  if (sprint.isNotEmpty) {
    final size = _str(sprint['size']);
    final order = sprint['order'];
    final depends = _listOf(sprint['depends']);
    final gate = _listOf(sprint['gate']);
    out.add('**Sprint**');
    out.add('');
    final bits = <String>['order `$order`', 'size `$size`'];
    if (depends.isNotEmpty) {
      bits.add('depends on ${depends.join(', ')}');
    }
    out.add('- ${bits.join(', ')}');
    if (gate.isNotEmpty) {
      out.add('');
      out.add('Verification gate:');
      for (final g in gate) {
        out.add('- `$g`');
      }
    }
    out.add('');
  }

  return out;
}

String _humanise(String k) {
  if (k.isEmpty) return k;
  // `darkMode` -> `Dark mode`, `nonGoals` -> `Non-goals`, `designSystemRules` ->
  // `Design-system rules`.
  const named = <String, String>{
    'darkMode': 'Dark mode',
    'nonGoals': 'Non-goals',
    'designSystemRules': 'Design-system rules',
  };
  if (named.containsKey(k)) return named[k]!;
  // Generic camel -> spaced: insert space before uppercase letters.
  final out = StringBuffer();
  for (var i = 0; i < k.length; i++) {
    final c = k[i];
    if (i > 0 && c.toUpperCase() == c && c.toLowerCase() != c) {
      out.write(' ');
    }
    out.write(c);
  }
  return out.toString()[0].toUpperCase() + out.toString().substring(1);
}

List<String> _renderCodingList(
  String heading,
  List<Object?> items, {
  String key = 'name',
}) {
  if (items.isEmpty) return const [];
  final out = <String>['## $heading', ''];
  for (final item in items) {
    if (item is Map) {
      final name = _str(item[key]);
      // Entities, providers and mocks annotate with `note`; dependencies
      // annotate with `why`, because a new pubspec line is a justification,
      // not a remark. Reading only `note` silently dropped every dependency's
      // reason — including the ones recorded as rejections.
      final noteText = _str(item['note']);
      final why = _str(item['why']);
      final annotation = noteText.isNotEmpty ? noteText : why;
      out.add('- **$name**${annotation.isEmpty ? '' : ' — $annotation'}');
    } else {
      out.add('- $item');
    }
  }
  out.add('');
  return out;
}

String renderSuperPlanMarkdown(Object? input) {
  final errors = validateSuperPlan(input);
  if (errors.isNotEmpty) {
    throw ArgumentError(
      'Invalid superplan:\n${errors.map((e) => '  - $e').join('\n')}',
    );
  }
  final plan = input as Map;
  final app = plan['app'] as Map;
  final navigation = plan['navigation'] as Map;
  final modules = plan['modules'] as Map;
  final routes = _listOf(plan['routes']).whereType<Map>().toList();
  final tabs = _listOf(navigation['tabs']);
  final openQuestions = _listOf(plan['openQuestions']);

  final out = <String>[];
  out.add('<!-- super-plan:v1 — generated, do not hand-edit.');
  out.add(
    '     Regenerate with: dart run tool/super_plan.dart '
    'SUPERPLAN.json -o SUPERPLAN.md -->',
  );
  out.add('');
  out.add('# Superplan — ${app['name']}');
  out.add('');
  out.add('${app['oneLiner']}');
  out.add('');
  out.add('**Problem.** ${app['problem']}');
  out.add('');
  out.add('**Target users.** ${app['targetUsers']}');
  out.add('');
  out.add(
    '**Industry.** ${app['industry']} — see '
    '`docs/references/industry-conventions.md` for the design language '
    'this brief pulls from.',
  );
  out.add('');

  // Decisions — first, because the reader's first question about a plan
  // written for them is which parts of it they actually chose.
  final decisionList = _listOf(plan['decisions']).whereType<Map>().toList();
  if (decisionList.isNotEmpty) {
    final assumedCount = decisionList
        .where((d) => _str(d['source']) == 'assumed')
        .length;
    final userCount = decisionList.length - assumedCount;
    out.add('## Decisions');
    out.add('');
    out.add(
      '$userCount answered by you, $assumedCount assumed. Every assumption '
      'below is a question that was not asked — read those first.',
    );
    out.add('');
    out.add('| | Question | Call | Why |');
    out.add('| --- | --- | --- | --- |');
    for (final d in decisionList) {
      final source = _str(d['source']);
      final mark = source == 'user' ? 'you' : '**assumed**';
      final why = _str(d['why']);
      out.add(
        '| $mark | ${_str(d['question'])} | ${_str(d['answer'])} '
        '| ${why.isEmpty ? '—' : why} |',
      );
    }
    out.add('');
  }

  // MVP cut
  final mvp = app['mvp'] as Map;
  out.add('## MVP cut');
  out.add('');
  out.add('**In:**');
  for (final x in _listOf(mvp['in'])) {
    out.add('- $x');
  }
  out.add('');
  out.add('**Deferred (explicit):**');
  for (final x in _listOf(mvp['out'])) {
    out.add('- $x');
  }
  out.add('');

  // Non-goals (app-level)
  final nonGoals = _listOf(app['nonGoals']);
  if (nonGoals.isNotEmpty) {
    out.add('## App-level non-goals');
    out.add('');
    for (final n in nonGoals) {
      out.add('- $n');
    }
    out.add('');
  }

  // Navigation map — the ASCII tree, if provided, otherwise the tab list.
  out.add('## Navigation map');
  out.add('');
  if (tabs.isNotEmpty) {
    out.add(_fence(['tabs: ${tabs.join(' · ')}']));
  }
  final ascii = _str(navigation['ascii']);
  if (ascii.isNotEmpty) {
    out.add('');
    out.add(_fence(ascii.split('\n')));
  }
  out.add('');

  // Modules checklist
  out.add('## Modules');
  out.add('');
  out.add('| Module | Decision |');
  out.add('| --- | --- |');
  for (final k in moduleKeys) {
    final v = _str(modules[k]);
    if (v.isNotEmpty) {
      out.add('| `$k` | $v |');
    }
  }
  out.add('');

  // Theme (compact — token list, not full palette dump)
  final theme = plan['theme'];
  if (theme is Map) {
    final tokens = _listOf(theme['tokens']);
    if (tokens.isNotEmpty) {
      out.add('## Theme tokens');
      out.add('');
      for (final t in tokens) {
        out.add('- $t');
      }
      out.add('');
    }
  }

  // Dependencies — what the pubspec will gain.
  out.addAll(
    _renderCodingList(
      'Dependencies',
      _listOf(plan['dependencies']),
      key: 'name',
    ),
  );

  // Routes
  out.add('## Routes');
  out.add('');
  out.add(
    '${routes.length} route${routes.length == 1 ? '' : 's'}. Each renders a '
    'phone-frame wireframe from the same twelve archetypes the per-feature '
    '`FEATURE-PLAN.md` keys off, so the shape approved here and the shape '
    'approved per feature cannot drift.',
  );
  out.add('');
  for (final r in routes) {
    out.addAll(_renderRoute(r, tabs));
  }

  // Cross-cutting
  out.addAll(
    _renderCodingList(
      'Shared entities',
      _listOf(plan['sharedEntities']),
      key: 'name',
    ),
  );
  out.addAll(
    _renderCodingList('Shared providers', _listOf(plan['sharedProviders'])),
  );
  out.addAll(_renderCodingList('Shared mocks', _listOf(plan['sharedMocks'])));

  // Open questions
  if (openQuestions.isNotEmpty) {
    out.add('## Open questions');
    out.add('');
    for (final q in openQuestions) {
      out.add('- $q');
    }
    out.add('');
  }

  // Sprint order — the build sequence in one place.
  final orderable = routes.where((r) => r['sprint'] is Map).toList()
    ..sort((a, b) {
      final ao = ((a['sprint'] as Map)['order'] as int?) ?? 0;
      final bo = ((b['sprint'] as Map)['order'] as int?) ?? 0;
      return ao.compareTo(bo);
    });
  if (orderable.isNotEmpty) {
    out.add('## Sprint order');
    out.add('');
    out.add('| # | Route | Size | Depends on |');
    out.add('| --- | --- | --- | --- |');
    for (final r in orderable) {
      final sp = r['sprint'] as Map;
      final deps = _listOf(sp['depends']).join(', ');
      out.add(
        '| ${sp['order']} | `${_str(r['id'])}` | `${_str(sp['size'])}` | '
        '${deps.isEmpty ? '—' : deps} |',
      );
    }
    out.add('');
  }

  // Cross-route DS component inventory — the diagnostic that tells the
  // team *what's reused* (good — should be reused) and *what's unique*
  // (flag for review). Sorted by reuse count descending, then by name.
  // Same derivation as the per-route manifest, so an author who only
  // wrote `lookAndFeel.panels[]` still gets a populated inventory.
  final inventory = <String, List<String>>{};
  for (final r in routes) {
    final rid = _str(r['id']);
    for (final c in _routeComponents(r)) {
      final kit = _str(c['kit']);
      if (kit.isEmpty) continue;
      inventory.putIfAbsent(kit, () => <String>[]).add(rid);
    }
  }
  if (inventory.isNotEmpty) {
    final sorted = inventory.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.length.compareTo(a.value.length);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    out.add('## DS component inventory');
    out.add('');
    out.add(
      '${inventory.length} distinct kit components across ${routes.length} '
      'route${routes.length == 1 ? '' : 's'}. Sorted by reuse count '
      'descending; a kit used by 3+ routes is the visual vocabulary of the '
      'app, a kit used by exactly one deserves a second look.',
    );
    out.add('');
    out.add('| Kit | Used by | Uses |');
    out.add('| --- | --- | --- |');
    final catalog = _catalogIndex();
    for (final entry in sorted) {
      final usedBy = entry.value.toSet().toList()..sort();
      final entryCatalog = catalog[entry.key];
      final kind = entryCatalog != null ? _str(entryCatalog['kind']) : '—';
      out.add(
        '| `${entry.key}` _($kind)_ | ${usedBy.map((r) => '`$r`').join(', ')} '
        '| ${entry.value.length} |',
      );
    }
    out.add('');
  }

  // Footer
  out.add('---');
  out.add('');
  out.add('Approve this before any file under `lib/` is written. Every frame');
  out.add('above is drawn from this superplan\'s JSON, so the picture and the');
  out.add('build cannot drift; the archetypes are the twelve in');
  out.add(
    '`docs/principles/screen-archetypes.md`, which every demo screen names',
  );
  out.add('and `test/screens/archetypes_test.dart` holds them to.');
  out.add('');

  return out.join('\n');
}

// --- cli ---------------------------------------------------------------------

void main(List<String> args) {
  final file = args.firstWhere((a) => !a.startsWith('-'), orElse: () => '');
  if (file.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/super_plan.dart <plan.json> '
      '[-o SUPERPLAN.md] [--check]',
    );
    exit(2);
  }
  final source = File(file);
  if (!source.existsSync()) {
    stderr.writeln('super-plan: $file does not exist');
    exit(2);
  }

  Object? plan;
  try {
    plan = jsonDecode(source.readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('super-plan: $file is not valid JSON: ${e.message}');
    exit(1);
  }

  final errors = validateSuperPlan(plan);
  if (errors.isNotEmpty) {
    stderr.writeln('super-plan: ${errors.length} problem(s) in $file');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }

  final routes = _listOf((plan as Map)['routes']).length;
  if (args.contains('--check')) {
    stdout.writeln(
      'super-plan: $file is valid ($routes route${routes == 1 ? '' : 's'})',
    );
    exit(0);
  }

  final md = renderSuperPlanMarkdown(plan);
  final o = args.indexOf('-o');
  if (o != -1 && o + 1 < args.length) {
    File(args[o + 1]).writeAsStringSync(md);
    stdout.writeln(
      'super-plan: $routes route${routes == 1 ? '' : 's'} → ${args[o + 1]}',
    );
  } else {
    stdout.write(md);
  }
}
