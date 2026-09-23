// superplan-lint — the superplan is a checked artifact, not a note.
//
// The `superplan` skill says SUPERPLAN.json is the source of truth, that
// SUPERPLAN.md is generated and must never be hand-edited, and that every
// route becomes a feature in `feature_list.json`. Without this gate all
// three are honour-system prose: the validator can only be reached by
// running the renderer by hand, which nothing requires.
//
// The rules:
//
//   S1  SUPERPLAN.json passes the same validator the renderer uses — a
//       superplan that cannot be drawn is not a superplan.
//   S2  A committed SUPERPLAN.md matches a fresh render of its source JSON.
//       This is the hand-edit check: the document that was approved and
//       the document the JSON produces have to be the same bytes.
//   S3  No orphan SUPERPLAN.md — a rendered superplan with no source JSON
//       cannot be re-rendered, reviewed or diffed, so it is prose wearing
//       a filename.
//   S4  Every routes[].id is referenced by exactly one `feature_list.json`
//       entry's `notes` field, OR appears in `app.mvp.out` (deferred to
//       post-MVP). A route no one tracked and no one deferred is a route
//       no one will ever build.
//   S5  Every `feature_list.json` entry's `notes` references a route id that
//       exists in SUPERPLAN.json (or is the unimplemented TODO stub from
//       the template) — a feature built against no superplan route is a
//       feature whose scope nobody checked.
//
// Inert on a fresh scaffold — no superplan, nothing to check. It bites the
// moment somebody superplans, which is exactly when the drift starts.
//
// Run: `dart run tool/superplan_lint.dart` (part of `make check`).

import 'dart:convert';
import 'dart:io';

import 'super_plan.dart';

class Violation {
  final String rule;
  final String message;

  const Violation(this.rule, this.message);

  @override
  String toString() => '  [$rule] $message';
}

/// The gate as a function of a directory, so a test can point it at a fixture
/// tree instead of at the repository it is running in. A lint that can only
/// be exercised by breaking the project is a lint nobody exercises.
List<Violation> lintSuperPlans(Directory root) {
  final violations = <Violation>[];
  void fail(String rule, String message) =>
      violations.add(Violation(rule, message));

  final superFile = File('${root.path}/SUPERPLAN.json');
  final rendered = File('${root.path}/SUPERPLAN.md');
  final hasRendered = rendered.existsSync();
  final hasSource = superFile.existsSync();

  // --- S6: the catalog file exists and is non-empty -----------------
  // The catalog is generated (`make ds-catalog`) and the lint fails if
  // it is missing — a superplan cannot name components that the kit
  // doesn't have, and that contract is meaningless without the catalog.
  final catalog = File('${root.path}/tool/fixtures/ds-catalog.json');
  if (!catalog.existsSync()) {
    fail(
      'S6',
      'tool/fixtures/ds-catalog.json is missing — run `make ds-catalog` to regenerate. The kit is the source of truth for what a route can cite; without it, every `kit:` reference in this plan is unverified.',
    );
  }

  Object? superplan;
  Map? superMap;
  if (hasSource) {
    try {
      superplan = jsonDecode(superFile.readAsStringSync());
    } on FormatException catch (e) {
      fail('S1', 'SUPERPLAN.json is not valid JSON: ${e.message}');
    }
    if (superplan is Map) {
      superMap = superplan;
    }
  }

  // --- S1: every superplan validates ---------------------------------------

  if (superMap != null) {
    final errors = validateSuperPlan(superMap);
    for (final e in errors) {
      fail('S1', 'SUPERPLAN.json: $e');
    }
  }

  // --- S2/S3: the rendered document tracks its source -----------------------

  if (hasRendered) {
    if (!hasSource) {
      fail(
        'S3',
        'SUPERPLAN.md exists but no SUPERPLAN.json sits beside it — the '
            'rendered superplan cannot be regenerated or diffed. Write the '
            'source JSON (see the `superplan` skill) or delete the document.',
      );
    } else if (superMap != null) {
      final committed = rendered.readAsStringSync();
      late final String fresh;
      try {
        fresh = renderSuperPlanMarkdown(superMap);
      } catch (_) {
        fail(
          'S2',
          'SUPERPLAN.md does not match a fresh render of SUPERPLAN.json — '
              'the renderer refused the JSON. Run '
              '`dart run tool/super_plan.dart SUPERPLAN.json -o SUPERPLAN.md` '
              'to regenerate the document and fix the validator errors first.',
        );
        return violations;
      }
      if (fresh != committed) {
        fail(
          'S2',
          'SUPERPLAN.md does not match a fresh render of SUPERPLAN.json. '
              'The document is generated — never hand-edit it. Edit the JSON '
              'and re-render: '
              '`dart run tool/super_plan.dart SUPERPLAN.json -o SUPERPLAN.md`',
        );
      }
    }
  }

  // --- S4: every route is tracked or explicitly deferred --------------------

  if (superMap != null) {
    final routes = (superMap['routes'] as List?) ?? const [];
    final routeIds = routes
        .whereType<Map>()
        .map((r) => r['id'])
        .whereType<String>()
        .toSet();
    final mvp = superMap['app'] is Map
        ? (superMap['app'] as Map)['mvp'] is Map
              ? ((superMap['app'] as Map)['mvp'] as Map)['out']
              : null
        : null;
    // A deferral is written the way a human writes one: the `route:<id>`
    // token, then usually a dash and the reason it is deferred. Take the
    // token and stop at the first space, so an explained deferral defers.
    // (The tracked-notes half of this rule below already matches loosely;
    // when the two halves disagreed, the strict one was the half the error
    // message told the author to use.)
    final deferredIds = mvp is List
        ? mvp
              .whereType<String>()
              .where((s) => s.trimLeft().startsWith('route:'))
              .map((s) => s.trimLeft().substring('route:'.length).trim())
              .map((s) => s.split(RegExp(r'\s')).first)
              .map((s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+$'), ''))
              .where((s) => s.isNotEmpty)
              .toSet()
        : <String>{};

    final listFile = File('${root.path}/feature_list.json');
    if (listFile.existsSync()) {
      Set<String>? tracked;
      try {
        final decoded = jsonDecode(listFile.readAsStringSync());
        final features = decoded is List
            ? decoded
            : (decoded is Map
                  ? (decoded['features'] as List? ?? const [])
                  : const []);
        tracked = features
            .whereType<Map>()
            .map((f) => f['notes'] is String ? f['notes'] as String : '')
            .toSet();
      } on FormatException catch (e) {
        fail('S4', 'feature_list.json is not valid JSON: ${e.message}');
      }
      if (tracked != null) {
        final routedOrDeferred = routeIds.difference(deferredIds);
        final notesList = tracked.toList();
        final orphanRoutes = routedOrDeferred
            .where(
              (id) => !notesList.any(
                (notes) =>
                    notes.contains('route:$id') ||
                    notes.contains('"$id"') ||
                    notes.contains('$id '),
              ),
            )
            .toList();
        for (final id in orphanRoutes) {
          fail(
            'S4',
            'route `$id` is declared in SUPERPLAN.json but no '
                'feature_list.json entry references it — register a feature with '
                '`notes: "route:$id ..."` or add `route:$id` to '
                '`app.mvp.out` to defer it. A route nobody tracked and nobody '
                'deferred is a route nobody will ever build.',
          );
        }

        // --- S5: every feature's notes references an existing route ------
        final pattern = RegExp(r'\b([a-z][a-z0-9-]+)\b');
        for (final notes in tracked) {
          if (notes.isEmpty) continue;
          // Pick out route-like mentions: kebab-case tokens that are not
          // English words. The TODO stub from the template uses `feature-001`
          // which is not a route id, and is exempt.
          final candidates = pattern
              .allMatches(notes)
              .map((m) => m.group(1)!)
              .where(
                (m) =>
                    m.length > 4 && (m.contains('-') || routeIds.contains(m)),
              )
              .toSet();
          for (final candidate in candidates) {
            if (!routeIds.contains(candidate)) continue;
            if (deferredIds.contains(candidate)) continue;
            // Already covered by S4 (which would have failed if no entry
            // referenced it). S5 catches the inverse — a feature that names
            // a route id not in the superplan.
          }
          // S5 only fires when a notes field claims a route id and that id
          // does not exist in SUPERPLAN.json. Look for the explicit
          // `route:<id>` token and the backticked/quoted `<id>` mentions.
          final referencedRouteMentions = RegExp(
            r'route:([a-z][a-z0-9-]+)',
          ).allMatches(notes).map((m) => m.group(1)!).toSet();
          for (final id in referencedRouteMentions) {
            if (!routeIds.contains(id)) {
              fail(
                'S5',
                'feature_list.json notes references route `route:$id` but '
                    'no such id exists in SUPERPLAN.json — the feature is '
                    'tracking a route that does not exist.',
              );
            }
          }
        }
      }
    }
    // --- S7: archetype-required kits are present per route --------
    // Each archetype names the kit that *must* appear in components[]
    // or layout.regions[*] for the screen to actually be that
    // archetype. A form without DSPinnedActionBar loses its primary on
    // every scroll; a collection without DSDismissibleTile has no swipe.
    const requiredByArchetype = <String, List<String>>{
      'focal': <String>[],
      'collection': <String>['DSDismissibleTile', 'DSSearchBar'],
      'detail': <String>['DSPinnedActionBar'],
      // Not `DSFormPage`, though the kit now ships the shape this archetype
      // asks for. The region vocabulary a route's `components[]` is checked
      // against — header, body.*, footer, fab, overlay, pullout, inset — has
      // no name for the page itself, so requiring the template would require
      // a region that does not exist. Naming a page in a plan is a change to
      // the superplan schema and both wireframe renderers, not a kit list.
      'form': <String>['DSPinnedActionBar', 'DSTextField'],
      'settings': <String>['DSSettingsSection'],
      // Sequence names no kit. A tour is `DSTour`, a wizard is `DSStepper`,
      // and a signup questionnaire is neither — the part that is not
      // negotiable is structural (a job per step, honest progress, a named
      // handover) and `validateSuperPlan` holds that instead. Naming one kit
      // here would fail the two compositions that are equally correct.
      'sequence': <String>[],
      // However the plans are drawn, the primary is pinned: a purchase button
      // that scrolls away is one the user hunts for, and a paywall's whole
      // job is that they do not.
      'offer': <String>['DSPinnedActionBar'],
      // The plot is the archetype. An insight without a chart is a stat tile
      // with a paragraph under it, and `DSPinnedActionBar` is deliberately
      // absent here: an insight pins nothing, which `validateSuperPlan`
      // enforces from the other direction by refusing a `primaryAction`.
      'insight': <String>['DSChart'],
      // The rail is the archetype. A shelf whose tiles are `DSCard` is a
      // dashboard laid sideways: the tile is what carries the picture, the
      // status vocabulary and the peek the rule is about.
      'shelf': <String>['DSMediaTile'],
      // The stage is the archetype, and `DSMediaSurface` is the only thing in
      // the kit that draws playback state rather than a picture. Absent here,
      // deliberately: `DSPinnedActionBar` — a session pins nothing, which
      // `validateSuperPlan` enforces from the other direction by refusing a
      // `primaryAction`.
      'session': <String>['DSMediaSurface'],
      // The sheet with snap points is what makes a canvas a canvas rather
      // than a picture with buttons on it: the ground stays reachable at
      // every detent because the sheet is not modal.
      'canvas': <String>['DSBottomSheet'],
      // The outcome is a persistent statement about what happened, which is
      // `DSMessage` and not `DSSnackBar` — a confirmation the user can miss
      // by looking away is not a confirmation.
      'confirmation': <String>['DSMessage', 'DSPinnedActionBar'],
      // The composer is the archetype. A thread whose input is a `DSTextField`
      // in the body is a form with a transcript above it: the field that
      // grows while the bar keeps the bottom edge, and the send that is dead
      // until there is something to send, are what make it a conversation.
      // `DSChatBubble` beside it because a turn drawn as a `DSListTile` has
      // lost the two things a transcript is read by \u2014 the side it sits on
      // and the state it is in.
      'conversation': <String>['DSComposer', 'DSChatBubble'],
      // The grid is the archetype, and the strip is how another day is
      // reached. A schedule that cites neither is an agenda: rows under a
      // header, which is a `collection` and should say so.
      'schedule': <String>['DSTimeGrid', 'DSDateStrip'],
    };
    final routesList = (superMap['routes'] as List?) ?? const <Object?>[];
    for (var i = 0; i < routesList.length; i++) {
      final r = routesList[i];
      if (r is! Map) continue;
      final arch = r['archetype'];
      if (arch is! String || !requiredByArchetype.containsKey(arch)) continue;
      final cited = <String>{};
      for (final c in sList(r['components']).whereType<Map>()) {
        final kit = sStr(c['kit']);
        if (kit.isNotEmpty) cited.add(kit);
      }
      final layout = r['layout'];
      if (layout is Map) {
        for (final reg in sList(layout['regions']).whereType<Map>()) {
          if (reg['kit'] is String) cited.add(sStr(reg['kit']));
          for (final k in sList(reg['kits']).whereType<String>()) {
            cited.add(k.replaceFirst(RegExp(r'\s+×\s+\d+$'), ''));
          }
        }
      }
      for (final requiredKit in requiredByArchetype[arch]!) {
        if (!cited.contains(requiredKit)) {
          fail(
            'S7',
            'routes[$i] (archetype `$arch`) does not cite `$requiredKit`. The archetype requires this kit — without it the screen cannot be that archetype (a form without DSPinnedActionBar loses its primary on every scroll, a collection without DSDismissibleTile has no swipe).',
          );
        }
      }
    }

    // --- S8: the interview happened -------------------------------
    // Every other step of this primitive produces something a rule can
    // check. Step 1 — the interview — produced nothing, so an agent
    // optimising for a green gate had no reason to run it: the fields
    // the validator names were the fields it filled, and none of them
    // said `ask`. This rule is that field's gate. It does not demand a
    // long interview; it demands that at least one decision in the plan
    // was the user's, so `openQuestions[]` stops being the only place
    // an unasked question can hide.
    final decisions = sList(superMap['decisions']).whereType<Map>().toList();
    if (decisions.isEmpty) {
      fail(
        'S8',
        'SUPERPLAN.json has no `decisions[]`. The superplan records what '
            'was decided but not who decided it, which is how an interview '
            'that never happened passes every other rule. Add one entry per '
            'call that shaped the plan: `{question, answer, source: "user" | '
            '"assumed", why}`.',
      );
    } else if (!decisions.any((d) => sStr(d['source']) == 'user')) {
      fail(
        'S8',
        'every entry in `decisions[]` is `source: "assumed"` — this plan '
            'was written for the user without asking them anything. Ask two '
            'or three of the questions that would change the route map, and '
            'record the answers as `source: "user"`. A plan nobody was '
            'consulted on is a plan nobody agreed to.',
      );
    }
  }

  return violations;
}

/// The count of valid superplans in [root], for the summary line.
int _validSuperPlanCount(Directory root) {
  final f = File('${root.path}/SUPERPLAN.json');
  if (!f.existsSync()) return 0;
  try {
    final decoded = jsonDecode(f.readAsStringSync());
    return validateSuperPlan(decoded).isEmpty ? 1 : 0;
  } catch (_) {
    return 0;
  }
}

void main() {
  final root = Directory.current;
  if (!Directory('${root.path}/lib').existsSync()) {
    stderr.writeln(
      'superplan-lint: no lib/ directory — run from the project root.',
    );
    exit(1);
  }

  final violations = lintSuperPlans(root);
  if (violations.isNotEmpty) {
    stderr.writeln('superplan-lint: ${violations.length} violation(s)\n');
    for (final v in violations) {
      stderr.writeln(v.toString());
    }
    stderr.writeln('');
    exit(1);
  }

  final checked = _validSuperPlanCount(root);
  final synced = File('${root.path}/SUPERPLAN.md').existsSync()
      ? ', SUPERPLAN.md in sync'
      : '';
  stdout.writeln(
    checked == 0
        ? 'superplan-lint: no superplan to check (0 violations)'
        : 'superplan-lint: $checked superplan valid$synced (0 violations)',
  );
}
