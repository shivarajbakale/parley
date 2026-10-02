import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/data/library_repository.dart';
import 'package:parley_android/models/library_item.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/services/auth/auth_models.dart';
import 'package:parley_android/services/auth/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The data every screen baseline is recorded against.
///
/// Shared rather than declared per suite: the screen sheets and the identity
/// sheets are pictures of the same screens, and two copies of this list is two
/// chances for them to drift into being pictures of different apps.
///
/// Three categories, deliberately distinct: the Library's filter strip is
/// derived from the values present in the data, so fixture items that all
/// share a category record a baseline of a two-chip strip and the real one is
/// never seen.
const List<LibraryItem> demoItems = <LibraryItem>[
  LibraryItem(
    id: '1',
    category: 'Design',
    title: 'Designing for the platform',
    subtitle: 'Six chapters · 42 min',
    detail:
        'What "native" means on each side, and what it costs to ignore '
        'it. The chapter the rest of the kit is built on.',
    iconName: 'star',
    minutes: 42,
    progress: 0.4,
  ),
  LibraryItem(
    id: '2',
    category: 'Guides',
    title: 'Depth without decoration',
    subtitle: 'Four chapters · 26 min',
    detail:
        'A surface ladder, an elevation contract, and the one layer '
        'that is allowed to float.',
    iconName: 'book',
    minutes: 26,
    progress: 1.0,
  ),
  LibraryItem(
    id: '3',
    category: 'Modules',
    title: 'Motion that means something',
    subtitle: 'Three chapters · 18 min',
    detail:
        'Springs where a gesture continues, curves where nothing was '
        'thrown.',
    iconName: 'bolt',
    minutes: 18,
    progress: 0,
  ),
];

/// One scope for the whole sheet: the frames differ by theme, not by state,
/// so four containers would only be four chances to diverge.
Widget demoScope(SharedPreferences prefs, Widget child) => ProviderScope(
  overrides: <Override>[
    sharedPreferencesProvider.overrideWithValue(prefs),
    tokenStoreProvider.overrideWithValue(
      InMemoryTokenStore(
        const AuthSession(
          user: AuthUser(
            id: 'usr_golden',
            email: 'ada@rocketship.dev',
            displayName: 'Ada Lovelace',
          ),
          accessToken: 'golden',
        ),
      ),
    ),
    // Fixed data rather than the mock backend: a baseline recorded
    // against a network call, however faked, records whatever the timing
    // happened to be on the machine that recorded it.
    libraryItemsProvider.overrideWith((Ref ref) => demoItems),
  ],
  child: child,
);
