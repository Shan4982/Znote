import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';
import 'file_storage.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Notebooks, Sections, Pages, PluginStates, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {},
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(notebooks, notebooks.parentId);
      }
    },
  );

  static Future<AppDatabase> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'note_app.sqlite');
    return AppDatabase(NativeDatabase(File(dbPath)));
  }

  // ── Notebooks ──
  Future<List<Notebook>> allNotebooks() =>
      (select(notebooks)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  Stream<List<Notebook>> watchAllNotebooks() =>
      (select(notebooks)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();

  Future<Notebook> getNotebook(String id) =>
      (select(notebooks)..where((t) => t.id.equals(id))).getSingle();

  Future<void> createNotebook(NotebooksCompanion entry) =>
      into(notebooks).insert(entry);

  Future<void> updateNotebook(String id, NotebooksCompanion entry) =>
      (update(notebooks)..where((t) => t.id.equals(id))).write(entry);

  Future<void> deleteNotebook(String id) =>
      (delete(notebooks)..where((t) => t.id.equals(id))).go();

  Future<List<Notebook>> childNotebooks(String parentId) =>
      (select(notebooks)
        ..where((t) => t.parentId.equals(parentId))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Stream<List<Notebook>> watchChildNotebooks(String parentId) =>
      (select(notebooks)
        ..where((t) => t.parentId.equals(parentId))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<List<Notebook>> rootNotebooks() =>
      (select(notebooks)
        ..where((t) => t.parentId.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Stream<List<Notebook>> watchRootNotebooks() =>
      (select(notebooks)
        ..where((t) => t.parentId.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  // ── Pages ──
  Future<List<NotePage>> notebookPages(String notebookId) =>
      (select(pages)
            ..where((t) => t.notebookId.equals(notebookId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Stream<List<NotePage>> watchNotebookPages(String notebookId) =>
      (select(pages)
            ..where((t) => t.notebookId.equals(notebookId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<void> createPage(PagesCompanion entry) => into(pages).insert(entry);

  Future<void> updatePage(String id, PagesCompanion entry) =>
      (update(pages)..where((t) => t.id.equals(id))).write(entry);

  Future<void> deletePage(String id) =>
      (delete(pages)..where((t) => t.id.equals(id))).go();

  // ── Plugin states ──
  Future<List<PluginState>> enabledPlugins() =>
      (select(pluginStates)..where((t) => t.enabled.equals(true))).get();

  Future<List<PluginState>> allPluginStates() => select(pluginStates).get();

  Future<void> setPluginEnabled(String pluginId, bool enabled) =>
      into(pluginStates).insertOnConflictUpdate(
        PluginStatesCompanion(pluginId: Value(pluginId), enabled: Value(enabled)),
      );

  Future<void> upsertPluginState(PluginStatesCompanion entry) =>
      into(pluginStates).insertOnConflictUpdate(entry);

  // ── Settings ──
  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      into(appSettings).insertOnConflictUpdate(AppSettingsCompanion(key: Value(key), value: Value(value)));
}
