import 'package:flutter/material.dart';

/// The two things the profile's segmented control switches between.
enum ProfileSection { activity, badges }

/// One row of the activity list: something the reader did, and when.
@immutable
class ProfileActivity {
  const ProfileActivity({
    required this.icon,
    required this.title,
    required this.timeAgo,
  });

  final IconData icon;
  final String title;
  final String timeAgo;
}

/// One earned badge: a name, the icon it reads as a glyph, and the one line
/// that explains what it took to earn it — the line a badge with no
/// explanation never has.
@immutable
class ProfileBadge {
  const ProfileBadge({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;
}

const demoActivity = <ProfileActivity>[
  ProfileActivity(
    icon: Icons.menu_book_outlined,
    title: 'Finished a guide',
    timeAgo: '2h ago',
  ),
  ProfileActivity(
    icon: Icons.bookmark_border,
    title: 'Saved an article',
    timeAgo: 'Yesterday',
  ),
  ProfileActivity(
    icon: Icons.local_fire_department_outlined,
    title: 'Started a streak',
    timeAgo: '3 days ago',
  ),
  ProfileActivity(
    icon: Icons.rate_review_outlined,
    title: 'Left a review',
    timeAgo: '1 week ago',
  ),
  ProfileActivity(
    icon: Icons.groups_outlined,
    title: 'Invited a teammate',
    timeAgo: '1 week ago',
  ),
  ProfileActivity(
    icon: Icons.download_outlined,
    title: 'Saved a guide offline',
    timeAgo: '2 weeks ago',
  ),
  ProfileActivity(
    icon: Icons.edit_note_outlined,
    title: 'Added a note to a guide',
    timeAgo: '2 weeks ago',
  ),
  ProfileActivity(
    icon: Icons.person_add_alt,
    title: 'Joined the beta',
    timeAgo: '1 month ago',
  ),
];

const demoBadges = <ProfileBadge>[
  ProfileBadge(
    icon: Icons.local_fire_department_outlined,
    label: 'On a streak',
    detail: '5 days reading in a row',
  ),
  ProfileBadge(
    icon: Icons.school_outlined,
    label: 'Early adopter',
    detail: 'Joined in the first month',
  ),
  ProfileBadge(
    icon: Icons.emoji_events_outlined,
    label: 'Finisher',
    detail: 'Completed 10 guides',
  ),
  ProfileBadge(
    icon: Icons.groups_outlined,
    label: 'Referrer',
    detail: 'Invited 3 friends who joined',
  ),
];

/// The badge the reader is working towards, and how far along they are.
///
/// A wall of earned badges raises one question and answers none of it: what
/// is next, and how close am I? Without this the Badges tab was a chip wrap
/// and a paragraph, and `ui-probe`'s `dead-band` rule measured 240pt of
/// nothing under it.
class ProfileNextBadge {
  const ProfileNextBadge({
    required this.label,
    required this.detail,
    required this.progress,
    required this.total,
  });

  final String label;

  /// What earning it takes, in the reader's own terms.
  final String detail;

  /// How much of [total] is done.
  final int progress;
  final int total;
}

const demoNextBadge = ProfileNextBadge(
  label: 'Marathon',
  detail: 'Read on 30 separate days',
  progress: 5,
  total: 30,
);
