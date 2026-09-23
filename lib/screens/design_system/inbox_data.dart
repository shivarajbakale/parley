import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';

/// The four tabs the inbox ships. Each one is a slice of [demoInboxItems];
/// the same item can appear in [all] and in a narrower section, the way the
/// same Slack message can be in "All" and "Mentions".
///
/// Lives at the top because the segmented-control sort reaches into these
/// values to gate which items it considers, and reading the slice logic
/// "which items show under this tab" needs the section names visible.
enum InboxSection { all, mentions, assigned, archived }

/// How the inbox sorts the items under the active section. These are the
/// three ways every inbox app sorts — by time, by inverse time, or by what
/// the user is most likely to need to act on first.
enum InboxSort { newest, oldest, priority }

/// What kind of action a notification invites. Drives the leading avatar
/// glyph and the meta chip's tone — a comment reads as neutral, a mention
/// reads as info, an assigned task reads as warning, an alert reads as error,
/// a digest is success.
enum InboxItemKind { comment, mention, assigned, alert, digest }

/// One notification row. A value type, not a Freezed model, because the demo
/// page has no repository, no provider and no serialisation — the same
/// pattern as `BlogArticle` in `blog_data.dart` next door.
@immutable
class InboxItem {
  // ignore: prefer_const_constructors_in_immutables
  InboxItem({
    required this.id,
    required this.kind,
    required this.section,
    required this.senderName,
    required this.subject,
    required this.preview,
    required this.timestamp,
    this.isUnread = false,
    this.priority = 0,
  });

  /// Stable id, used as the key for taps and dismissals. The id is also
  /// the test fixture's contract — tests assert on it.
  final String id;

  /// What the notification is about. Drives the avatar glyph and the chip.
  final InboxItemKind kind;

  /// Which section this row belongs to under. The same item can be in
  /// [InboxSection.all] and a narrower one (e.g. mentions), the way a Slack
  /// message is in both `#channel` and "Mentions".
  final Set<InboxSection> section;

  /// Used by `DSAvatar.fromName` to derive initials and a colour identity.
  final String senderName;

  /// "Ada commented on Tokens". The action-verb pattern that keeps an
  /// inbox scannable — the title says who did what, the preview says to what.
  final String subject;

  /// The message body preview, truncated to two lines by `DSListTile`.
  final String preview;

  /// When it happened. The sort segmented control reads this directly.
  final DateTime timestamp;

  /// Whether the unread dot / count chip paint in the meta row.
  final bool isUnread;

  /// 0 normal, 1 high, 2 urgent. The priority sort reads this descending.
  final int priority;

  /// The chip tone — the same value the segmented control cannot reach, so
  /// the kind is the right place for it.
  DSTone get tone => switch (kind) {
    InboxItemKind.comment => DSTone.neutral,
    InboxItemKind.mention => DSTone.info,
    InboxItemKind.assigned => DSTone.warning,
    InboxItemKind.alert => DSTone.error,
    InboxItemKind.digest => DSTone.success,
  };

  /// The avatar glyph that goes with the kind — a comment gets a chat
  /// bubble, a mention gets an "@", an assignment gets a flag. Read by the
  /// list tile through `_AvatarForKind`.
  IconData get kindIcon => switch (kind) {
    InboxItemKind.comment => Icons.chat_bubble_outline,
    InboxItemKind.mention => Icons.alternate_email,
    InboxItemKind.assigned => Icons.flag_outlined,
    InboxItemKind.alert => Icons.priority_high_rounded,
    InboxItemKind.digest => Icons.summarize_outlined,
  };

  /// The chip label. Kept short — the meta slot is one row, and the chip is
  /// sharing it with a timestamp.
  String get kindLabel => switch (kind) {
    InboxItemKind.comment => 'Comment',
    InboxItemKind.mention => 'Mention',
    InboxItemKind.assigned => 'Assigned',
    InboxItemKind.alert => 'Alert',
    InboxItemKind.digest => 'Digest',
  };
}

// `DateTime.utc` is not a `const` expression on the version of Dart this
// project ships, which is why every item below uses a `final` date and the
// `InboxItem` constructor above is non-const. Five named dates at the top
// give the comments meaningful relative-time anchors without dragging a
// clock into the demo.

final DateTime _tMinus0 = DateTime.utc(2026, 8, 31, 9, 12);
final DateTime _tMinus1 = DateTime.utc(2026, 8, 31, 8, 27);
final DateTime _tMinus2 = DateTime.utc(2026, 8, 30, 22, 3);
final DateTime _tMinus3 = DateTime.utc(2026, 8, 30, 19, 41);
final DateTime _tMinus4 = DateTime.utc(2026, 8, 30, 16, 14);
final DateTime _tMinus5 = DateTime.utc(2026, 8, 30, 11, 58);
final DateTime _tMinus6 = DateTime.utc(2026, 8, 29, 14, 6);
final DateTime _tMinus7 = DateTime.utc(2026, 8, 29, 9, 33);
final DateTime _tMinus8 = DateTime.utc(2026, 8, 28, 18, 12);
final DateTime _tMinus9 = DateTime.utc(2026, 8, 28, 13, 47);
final DateTime _tMinus10 = DateTime.utc(2026, 8, 27, 21, 18);
final DateTime _tMinus11 = DateTime.utc(2026, 8, 27, 8, 2);

/// The shipped demo inbox. Twelve items so every section has at least one
/// row but no section has so many that the list stops feeling curated.
///
/// Hand-written rather than generated: a real-feeling inbox has a shape
/// (urgent things on top, digests at the bottom, mentions mixed through)
/// that random data does not produce, and the demo is at its strongest when
/// a reader recognises it as plausible rather than synthetic.
final List<InboxItem> demoInboxItems = [
  InboxItem(
    id: 'inbox-001',
    kind: InboxItemKind.alert,
    section: const {InboxSection.all, InboxSection.assigned},
    senderName: 'Ada Okafor',
    subject: 'flagged a regression in Tokens / Motion',
    preview:
        'The spring constant on the page transition dropped to 180 N/m '
        'between 14:00 and 15:00 — please check tokens#motion before the '
        'release tag.',
    timestamp: _tMinus0,
    isUnread: true,
    priority: 2,
  ),
  InboxItem(
    id: 'inbox-002',
    kind: InboxItemKind.mention,
    section: const {InboxSection.all, InboxSection.mentions},
    senderName: 'Kai Nakamura',
    subject: 'asked you to review a pull request',
    preview:
        'kit/pulls/482 — three new affordances on DSListTile. The '
        'subtitle-max-lines lint is the one I am least sure about.',
    timestamp: _tMinus1,
    isUnread: true,
    priority: 1,
  ),
  InboxItem(
    id: 'inbox-003',
    kind: InboxItemKind.comment,
    section: const {InboxSection.all},
    senderName: 'Lin Park',
    subject: 'replied to your comment on Type Roles',
    preview:
        'Agree that "display" should never be used for body copy. The '
        'open question is whether the lint should warn or error.',
    timestamp: _tMinus2,
    isUnread: true,
    priority: 0,
  ),
  InboxItem(
    id: 'inbox-004',
    kind: InboxItemKind.digest,
    section: const {InboxSection.all, InboxSection.archived},
    senderName: 'Rocketship',
    subject: 'weekly digest — 32 PRs merged, 4 awaiting review',
    preview:
        'Highlights: DSFieldBox border now sits on the outer edge, '
        'DSBottomSheet scroll area drag is fixed, the iOS back gesture is '
        'back on the three list routes.',
    timestamp: _tMinus3,
    isUnread: false,
    priority: 0,
  ),
  InboxItem(
    id: 'inbox-005',
    kind: InboxItemKind.assigned,
    section: const {InboxSection.all, InboxSection.assigned},
    senderName: 'Maya Singh',
    subject: 'assigned you a ticket',
    preview:
        'kit/2204 — DSTabBar and DSSegmentedButton both need their own '
        'demo page. Both components ship, but they have never appeared '
        'together.',
    timestamp: _tMinus4,
    isUnread: true,
    priority: 2,
  ),
  InboxItem(
    id: 'inbox-006',
    kind: InboxItemKind.mention,
    section: const {InboxSection.all, InboxSection.mentions},
    senderName: 'Theo Almeida',
    subject: 'mentioned you in #design-system',
    preview:
        '@here — can someone confirm whether the segmented control '
        'indicator should overshoot on spring or settle without one?',
    timestamp: _tMinus5,
    isUnread: false,
    priority: 1,
  ),
  InboxItem(
    id: 'inbox-007',
    kind: InboxItemKind.comment,
    section: const {InboxSection.all, InboxSection.archived},
    senderName: 'Iris Wen',
    subject: 'commented on Card Variants',
    preview:
        'The "filled" card variant reads as a button on light, and as '
        'a divider on dark. Worth a dedicated plan.',
    timestamp: _tMinus6,
    isUnread: false,
    priority: 0,
  ),
  InboxItem(
    id: 'inbox-008',
    kind: InboxItemKind.mention,
    section: const {InboxSection.all, InboxSection.mentions},
    senderName: 'Ada Okafor',
    subject: 'tagged you in a design review',
    preview:
        '@you — the segment widths on the third screenshot look uneven. '
        'Is that the equal-sizing path or the content-sizing one?',
    timestamp: _tMinus7,
    isUnread: false,
    priority: 1,
  ),
  InboxItem(
    id: 'inbox-009',
    kind: InboxItemKind.comment,
    section: const {InboxSection.all},
    senderName: 'Kai Nakamura',
    subject: 'pushed 4 commits to scaffold-core',
    preview:
        'Refactored the route table so the home subroute list reads as '
        'a single tree. No behavioural changes; tests still green.',
    timestamp: _tMinus8,
    isUnread: false,
    priority: 0,
  ),
  InboxItem(
    id: 'inbox-010',
    kind: InboxItemKind.alert,
    section: const {InboxSection.all, InboxSection.archived},
    senderName: 'CI',
    subject: 'build failed on main',
    preview:
        'test/probe/debt_test.dart failed at "the segmented control '
        'indicator paints under the chosen segment". Pipeline blocked.',
    timestamp: _tMinus9,
    isUnread: false,
    priority: 2,
  ),
  InboxItem(
    id: 'inbox-011',
    kind: InboxItemKind.digest,
    section: const {InboxSection.all, InboxSection.archived},
    senderName: 'Rocketship',
    subject: 'release notes — v0.3.0',
    preview:
        'New: DSTabBar + DSSegmentedButton demos. Fixed: '
        'iOS back gesture on list routes. Improved: DSFieldBox '
        'border sits on the outer edge.',
    timestamp: _tMinus10,
    isUnread: false,
    priority: 0,
  ),
  InboxItem(
    id: 'inbox-012',
    kind: InboxItemKind.comment,
    section: const {InboxSection.all, InboxSection.archived},
    senderName: 'Maya Singh',
    subject: 'left a note on the inbox demo plan',
    preview:
        'One section per kind may be too clever — better to group by '
        "tonal urgency (urgent / soon / fyi), which is what the user's "
        'eye actually does.',
    timestamp: _tMinus11,
    isUnread: false,
    priority: 0,
  ),
];

/// The label of each section, in display order. The tab bar reads this
/// directly, which is why the order is its order and not an alphabetical one.
({String label, IconData icon, int? count}) sectionSummary(
  InboxSection section,
) {
  final count = demoInboxItems.where((i) => i.section.contains(section)).length;
  return switch (section) {
    InboxSection.all => (
      label: 'All',
      icon: Icons.inbox_outlined,
      count: count,
    ),
    InboxSection.mentions => (
      label: 'Mentions',
      icon: Icons.alternate_email,
      count: count,
    ),
    InboxSection.assigned => (
      label: 'Assigned',
      icon: Icons.flag_outlined,
      count: count,
    ),
    InboxSection.archived => (
      label: 'Archived',
      icon: Icons.inventory_2_outlined,
      count: count,
    ),
  };
}

/// The items under [section], in the order [sort] says.
List<InboxItem> inboxItems(InboxSection section, InboxSort sort) {
  final items = demoInboxItems
      .where((i) => i.section.contains(section))
      .toList(growable: false);
  return switch (sort) {
    InboxSort.newest =>
      items..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
    InboxSort.oldest =>
      items..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
    // Priority desc, then newest first within a priority band — the
    // exception that proves the rule: a same-priority row reads as "same
    // size", so the secondary order is what tells them apart.
    InboxSort.priority =>
      items..sort((a, b) {
        final byPriority = b.priority.compareTo(a.priority);
        if (byPriority != 0) return byPriority;
        return b.timestamp.compareTo(a.timestamp);
      }),
  };
}

/// Whether [section] has any items in it. Empty sections would render the
/// segmented control in a useless state, so the page reads this before
/// deciding what to show.
bool inboxSectionHasItems(InboxSection section) =>
    demoInboxItems.any((i) => i.section.contains(section));

/// A short, human-readable relative-time for [date] relative to [now]. Kept
/// here (next to the data) rather than next to the row, because a future test
/// will want the same wording.
String relativeTime(DateTime date, {DateTime? now}) {
  final reference = now ?? inboxReferenceNow;
  final delta = reference.difference(date);
  if (delta.inSeconds < 60) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  if (delta.inDays < 7) return '${delta.inDays}d ago';
  // Older than a week — show a short date, which is what every inbox does
  // past the "this week" boundary.
  return '${date.year}-${date.month.toString().padLeft(2, '0')}'
      '-${date.day.toString().padLeft(2, '0')}';
}

/// The reference "now" the page renders relative-time against. A `final`
/// rather than `DateTime.now()` so the demo's timestamps read as the same
/// string on every render, and tests assert against a stable value rather
/// than a moving target.
final DateTime inboxReferenceNow = DateTime.utc(2026, 8, 31, 10, 0);
