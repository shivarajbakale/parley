import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/data/local/app_database.dart';
import 'package:parley_android/models/library_item.dart';

/// Covers the codegen layer: the freezed + json model and the Drift database.
void main() {
  test('freezed model: copyWith, equality, and JSON roundtrip', () {
    const item = LibraryItem(
      id: 'getting-started',
      title: 'Getting Started',
      subtitle: 'Set up your first feature slice',
      detail: 'Run the add-feature skill.',
      iconName: 'rocket',
    );

    final renamed = item.copyWith(title: 'Getting Started, again');
    expect(renamed.title, 'Getting Started, again');
    expect(renamed.id, item.id);
    expect(renamed, isNot(item)); // value equality

    expect(LibraryItem.fromJson(renamed.toJson()), renamed);
  });

  test('icon keys resolve, and an unknown key degrades to a fallback', () {
    const known = LibraryItem(
      id: 'a',
      title: 'a',
      subtitle: 'a',
      detail: 'a',
      iconName: 'rocket',
    );
    expect(known.icon, libraryIcons['rocket']);

    // A backend that sends a key this build doesn't know must not crash the UI.
    const unknown = LibraryItem(
      id: 'b',
      title: 'b',
      subtitle: 'b',
      detail: 'b',
      iconName: 'not-a-real-icon',
    );
    expect(unknown.icon, Icons.star_outline);
  });

  test('every seeded demo item declares a known icon key', () {
    for (final item in demoLibraryItems) {
      expect(
        libraryIcons.containsKey(item.iconName),
        isTrue,
        reason: '${item.id} uses an unmapped icon key "${item.iconName}"',
      );
    }
  });

  test('Drift: insert, read, and delete notes (in-memory)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final id = await db.addNote('first');
    await db.addNote('second');

    var notes = await db.allNotes();
    expect(notes.length, 2);
    expect(notes.map((n) => n.body), containsAll(['first', 'second']));

    await db.deleteNote(id);
    notes = await db.allNotes();
    expect(notes.length, 1);
  });
}
