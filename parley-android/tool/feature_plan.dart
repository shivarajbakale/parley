// feature_plan — validate a feature plan and draw it, before anything is built.
//
// Why this exists
// ---------------
// `add-feature` starts writing files at step 2, so the first reviewable
// artifact for a feature was a diff. By then the layout argument is expensive:
// the screen exists, its test exists, its golden exists, and moving the primary
// action means rewriting all three.
//
// This renders the review artifact first, and renders it DETERMINISTICALLY.
// Every frame below is drawn from the plan's own nodes — never free-drawn — so
// the picture cannot disagree with what gets built.
//
// The frames key off `archetype`, which is not a word invented for this file:
// `docs/principles/screen-archetypes.md` declares the twelve, every demo screen
// names its own in its doc comment, and `test/screens/archetypes_test.dart`
// asserts the shape once the screen exists. So the frame approved here is the
// frame the suite later holds the screen to.
//
// Usage
// -----
//   dart run tool/feature_plan.dart <plan.json>                    # print
//   dart run tool/feature_plan.dart <plan.json> -o FEATURE-PLAN.md
//   dart run tool/feature_plan.dart <plan.json> --check            # validate only
//
// Dependency-free: `dart:io` and `dart:convert`, nothing from pub.

import 'dart:convert';
import 'dart:io';

// --- vocabulary --------------------------------------------------------------

/// The twelve shapes `docs/principles/screen-archetypes.md` declares. A
/// thirteenth archetype is a change to that document first, to this list
/// second, to `tool/super_plan.dart`'s copy third, and to
/// `superplan_lint.dart`'s required-kit table fourth. `shelf`, `session`,
/// `canvas` and `confirmation` were the last four to make that trip, together,
/// when the media family gave the first two kit to stand on.
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

/// The most detents a `canvas` sheet may settle at. Peek, half, full. A sheet
/// that settles anywhere is a sheet the user has to aim, and one that settles
/// at a single height is not a canvas — it is a panel.
const maxCanvasDetents = 3;

/// The most tiles a `shelf` rail may hold before it owes a "See all". Past
/// this the rail's end is more than three or four swipes away, which is where
/// sequential access stops being browsing and starts being work.
const maxRailItems = 4;

/// What a `sequence` step is allowed to be for. Not a taxonomy for its own
/// sake: a step that cannot name one of these is a step nobody decided to
/// build, and naming it is the cheapest cut a flow ever gets.
const stepJobs = <String>[
  'brand',
  'segmentation',
  'trust',
  'activation',
  'monetization',
  'retention',
];

/// The most plots an `insight` may draw. One. It is a constant rather than a
/// literal so the rule has a name to be argued with: a recap with two charts
/// is a dashboard, and a dashboard is a screen that gets opened once.
const maxInsightCharts = 1;

/// The most plans an `offer` may show. One removes the comparison, two
/// separate flexibility from savings, three need a reason you can say out
/// loud. Four is a pricing page, and a pricing page is a web idiom.
const maxOfferPlans = 3;

/// The overlays this kit actually ships. A plan may not name a control that
/// does not exist — that is how a wireframe starts describing another app.
const overlayKinds = <String>[
  'dialog',
  'alert-dialog',
  'bottom-sheet',
  'snap-sheet',
  'menu',
  'snack-bar',
];

/// Every async surface owes all four. Missing one is a bug, not a shortcut.
const requiredStates = <String>['loading', 'empty', 'error', 'success'];

/// What each archetype will be held to once it is code, printed into the plan
/// so the reviewer sees the rules at the moment the shape is still free.
const _archetypeRules = <String, List<String>>{
  'focal': [
    'one hero at scale, then a bento of two sizes — six tiles of equal weight '
        'is the defect `screen-archetypes.md` is named after',
    'at most one gradient, and it is on the hero '
        '(`docs/principles/depth-and-materials.md`)',
  ],
  'collection': [
    'search in place, filters as a horizontally scrolling chip strip, '
        'pull-to-refresh always',
    'the swipe action has a tappable twin — a swipe is not discoverable, and a '
        'reader using VoiceOver never has it',
    'empty, zero-results and error are three different screens',
  ],
  'detail': [
    'the primary pins above the safe area on a chrome surface and does not '
        'scroll away (`DSPinnedActionBar` with `extendBody: true`)',
    'secondary actions go in the app-bar overflow, not a row of five buttons',
  ],
  'form': [
    'one column, and the primary is bottom, full width, above the safe area — '
        'not bottom-right, which is the desktop idiom',
    'label above the field, helper below, error replaces the helper, so the '
        'layout does not jump when validation fires',
  ],
  'settings': [
    'grouped inset rows (`DSSettingsSection`), grouped by what the user is '
        'changing rather than by which service owns it',
    'destructive actions in their own group at the bottom, behind a confirm '
        'that names the object',
  ],
  'sequence': [
    'one decision per screen, and every step names its job — brand, '
        'segmentation, trust, activation, monetization or retention',
    'progress at the top and the primary pinned at the bottom, never sharing '
        'the bottom edge with a keyboard',
    'back never destroys an answer, and the last step hands over to a named '
        'screen',
  ],
  'insight': [
    'one figure, its comparison beside it, one chart, then one sentence of '
        'plain-language interpretation under the chart',
    'nothing pins — an insight is read, not submitted, and a pinned bar over '
        'a recap steals the height the chart needs',
    'the finding is in text as well as in the plot: a chart is silent to a '
        'screen reader, so the headline, the sentence and the breakdown each '
        'carry it',
  ],
  'shelf': [
    'every rail names why it is here — "because you watched", "new this '
        'week", "continue". A rail titled with a genre nobody chose is cut',
    'a rail\'s end is three or four swipes away; past that it is a collection '
        'route behind a "See all", and the next tile always peeks so the '
        'swipe is discoverable',
    'the title is text under the tile — artwork is a guess about the viewer, '
        'not a name',
  ],
  'session': [
    'the transport reads playback state and never keeps its own; the same '
        'state is what the platform draws on the lock screen',
    'nothing pins and nothing scrolls — the transport is the chrome, and a '
        'session that scrolls has a detail screen hidden inside it',
    'the scrubber meets the 44-point target floor, and elapsed and remaining '
        'are text as well as a filled bar',
  ],
  'canvas': [
    'the ground stays interactive at every detent, and the smallest detent '
        'leaves the subject visible — a peek that covers the pin has no '
        'reason to be a peek',
    'two or three named detents, a drag handle, and floating controls above '
        'the sheet\'s top edge rather than under it',
    'the state is in text in the sheet: a map is silent to a screen reader',
  ],
  'confirmation': [
    'what happened in the past tense, then the identifier the user can copy, '
        'then what was ordered, then what happens next with a date on it',
    'the undo window is named here or nowhere — "you can cancel until 6pm"',
    'one way onward: a confirmation is the last screen of a flow, not the '
        'last screen of the app, and it is never a dialog',
  ],
  'schedule': [
    'the day being drawn is named on the screen, and another one is chosen '
        'from the strip above it rather than from a dialog',
    'two things at the same hour are side by side, never stacked \u2014 a booking '
        'hidden under another booking is the one that gets double-booked',
    'the window is a hint: anything outside it widens the day rather than '
        'being clipped, and an empty day says so and says how to fill it',
  ],
  'editor': [
    'the work fills the screen and the chrome is a bar \u2014 an editor with a '
        'panel of controls beside the document has given the controls the '
        'room the work needed',
    'the save state is on the screen and it is true: clean, saving, saved, '
        'conflict. "Saved" drawn while the write is in flight is the lie the '
        'user finds out about later',
    'undo is one tap from where the mistake happened, never behind a menu, '
        'and leaving with unsaved work is answered here rather than by the '
        'platform back gesture',
  ],
  'conversation': [
    'the transcript is inverted \u2014 the newest turn is at the bottom, and it '
        'stays there when the keyboard opens rather than sliding under it',
    'every turn carries its state: sending, streaming, sent, failed. A turn '
        'that did not send offers the retry in the transcript, where the user '
        'is looking, not in a snackbar that has gone by the time they look',
    'the composer is the only pinned thing, its field grows to a ceiling and '
        'then scrolls itself, and its send is dead until there is something '
        'to send',
  ],
  'offer': [
    'the outcome, then the dated trial, then at most three plans, then the '
        'primary naming the purchase, then the billing disclosure beside it',
    'the pinned action may not cover the renewal line at a 1.3x text scale — '
        '`ui-probe`\'s overlap rule is the gate',
    'restore, terms and privacy stay reachable in the footer, never behind '
        'the primary',
  ],
};

/// Rules every surface is held to, whatever its shape.
const _universalRules = <String>[
  '`dart run tool/ui_lint.dart` — every control comes from the kit and every '
      'colour, radius, duration and shadow from the tokens',
  'a golden at textScale 2.0 — the accessibility case that breaks layouts',
];

// --- validation --------------------------------------------------------------

/// Empty when the plan can be drawn. Every message names the path it is about,
/// because a validator that only says "invalid" sends the author back to read
/// this file.
List<String> validateFeaturePlan(Object? input) {
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

  final feature = plan['feature'];
  need(feature is Map, 'feature: required object');
  if (feature is Map) {
    final id = str(feature['id']);
    need(
      id != null && RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(id),
      'feature.id: required kebab-case string',
    );
    need(filled(feature['title']), 'feature.title: required');
    need(
      filled(feature['problem']),
      'feature.problem: required — a plan with no problem statement cannot '
      'be reviewed',
    );
  }

  final surfaces = plan['surfaces'];
  need(
    surfaces is List && surfaces.isNotEmpty,
    'surfaces: at least one required',
  );

  final list = surfaces is List ? surfaces : const [];
  for (var i = 0; i < list.length; i++) {
    final at = 'surfaces[$i]';
    final s = list[i];
    if (s is! Map) {
      e.add('$at: must be an object');
      continue;
    }
    need(filled(s['id']), '$at.id: required');
    need(filled(s['name']), '$at.name: required');

    final archetype = str(s['archetype']);
    final known = archetype != null && archetypes.contains(archetype);
    need(
      known,
      '$at.archetype: must be one of ${archetypes.join(' | ')} '
      '(got ${jsonEncode(s['archetype'])})',
    );

    final panels = s['panels'];
    need(
      panels is List && panels.isNotEmpty,
      '$at.panels: at least one required — a surface with no panels cannot '
      'be drawn',
    );

    // The peak and the end are named before the layout is drawn. A surface
    // whose author cannot say which moment the user takes away is a surface
    // with neither — see docs/principles/emotional-design.md.
    final moments = s['moments'];
    need(
      moments is Map,
      '$at.moments: required — name the peak and the end '
      '(docs/principles/emotional-design.md)',
    );
    for (final m in const <String, String>{
      'peak': 'the one moment the user came for',
      'end': 'the last impression before they leave',
    }.entries) {
      need(
        moments is Map && filled(moments[m.key]),
        '$at.moments.${m.key}: required — ${m.value}',
      );
    }

    final states = s['states'];
    for (final st in requiredStates) {
      need(
        states is Map && filled(states[st]),
        '$at.states.$st: required — every async surface renders all four '
        'states',
      );
    }

    if (!known || panels is! List || panels.isEmpty) continue;
    final boxes = panels.whereType<Map>().toList();
    String kindOf(Map p) => str(p['kind']) ?? '';

    switch (archetype) {
      case 'focal':
        // The archetype IS "one hero, then unequal weights". A focal plan
        // whose tiles are all one kind is the six-identical-tiles screen with
        // a different word on it, so it is rejected here rather than found in
        // review.
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
          'identical tiles, which is the layout screen-archetypes.md exists '
          'to prevent',
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
            '$at: the list panel needs `rows` — a collection nobody drew a '
            'row of is not reviewable',
          );
          need(
            filled(l['search']),
            '$at: `search` is required — search in place is part of the '
            'archetype, not an enhancement',
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
            '$at: `swipeTwin` is required — say where the swipe action also '
            'lives as a tap target. A swipe with no twin is invisible to a '
            'reader using VoiceOver or a switch control',
          );
        }
        need(
          filled((s['states'] as Map?)?['zeroResults']),
          '$at.states.zeroResults: required for a collection — nothing '
          'matched and nothing exists are two different screens with two '
          'different things to do about them',
        );
      case 'detail':
        need(
          filled(s['primaryAction']),
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
          filled(s['primaryAction']),
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
            '$at.panels[$j].rows: required — a settings group is its rows',
          );
        }
      case 'sequence':
        final steps = boxes.where((p) => kindOf(p) == 'step').toList();
        need(
          steps.length >= 2,
          '$at: sequence is at least two panels of `kind: "step"` — one step '
          'is a form with a progress bar drawn on it',
        );
        for (var j = 0; j < steps.length; j++) {
          final job = str(steps[j]['job']);
          need(
            job != null && stepJobs.contains(job),
            '$at.panels[$j].job: must be one of ${stepJobs.join(' | ')} — a '
            'step that cannot name its job is a step nobody decided to build',
          );
        }
        need(
          filled(s['progress']),
          '$at.progress: required — say how the user knows where they are. A '
          'sequence with no progress is a corridor with no end',
        );
        need(
          filled(s['back']),
          '$at.back: required — say what Back does. Back that loses an answer '
          'is the defect this key exists to surface',
        );
        need(
          filled(s['handover']),
          '$at.handover: required — name the screen the last step hands over '
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
            '$at: the hero is the first panel — a hero under a rail is a rail '
            'the user scrolled past to reach it',
          );
        }
        for (var j = 0; j < rails.length; j++) {
          final rail = rails[j];
          need(
            filled(rail['title']),
            '$at.panels: every rail needs a `title` saying why it is here. '
            '"Because you watched", "New this week", "Continue" — a rail that '
            'cannot name its reason is a rail nobody asked for',
          );
          final items = rail['items'];
          need(
            items is List && items.isNotEmpty,
            '$at.panels: rail `${rail['title']}` needs `items` — a rail '
            'nobody drew a tile of is not reviewable',
          );
          if (items is List && items.length > maxRailItems) {
            need(
              filled(rail['seeAll']),
              '$at.panels: rail `${rail['title']}` holds ${items.length} '
              'items, so it needs `seeAll` naming the route it opens. Past '
              '$maxRailItems the end is more than four swipes away',
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
          filled(s['nowPlaying']),
          '$at.nowPlaying: required — what is playing, in text. A filled bar '
          'and a picture are both silent to a screen reader',
        );
        final transport = s['transport'];
        need(
          transport is List && transport.isNotEmpty,
          '$at.transport: required — the controls, named. They read the '
          'playback state; a session whose buttons keep their own is how a '
          'paused notification ends up over a playing screen',
        );
        need(
          filled(s['escape']),
          '$at.escape: required — say how the user leaves without stopping '
          'it. A down-chevron, not a back arrow: back implies the session '
          'ended',
        );
        need(
          !filled(s['primaryAction']),
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
            'peek, half, full. One height is a panel, and a sheet that '
            'settles anywhere is one the user has to aim',
          );
          need(
            filled(sheets.single['peek']),
            '$at: the sheet needs `peek` — say what stays visible on the '
            'ground at the smallest detent. A peek that covers the pin the '
            'user just tapped has no reason to be a peek',
          );
        }
        need(
          !filled(s['primaryAction']),
          '$at.primaryAction: a canvas pins nothing — the sheet owns the '
          'bottom edge, and a bar under it is a control at one detent only',
        );
      case 'confirmation':
        final receipts = boxes.where((p) => kindOf(p) == 'receipt').toList();
        need(
          receipts.length == 1,
          '$at: confirmation is exactly one panel of `kind: "receipt"` — what '
          'was ordered, booked or sent. It is the most requested thing on '
          'the screen and the easiest to leave off',
        );
        need(
          filled(s['outcome']),
          '$at.outcome: required — what happened, in the past tense and in '
          'the user\'s words. "Your order is placed", not "Success"',
        );
        need(
          filled(s['reference']),
          '$at.reference: required — the identifier, and it is selectable. An '
          'order number the user cannot copy is one they photograph',
        );
        need(
          filled(s['next']),
          '$at.next: required — what happens next, with a date on it. '
          '"Arrives Thursday 12 March", not "soon"',
        );
        need(
          filled(s['handover']),
          '$at.handover: required — the one way onward. A confirmation is the '
          'last screen of a flow, not the last screen of the app',
        );
      case 'schedule':
        final days = boxes.where((p) => kindOf(p) == 'day').toList();
        need(
          days.length == 1,
          '$at: schedule is exactly one panel of `kind: "day"` \u2014 the grid '
          'itself. A week is seven of these behind a strip, not seven panels '
          'on one screen',
        );
        need(
          filled(s['window']),
          '$at.window: required \u2014 the hours the day opens on, and it is a '
          'hint rather than a crop: "08:00 to 20:00, widened by anything '
          'outside it"',
        );
        need(
          filled(s['empty']),
          '$at.empty: required \u2014 what a day with nothing on it says, and how '
          'it offers to be filled. An empty grid is twelve hours of ruled '
          'paper',
        );
        need(
          filled(s['create']),
          '$at.create: required \u2014 how something new is added to the day',
        );
      case 'editor':
        final docs = boxes.where((p) => kindOf(p) == 'document').toList();
        need(
          docs.length == 1,
          '$at: editor is exactly one panel of `kind: "document"` \u2014 the work '
          'itself. A second panel beside it is a control taking the room the '
          'work needed',
        );
        need(
          filled(s['autosave']),
          '$at.autosave: required \u2014 what saving means here. "Every keystroke, '
          'debounced two seconds", or "on Done". A save state nobody can '
          'predict is one nobody trusts',
        );
        need(
          filled(s['undo']),
          '$at.undo: required \u2014 what undo covers, and how far back it goes',
        );
        need(
          filled(s['exit']),
          '$at.exit: required \u2014 what happens on back with unsaved work. The '
          'platform gesture will be used, and answering it here is the '
          'difference between a draft kept and a draft lost',
        );
        need(
          !filled(s['primaryAction']),
          '$at.primaryAction: an editor pins its toolbar, not a button \u2014 the '
          'keyboard owns the bottom edge, and the way out belongs in the '
          'header where it is reachable without dismissing it',
        );
      case 'conversation':
        final threads = boxes.where((p) => kindOf(p) == 'transcript').toList();
        need(
          threads.length == 1,
          '$at: conversation is exactly one panel of `kind: "transcript"` \u2014 '
          'the thread itself. Everything else on the screen is context '
          'beside it',
        );
        final turns = threads.isEmpty
            ? const <Map>[]
            : _listOf(threads.single['turns']).whereType<Map>().toList();
        need(
          turns.length >= 2,
          '$at.turns: a conversation is drawn with at least two turns. One '
          'turn is a message; two are a thread, and the thread is what the '
          'shape is about',
        );
        need(
          turns.map((t) => str(t['author'])).toSet().length >= 2,
          '$at.turns: both speakers appear. A transcript with one voice in it '
          'is a list, and it should be planned as a collection',
        );
        need(
          filled(s['composer']),
          '$at.composer: required \u2014 what the user writes into, in the words '
          'the field shows when it is empty',
        );
        need(
          filled(s['retry']),
          '$at.retry: required \u2014 what a turn that did not send offers. A '
          'conversation is the surface where the network is visible, and the '
          'failed turn is the one thing on it the user can still act on',
        );
        need(
          filled(s['empty']),
          '$at.empty: required \u2014 what the screen says before the first turn. '
          'A thread that opens blank has lost the one chance it had to say '
          'what it is for',
        );
        need(
          !filled(s['primaryAction']),
          '$at.primaryAction: a conversation pins the composer and nothing '
          'else \u2014 a bar under the composer is a second bottom edge',
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
          filled(s['headline']),
          '$at.headline: required — the one figure, in the user\'s units. '
          '`4h 12m`, not `252`',
        );
        need(
          filled(s['comparison']),
          '$at.comparison: required — what the figure is measured against, '
          'drawn beside it. A number with nothing to compare it to is trivia',
        );
        need(
          filled(s['period']),
          '$at.period: required — the span the figure covers. A figure whose '
          'denominator is a guess is a figure the user quietly distrusts',
        );
        need(
          filled(s['reading']),
          '$at.reading: required — one sentence saying what the number means, '
          'in plain language. This is the part every analytics screen skips '
          'and the only part a person repeats to somebody else',
        );
        need(
          filled(s['handover']),
          '$at.handover: required — name the screen this recap leads to. An '
          'insight that ends on itself is one the user closes',
        );
        need(
          !filled(s['primaryAction']),
          '$at.primaryAction: an insight pins nothing and submits nothing. '
          'The handover is an ordinary control at the end of the scroll, so '
          'name it in `handover` and leave this out',
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
              '$at: plans[$j] needs both `period` and `price` — a plan whose '
              'price is not beside its period is the row a user misreads',
            );
          }
        }
        need(
          filled(s['outcome']),
          '$at.outcome: required — what the user gets, in their words, not '
          'what the tier is called',
        );
        need(
          filled(s['primaryAction']),
          '$at: offer pins a primary naming the purchase, so name it. '
          '"Continue" is not the name of a purchase',
        );
        need(
          filled(s['billing']),
          '$at.billing: required — renewal amount, charge date and how to '
          'cancel, in plain language, drawn adjacent to the primary',
        );
        need(
          filled(s['restore']),
          '$at.restore: required — say where Restore purchases lives. On iOS '
          'a paywall without it is a review rejection',
        );
        need(
          filled(s['terms']),
          '$at.terms: required — say where terms and privacy live',
        );
    }
  }

  final components = plan['components'];
  if (components is List) {
    for (var i = 0; i < components.length; i++) {
      final c = components[i];
      final at = 'components[$i]';
      if (c is! Map) {
        e.add('$at: must be an object');
        continue;
      }
      need(filled(c['control']), '$at.control: required');
      need(
        filled(c['why']),
        '$at.why: required — an unjustified control choice is the thing this '
        'plan exists to surface',
      );
    }
  }

  final overlays = plan['overlays'];
  if (overlays is List) {
    for (var i = 0; i < overlays.length; i++) {
      final o = overlays[i];
      if (o is! Map) {
        e.add('overlays[$i]: must be an object');
        continue;
      }
      need(
        overlayKinds.contains(o['kind']),
        'overlays[$i].kind: must be ${overlayKinds.join(' | ')}',
      );
      need(filled(o['title']), 'overlays[$i].title: required');
    }
  }

  return e;
}

// --- ascii primitives --------------------------------------------------------
//
// Everything below composes fixed-width line lists. Keeping every block
// rectangular is what makes horizontal joins safe and the output byte-stable.
// Only BMP characters are used: a character Dart counts as two UTF-16 units
// would silently tear every box it appears in.

/// The phone. 38 columns outer, which is the widest frame that still sits
/// inside a fenced block in a terminal-width diff.
const _phoneW = 38;
const _bodyW = _phoneW - 4;

/// Body rows drawn even when the content is shorter, so a one-panel screen
/// still reads as a phone rather than as a strip.
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

/// A bordered box of exact width [w], borders included. A row of `'---'` is a
/// divider rather than content.
List<String> _boxOf(int w, List<String> rows) {
  final inner = w - 2;
  final out = <String>['┌${_rule(inner)}┐'];
  for (final r in rows) {
    out.add(r == '---' ? '├${_rule(inner)}┤' : '│${_pad(r, inner)}│');
  }
  out.add('└${_rule(inner)}┘');
  return out;
}

/// Place blocks side by side, padding short ones so the result stays square.
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

/// Lay `rows` out as columns sized to their widest entry. The last column is
/// right-aligned when there is more than one, which is what makes a row of
/// label + value read as a row rather than as a sentence.
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
    // Trim before clamping: the column padding exists to align the row, and
    // a short row that inherited the widest row's trailing spaces would be
    // truncated to a `…` it has no content behind.
    return _pad(parts.join('  ').trimRight(), width);
  }).toList();
}

List<Object?> _listOf(Object? v) => v is List ? v : const [];
String _str(Object? v) => v is String ? v : '';

// --- panels ------------------------------------------------------------------

/// One panel as a box of exact width [w].
///
/// The panel shape is data, not prose: `eyebrow` / `title` / `rows` / `fields`
/// / `footer` / `actions` each render one fixed way, so two plans describing
/// the same panel always draw the same box.
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

// --- archetype bodies --------------------------------------------------------

/// The hero, then the bento. Consecutive `tile` panels pair up; a `wide` panel
/// takes the full column. That is the two-sizes rule drawn rather than stated.
List<String> _focalBody(Map s) {
  final panels = _listOf(s['panels']).whereType<Map>().toList();
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

/// Search, then the chip strip, then hairline-separated rows — in that order,
/// because the two controls that say what the list currently is belong above it.
List<String> _collectionBody(Map s) {
  final panels = _listOf(s['panels']).whereType<Map>().toList();
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
      // The strip scrolls sideways rather than wrapping; what does not fit is
      // off the right edge, and drawn as such.
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
    // Two lines, not one. The twin is the half that gets dropped, and a hint
    // truncated at the frame's edge is exactly how it gets dropped quietly.
    out.add(_pad('◂ swipe: ${list['swipe']}', _bodyW));
    out.add(_pad('  also on: ${list['swipeTwin']}', _bodyW));
  }
  for (final p in panels.where((p) => !identical(p, list))) {
    out.add('');
    out.addAll(_panelBox(p, _bodyW));
  }
  return out;
}

/// Titled sections under a large title. The pinned bar is chrome and is drawn
/// by the frame, not here — which is the same division the code makes.
List<String> _detailBody(Map s) {
  final out = <String>[];
  for (final p in _listOf(s['panels']).whereType<Map>()) {
    out.addAll(_panelBox(p, _bodyW));
    out.add('');
  }
  if (out.isNotEmpty) out.removeLast();
  return out;
}

/// One column. Always. The primary is not here — it is in the pinned bar, and
/// drawing it anywhere else is drawing the desktop pattern.
List<String> _formBody(Map s) {
  final out = <String>[];
  for (final p in _listOf(s['panels']).whereType<Map>()) {
    // An untitled field-set is the page itself, so it draws without a
    // container and at the full column width. Fields inside a card is the
    // desktop settings pattern, and a sign-in screen that looks like one has
    // already gone wrong.
    final fields = _listOf(p['fields']).whereType<Map>().toList();
    if (_str(p['title']).isEmpty && fields.isNotEmpty) {
      for (final f in fields) {
        out.add(_pad(_str(f['label']), _bodyW));
        out.add('[ ${_pad(_str(f['placeholder']), _bodyW - 4)} ]');
        if (_str(f['helper']).isNotEmpty) {
          // Helper below, because the error will replace it — and a layout
          // that reflows the moment validation fires is the thing that rule
          // exists to stop.
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

/// Grouped inset lists: an eyebrow above the container, a footer caption below
/// it. The container is what makes a settings screen read as settings.
List<String> _settingsBody(Map s) {
  final out = <String>[];
  for (final p in _listOf(s['panels']).whereType<Map>()) {
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
/// it. The job is drawn rather than left in the JSON on purpose: a reviewer
/// looking at six steps all labelled `brand` can cut five of them, and a
/// reviewer reading a page count cannot.
List<String> _sequenceBody(Map s) {
  final steps = _listOf(
    s['panels'],
  ).whereType<Map>().where((p) => _str(p['kind']) == 'step').toList();
  final out = <String>[];
  final dots = List<String>.generate(
    steps.length,
    (i) => i == 0 ? '●' : '○',
  ).join(' ');
  out.add(_pad('$dots  ${_str(s['progress'])}', _bodyW));
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
  out.add(_pad('◂ back: ${_str(s['back'])}', _bodyW));
  out.add(_pad('▸ then: ${_str(s['handover'])}', _bodyW));
  return out;
}

/// The figure with its comparison on the same line, the period under it, the
/// plot, then the sentence — in that order, because the order *is* the
/// archetype.
///
/// The comparison is drawn *inside the figure's box* rather than under it, so
/// a plan cannot show the two separated. That separation is the defect the
/// rule names: a delta two paragraphs below the number it modifies is a
/// second number.
List<String> _insightBody(Map s) {
  final panels = _listOf(s['panels']).whereType<Map>().toList();
  final plot = panels.firstWhere(
    (p) => _str(p['kind']) == 'chart',
    orElse: () => <String, Object?>{},
  );
  final out = <String>[];
  out.addAll(
    _boxOf(_bodyW, <String>[
      ' ${_pad(_str(s['headline']), _bodyW - 4)} ',
      ' ${_pad('${_str(s['comparison'])}  ·  ${_str(s['period'])}', _bodyW - 4)} ',
    ]),
  );
  if (plot.isNotEmpty) {
    out.add('');
    out.addAll(_panelBox(plot, _bodyW));
  }
  out.add('');
  for (final l in _wrap('\u201c${_str(s['reading'])}\u201d', _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  for (final p in panels.where((p) => !identical(p, plot))) {
    out.add('');
    out.addAll(_panelBox(p, _bodyW));
  }
  out.add('');
  out.add(_pad('\u25b8 then: ${_str(s['handover'])}', _bodyW));
  return out;
}

/// Outcome, dated trial, plans, then whatever proof there is — in that order,
/// because the order *is* the archetype. The billing line and the footer
/// links are not here: they are drawn by the frame, under the pinned primary,
/// which is the adjacency the rule is actually about.
List<String> _offerBody(Map s) {
  final panels = _listOf(s['panels']).whereType<Map>().toList();
  final plans = panels.firstWhere(
    (p) => _str(p['kind']) == 'plans',
    orElse: () => panels.isEmpty ? <String, Object?>{} : panels.first,
  );
  final out = <String>[];
  for (final l in _wrap(_str(s['outcome']), _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  if (_str(s['trial']).isNotEmpty) {
    out.add('');
    out.add(_pad('⌛ ${_str(s['trial'])}', _bodyW));
  }
  for (final row in _listOf(plans['plans']).whereType<Map>()) {
    out.add('');
    final badge = _str(row['badge']);
    final head = badge.isEmpty
        ? _str(row['period'])
        : '${_str(row['period'])}  ($badge)';
    // Period and price on two rows of one box, so the drawing cannot show
    // them separated — which is the failure the rule names.
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

/// A hero, then rails. Each rail draws its title, a "See all" when it has one,
/// and its tiles cut off at the right edge — the peek is the archetype, so the
/// frame draws the tile that is half off screen rather than a tidy row.
List<String> _shelfBody(Map s) {
  final panels = _listOf(s['panels']).whereType<Map>().toList();
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
          : '${_pad(title, _bodyW - 10)} See all ›',
    );
    final tiles = _listOf(rail['items']).map((i) => '$i').toList();
    final cells = <List<String>>[];
    for (final t in tiles) {
      cells.add(<String>['┌──────┐', '│      │', '└──────┘', _pad(t, 8)]);
    }
    if (cells.isEmpty) {
      out.add(_pad('(no items)', _bodyW));
    } else {
      final row = _hjoin(cells);
      for (final l in row) {
        // Cut rather than wrap: what runs past the edge is the next tile
        // peeking, which is the signifier the rule is about.
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

/// The stage, what is playing, the scrubber, and the transport under it. No
/// pinned bar is drawn because a session has none — the transport is the
/// chrome, and the frame is told so by the `pinned` set.
List<String> _sessionBody(Map s) {
  final panels = _listOf(s['panels']).whereType<Map>().toList();
  final stage = panels.firstWhere(
    (p) => _str(p['kind']) == 'stage',
    orElse: () => panels.isEmpty ? <String, Object?>{} : panels.first,
  );
  final out = <String>[];
  out.add(_pad('⌄  ${_str(s['escape'])}', _bodyW));
  out.add('');
  if (stage.isNotEmpty) out.addAll(_panelBox(stage, _bodyW));
  out.add('');
  for (final l in _wrap(_str(s['nowPlaying']), _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  out.add('');
  out.add(_pad('━━━━━━━━━●${'─' * (_bodyW - 24)}', _bodyW - 12));
  out.add('${_pad('1:12', _bodyW - 6)}-2:48');
  out.add('');
  // Chunked rather than joined: a transport of four controls is wider than
  // the frame, and a row of buttons truncated at the edge is exactly the
  // control the reviewer would not have noticed missing.
  var line = '';
  for (final c in _listOf(s['transport']).map((c) => '[ $c ]')) {
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

/// The ground with the sheet over it at its smallest detent. The frame's job
/// is to show what the peek leaves visible, because that is the rule the
/// archetype is most often broken by.
List<String> _canvasBody(Map s) {
  final panels = _listOf(s['panels']).whereType<Map>().toList();
  final ground = panels.firstWhere(
    (p) => _str(p['kind']) == 'ground',
    orElse: () => <String, Object?>{},
  );
  final sheet = panels.firstWhere(
    (p) => _str(p['kind']) == 'sheet',
    orElse: () => <String, Object?>{},
  );
  final out = <String>[];
  out.add(_centre('· ${_str(ground['title'])} ·', _bodyW));
  out.add(_centre(_str(sheet['peek']), _bodyW));
  out.add('');
  out.add('${_pad('', _bodyW - 3)}(⌖)');
  out.add('');
  out.add(_centre('▁▁▁▁', _bodyW));
  final rows = <String>[' ${_pad(_str(sheet['title']), _bodyW - 4)} '];
  for (final r in _listOf(sheet['rows'])) {
    rows.add(' ${_pad('$r', _bodyW - 4)} ');
  }
  rows.add('---');
  rows.add(' ${_pad(_listOf(sheet['detents']).join('  ·  '), _bodyW - 4)} ');
  out.addAll(_boxOf(_bodyW, rows));
  for (final p in panels.where(
    (p) => !identical(p, ground) && !identical(p, sheet),
  )) {
    out.add('');
    out.addAll(_panelBox(p, _bodyW));
  }
  return out;
}

/// The end moment, in the order it is read: what happened, the identifier, the
/// receipt, then what happens next. The way onward is the pinned primary and
/// is drawn by the frame.
List<String> _confirmationBody(Map s) {
  final panels = _listOf(s['panels']).whereType<Map>().toList();
  final receipt = panels.firstWhere(
    (p) => _str(p['kind']) == 'receipt',
    orElse: () => panels.isEmpty ? <String, Object?>{} : panels.first,
  );
  final out = <String>[];
  out.addAll(
    _boxOf(_bodyW, <String>[
      ' ${_pad('✓  ${_str(s['outcome'])}', _bodyW - 4)} ',
      ' ${_pad(_str(s['reference']), _bodyW - 4)} ',
    ]),
  );
  out.add('');
  if (receipt.isNotEmpty) out.addAll(_panelBox(receipt, _bodyW));
  out.add('');
  for (final l in _wrap('▸ next: ${_str(s['next'])}', _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  if (_str(s['undo']).isNotEmpty) {
    out.add('');
    for (final l in _wrap('↺ ${_str(s['undo'])}', _bodyW)) {
      out.add(_pad(l, _bodyW));
    }
  }
  out.add('');
  out.add(_pad('▸ then: ${_str(s['handover'])}', _bodyW));
  for (final p in panels.where((p) => !identical(p, receipt))) {
    out.add('');
    out.addAll(_panelBox(p, _bodyW));
  }
  return out;
}

/// The thread, drawn the way it is read: oldest at the top, the newest turn
/// last and nearest the composer. Theirs on the leading edge, mine indented to
/// the trailing one, which is the whole of how a transcript says who spoke.
List<String> _conversationBody(Map s) {
  final panels = _listOf(s['panels']).whereType<Map>().toList();
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
        'failed' => '! not sent · ${_str(s['retry'])}',
        _ => state,
      };
      rows.add(' ${_pad(mark, bubbleW - 4)} ');
    }
    for (final l in _boxOf(bubbleW, rows)) {
      // Mine is pushed to the trailing edge by exactly the width the bubble
      // gives up, so both edges stay inside the frame at every turn.
      out.add(_pad(mine ? '${' ' * (_bodyW - bubbleW)}$l' : l, _bodyW));
    }
    out.add('');
  }

  if (turns.isEmpty) {
    for (final l in _wrap('(empty) ${_str(s['empty'])}', _bodyW)) {
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
      '${_pad(' ${_str(s['composer'])}', inner - 3)}↑  ',
    ]),
  );
  return out;
}

/// The work, then the bar over it. The toolbar and the save line are chrome
/// and are drawn here rather than by the frame, because an editor's bar is not
/// the pinned primary the frame knows how to draw.
List<String> _editorBody(Map s) {
  final panels = _listOf(s['panels']).whereType<Map>().toList();
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
  for (final l in _wrap('☁ ${_str(s['autosave'])}', _bodyW - 4)) {
    barRows.add(' ${_pad(l, _bodyW - 4)} ');
  }
  out.addAll(_boxOf(_bodyW, barRows));
  out.add('');
  for (final l in _wrap('↶ undo: ${_str(s['undo'])}', _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  for (final l in _wrap('← back: ${_str(s['exit'])}', _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  return out;
}

/// A day: the strip that picks it, then the hours with what is on them. The
/// clash is drawn as two boxes on one line, because that is the claim the
/// archetype makes.
List<String> _scheduleBody(Map s) {
  final panels = _listOf(s['panels']).whereType<Map>().toList();
  final day = panels.where((p) => _str(p['kind']) == 'day').firstOrNull;
  final out = <String>[];

  out.addAll(
    _boxOf(_bodyW, <String>[
      ' ${_pad('‹  M  T  W [T] F  S  S  ›', _bodyW - 4)} ',
    ]),
  );
  out.add('');
  for (final l in _wrap('⌚ ${_str(s['window'])}', _bodyW)) {
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
    final left = _boxOf(half, <String>[' ${_pad(title, half - 4)} ']);
    if (clash.isEmpty) {
      for (final l in _boxOf(_bodyW, <String>[
        ' ${_pad('$at  $title', _bodyW - 4)} ',
      ])) {
        out.add(_pad(l, _bodyW));
      }
    } else {
      // Side by side, and the drawing says so: a clash stacked is the defect
      // the rule is about.
      final right = _boxOf(half, <String>[' ${_pad(clash, half - 4)} ']);
      for (final row in _hjoin(<List<String>>[left, right])) {
        out.add(_pad(row, _bodyW));
      }
    }
    out.add('');
  }

  if (slots.isEmpty) {
    for (final l in _wrap('(empty) ${_str(s['empty'])}', _bodyW)) {
      out.add(_pad(l, _bodyW));
    }
    out.add('');
  }

  for (final l in _wrap('+ ${_str(s['create'])}', _bodyW)) {
    out.add(_pad(l, _bodyW));
  }
  return out;
}

List<String> _bodyFor(Map s) {
  switch (_str(s['archetype'])) {
    case 'focal':
      return _focalBody(s);
    case 'collection':
      return _collectionBody(s);
    case 'detail':
      return _detailBody(s);
    case 'form':
      return _formBody(s);
    case 'sequence':
      return _sequenceBody(s);
    case 'offer':
      return _offerBody(s);
    case 'insight':
      return _insightBody(s);
    case 'shelf':
      return _shelfBody(s);
    case 'session':
      return _sessionBody(s);
    case 'canvas':
      return _canvasBody(s);
    case 'confirmation':
      return _confirmationBody(s);
    case 'conversation':
      return _conversationBody(s);
    case 'editor':
      return _editorBody(s);
    case 'schedule':
      return _scheduleBody(s);
    default:
      return _settingsBody(s);
  }
}

// --- the phone frame ---------------------------------------------------------

/// The chrome around the body: status bar, app bar, the pinned action bar when
/// the archetype has one, the tab bar when the surface is a tab, and the home
/// indicator.
///
/// The home indicator is drawn on purpose. "Full width above the safe area" is
/// the single clearest difference between the mobile Form archetype and the
/// desktop pattern it is usually mistaken for, and a frame that does not draw
/// the safe area cannot show it.
List<String> _phone(Map s, {List<Object?> tabs = const []}) {
  const inner = _phoneW - 2;
  final archetype = _str(s['archetype']);
  final large = archetype == 'detail' || archetype == 'collection';
  final pushed = _str(s['tab']).isEmpty;

  final out = <String>['┌${_rule(inner)}┐'];
  out.add('│${_pad(' 9:41', inner - 10)}${_pad('▮▮▮  ▮▮', 10)}│');
  out.add('├${_rule(inner)}┤');

  // App bar. A pushed route carries a back chevron; a tab root does not.
  final leading = pushed ? ' ‹ ' : '   ';
  final trailing = _listOf(s['secondaryActions']).isEmpty ? '   ' : ' ⋯ ';
  final barTitle = large ? '' : _str(s['name']);
  out.add('│$leading${_pad(barTitle, inner - 6)}$trailing│');

  final body = <String>[];
  if (large) {
    body.add(_str(s['name']));
    if (_str(s['subtitle']).isNotEmpty) body.add(_str(s['subtitle']));
    body.add('');
  }
  body.addAll(_bodyFor(s));
  while (body.length < _minBodyRows) {
    body.add('');
  }

  out.add('├${_rule(inner)}┤');
  for (final l in body) {
    out.add('│ ${_pad(l, inner - 2)} │');
  }

  // The pinned bar: chrome, drawn between the content and the safe area.
  final primary = _str(s['primaryAction']);
  const pinned = <String>{
    'detail',
    'form',
    'sequence',
    'offer',
    'confirmation',
  };
  if (primary.isNotEmpty && pinned.contains(archetype)) {
    out.add('├${_rule(inner)}┤');
    // Full width, because that is the rule. A pinned primary drawn as a short
    // centred pill is the desktop button with a different y position, and the
    // drawing would be agreeing to something the archetype forbids.
    final icon = archetype == 'detail' ? '[ ● ] ' : '';
    final w = inner - 2 - icon.length;
    out.add('│ $icon[${_centre(primary, w - 2)}] │');
    if (archetype == 'offer') {
      // Under the button, inside the same bar. Drawing it anywhere else would
      // draw the defect: a renewal line the pinned chrome covers is one the
      // user meets at the charge instead of at the tap.
      for (final l in _wrap(_str(s['billing']), inner - 2)) {
        out.add('│ ${_pad(l, inner - 2)} │');
      }
      out.add(
        '│ ${_pad('${_str(s['restore'])}  ·  ${_str(s['terms'])}', inner - 2)} │',
      );
    }
  } else if (primary.isNotEmpty) {
    // Focal, Collection and Settings put their primary in the content or in
    // a FAB, so it is drawn floating over the body rather than as a bar.
    out.add('│ ${_pad('', inner - 2 - 14)}${_pad('( + $primary )', 14)} │');
  }

  // Only a tab root draws the tab bar. A pushed route covers it, which is why
  // its primary action has to be pinned rather than left to the nav.
  if (tabs.isNotEmpty && !pushed) {
    out.add('├${_rule(inner)}┤');
    final active = _str(s['tab']);
    final each = (inner - 2) ~/ tabs.length;
    final cells = StringBuffer();
    for (var i = 0; i < tabs.length; i++) {
      final label = '${tabs[i] == active ? '●' : '○'} ${tabs[i]}';
      // The remainder goes to the last cell, so the row is exactly as wide as
      // the frame instead of one column short of it.
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

// --- states ------------------------------------------------------------------

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

/// The states drawn, not promised — the copy is reviewable before it is
/// written. A collection draws four, because zero-results is a fourth screen.
List<String> _statesGrid(Map s) {
  const w = 24;
  final states = s['states'] is Map ? s['states'] as Map : const {};
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
      if (_str(s['primaryAction']).isNotEmpty) ...[
        '',
        '[ ${s['primaryAction']} ]',
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

// --- overlays ----------------------------------------------------------------

/// Sheets dock to the bottom edge and dialogs float; drawing them the same way
/// is how a plan ends up promising a dialog and shipping a sheet.
List<String> _overlayBox(Map o) {
  final kind = _str(o['kind']);
  final docked = kind == 'bottom-sheet' || kind == 'snap-sheet';
  final w = kind == 'snack-bar' ? 38 : 34;
  final inner = w - 2;
  final rows = <String>[];
  if (docked) rows.add(_centre('━━━━━━', inner));
  rows.add(
    ' ${_pad(_str(o['title']), inner - 4)}${kind == 'dialog' ? ' ✕ ' : '   '}',
  );
  if (_str(o['body']).isNotEmpty) {
    rows.add(' ${_rule(inner - 2)} ');
    for (final l in _wrap(_str(o['body']), inner - 2)) {
      rows.add(' ${_pad(l, inner - 2)} ');
    }
  }
  for (final f in _listOf(o['fields']).whereType<Map>()) {
    rows.add(' ${_pad(_str(f['label']), inner - 2)} ');
    rows.add(' [ ${_pad(_str(f['placeholder']), inner - 6)} ]');
  }
  final buttons = _listOf(o['buttons']).map((b) => '[ $b ]').join(' ');
  if (buttons.isNotEmpty) {
    rows.add(' ${_rule(inner - 2)} ');
    rows.add(' ${_pad(buttons.padLeft(inner - 2), inner - 2)} ');
  }
  return _boxOf(w, rows);
}

// --- markdown ----------------------------------------------------------------

// Trim trailing spaces only. `\s+$` with the multiline flag also eats the
// newline, which silently collapses the blank lines separating blocks inside a
// fence.
String _fence(List<String> lines) =>
    '```\n${lines.join('\n').replaceAll(RegExp(r'[ \t]+$', multiLine: true), '')}\n```';

List<String> _renderSurface(Map s, List<Object?> tabs) {
  final out = <String>[];
  final route = _str(s['route']);
  out.add('### ${s['name']}${route.isEmpty ? '' : ' · `$route`'}');
  out.add('');
  final purpose = _str(s['purpose']);
  out.add(
    'Archetype: `${s['archetype']}`${purpose.isEmpty ? '' : ' — $purpose'}',
  );
  out.add('');
  // Above the wireframe on purpose: a reviewer should read what the surface is
  // for before they read what it looks like.
  final moments = s['moments'] as Map? ?? const <String, Object?>{};
  out.add('**Peak** — ${moments['peak']}');
  out.add('');
  out.add('**End** — ${moments['end']}');
  out.add('');
  out.add('**Phone @390**');
  out.add('');
  out.add(_fence(_phone(s, tabs: tabs)));
  out.add('');
  out.add('**States**');
  out.add('');
  out.add(_fence(_statesGrid(s)));
  out.add('');
  out.add('Success: ${(s['states'] as Map)['success']}');
  out.add('');
  out.add('Held to:');
  out.add('');
  for (final r in _archetypeRules[_str(s['archetype'])] ?? const <String>[]) {
    out.add('- $r');
  }
  for (final r in _universalRules) {
    out.add('- $r');
  }
  out.add('');
  return out;
}

List<String> _renderOverlays(Map plan) {
  final overlays = _listOf(plan['overlays']).whereType<Map>().toList();
  if (overlays.isEmpty) return const [];
  final out = <String>['## Overlays', ''];
  for (final o in overlays) {
    out.add(
      _fence([
        _centre('${o['kind']} · ${o['id'] ?? o['title']}', 34),
        ..._overlayBox(o),
      ]),
    );
    out.add('');
  }
  return out;
}

List<String> _renderComponents(Map plan) {
  final components = _listOf(plan['components']).whereType<Map>().toList();
  if (components.isEmpty) return const [];
  return [
    '## Components',
    '',
    'Each choice states the neighbour it beat. `Use when:` / `Instead:` for every',
    'widget lives in `docs/references/design-system-reference-llms.txt`; the',
    'families where three widgets are all defensible live in',
    '`docs/principles/component-selection.md`.',
    '',
    '| Surface | Widget | Why this one | Not |',
    '| --- | --- | --- | --- |',
    ...components.map(
      (c) =>
          '| ${c['surface'] ?? '—'} | `${c['control']}` | '
          '${c['why']} | ${_str(c['rejected']).isEmpty ? '—' : '`${c['rejected']}`'} |',
    ),
    '',
  ];
}

List<String> _renderDataModel(Map plan) {
  final entities = _listOf(plan['entities']).whereType<Map>().toList();
  if (entities.isEmpty) return const [];
  final out = <String>['## Data model', ''];
  for (final e in entities) {
    out.add('- **${e['name']}**');
    for (final f in _listOf(e['fields']).whereType<Map>()) {
      final note = _str(f['note']);
      out.add(
        '  - `${f['name']}`: ${f['type']}${note.isEmpty ? '' : ' — $note'}',
      );
    }
    final relations = _listOf(e['relations']);
    if (relations.isNotEmpty) {
      out.add('  - _relations:_ ${relations.join('; ')}');
    }
  }
  out.add('');
  return out;
}

List<String> _renderEndpoints(Map plan) {
  final endpoints = _listOf(plan['endpoints']).whereType<Map>().toList();
  if (endpoints.isEmpty) return const [];
  return [
    '## API endpoints',
    '',
    'Each one needs a mock route in `lib/data/mock/mock_routes.dart` too, or the',
    'screen does not run offline and the golden cannot be recorded.',
    '',
    '| Method | Path | Auth | Purpose |',
    '| --- | --- | --- | --- |',
    ...endpoints.map(
      (e) =>
          '| ${e['method']} | `${e['path']}` | '
          '${e['auth'] == true ? 'yes' : 'no'} | ${e['purpose']} |',
    ),
    '',
  ];
}

List<String> _renderIntegration(Map plan) {
  final points = _listOf(plan['integration']).whereType<Map>().toList();
  if (points.isEmpty) return const [];
  final w = points.fold<int>(
    0,
    (m, i) => _str(i['from']).length > m ? _str(i['from']).length : m,
  );
  return [
    '## Integration points',
    '',
    _fence(
      points.map((i) {
        final note = _str(i['note']);
        return '  ${_pad(i['from'], w)}  ──▶  ${i['to']}'
            '${note.isEmpty ? '' : '   ($note)'}';
      }).toList(),
    ),
    '',
  ];
}

List<String> _renderBlastRadius(Map plan) {
  final b = plan['blastRadius'];
  if (b is! Map) return const [];
  final lines = <String>[];
  void tree(String label, List<Object?> files) {
    if (files.isEmpty) return;
    if (lines.isNotEmpty) lines.add('');
    lines.add('$label (${files.length})');
    for (var i = 0; i < files.length; i++) {
      lines.add('  ${i == files.length - 1 ? '└──' : '├──'} ${files[i]}');
    }
  }

  tree('new', _listOf(b['new']));
  tree('changed', _listOf(b['changed']));
  if (lines.isEmpty) return const [];
  return ['## Blast radius', '', _fence(lines), ''];
}

List<String> _renderVerification(Map plan) {
  final custom = _listOf(plan['verification']).map((v) => '$v').toList();
  final steps = custom.isNotEmpty
      ? custom
      : const [
          'flutter analyze',
          'dart run tool/ui_lint.dart',
          'dart run tool/plan_lint.dart',
          'dart run tool/design_system_reference.dart --check',
          'flutter test',
          'make golden',
        ];
  return [
    '## Verification plan',
    '',
    ...steps.map((s) => '- [ ] `$s`'),
    '- [ ] the screen runs on a device, not only in a test — '
        '`flutter run --dart-define=ENV=dev`',
    '',
  ];
}

/// The whole document. Throws when the plan does not validate: a drawing of an
/// invalid plan is a drawing of something nobody agreed to.
String renderFeaturePlanMarkdown(Object? input) {
  final errors = validateFeaturePlan(input);
  if (errors.isNotEmpty) {
    throw ArgumentError(
      'Invalid feature plan:\n${errors.map((e) => '  - $e').join('\n')}',
    );
  }
  final plan = input as Map;
  final f = plan['feature'] as Map;
  final surfaces = _listOf(plan['surfaces']).whereType<Map>().toList();
  final tabs = _listOf(plan['tabs']).isNotEmpty
      ? _listOf(plan['tabs'])
      // Mirrors the PageView in `lib/screens/home_screen.dart`. A plan may
      // override it; drawing tabs the app does not have is how a wireframe
      // starts describing another app.
      : const ['Home', 'Library', 'Settings'];

  final out = <String>[];
  out.add('<!-- feature-plan:v1 — generated, do not hand-edit.');
  out.add(
    '     Regenerate with: dart run tool/feature_plan.dart '
    '${f['id']}.feature-plan.json -o FEATURE-PLAN.md -->',
  );
  out.add('');
  out.add('# ${f['title']}');
  out.add('');
  out.add(
    '`${f['id']}` · ${surfaces.length} surface'
    '${surfaces.length == 1 ? '' : 's'}',
  );
  out.add('');
  out.add('## Problem');
  out.add('');
  out.add(_str(f['problem']));
  out.add('');
  final nonGoals = _listOf(f['nonGoals']);
  if (nonGoals.isNotEmpty) {
    out.add('## Not in this feature');
    out.add('');
    for (final n in nonGoals) {
      out.add('- $n');
    }
    out.add('');
  }
  out.add('## Surfaces');
  out.add('');
  for (final s in surfaces) {
    out.addAll(_renderSurface(s, tabs));
  }
  out.addAll(_renderOverlays(plan));
  out.addAll(_renderComponents(plan));
  out.addAll(_renderDataModel(plan));
  out.addAll(_renderEndpoints(plan));
  out.addAll(_renderIntegration(plan));
  out.addAll(_renderBlastRadius(plan));
  out.addAll(_renderVerification(plan));
  out.add('---');
  out.add('');
  out.add('Approve this before any file under `lib/` is written. Every frame');
  out.add(
    'above is drawn from this feature\'s plan JSON, so the picture and the',
  );
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
      'usage: dart run tool/feature_plan.dart <plan.json> '
      '[-o FEATURE-PLAN.md] [--check]',
    );
    exit(2);
  }
  final source = File(file);
  if (!source.existsSync()) {
    stderr.writeln('feature-plan: $file does not exist');
    exit(2);
  }

  Object? plan;
  try {
    plan = jsonDecode(source.readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('feature-plan: $file is not valid JSON: ${e.message}');
    exit(1);
  }

  final errors = validateFeaturePlan(plan);
  if (errors.isNotEmpty) {
    stderr.writeln('feature-plan: ${errors.length} problem(s) in $file');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }

  final surfaces = _listOf((plan as Map)['surfaces']).length;
  if (args.contains('--check')) {
    stdout.writeln(
      'feature-plan: $file is valid ($surfaces surface'
      '${surfaces == 1 ? '' : 's'})',
    );
    exit(0);
  }

  final md = renderFeaturePlanMarkdown(plan);
  final o = args.indexOf('-o');
  if (o != -1 && o + 1 < args.length) {
    File(args[o + 1]).writeAsStringSync(md);
    stdout.writeln(
      'feature-plan: $surfaces surface'
      '${surfaces == 1 ? '' : 's'} → ${args[o + 1]}',
    );
  } else {
    stdout.write(md);
  }
}
