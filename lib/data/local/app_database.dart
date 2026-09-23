import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Example offline table. Replace/extend with your own tables, then `make gen`.
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Drift database — typed, reactive, offline SQL. The default constructor opens
/// an on-device SQLite file via `drift_flutter`; tests pass an in-memory
/// executor (e.g. `AppDatabase(NativeDatabase.memory())`).
///
/// Exposed app-wide via `appDatabaseProvider` in
/// `lib/providers/database_provider.dart`.
@DriftDatabase(tables: [Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'app_db'));

  @override
  int get schemaVersion => 1;

  Future<List<Note>> allNotes() =>
      (select(notes)..orderBy([(n) => OrderingTerm.desc(n.createdAt)])).get();

  Stream<List<Note>> watchNotes() =>
      (select(notes)..orderBy([(n) => OrderingTerm.desc(n.createdAt)])).watch();

  Future<int> addNote(String body) =>
      into(notes).insert(NotesCompanion.insert(body: body));

  Future<int> deleteNote(int id) =>
      (delete(notes)..where((n) => n.id.equals(id))).go();
}
