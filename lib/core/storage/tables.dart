import 'package:drift/drift.dart';

@DataClassName('Notebook')
class Notebooks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get coverColor => integer()(); // ARGB int
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Section')
class Sections extends Table {
  TextColumn get id => text()();
  TextColumn get notebookId => text().references(Notebooks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('NotePage')
class Pages extends Table {
  TextColumn get id => text()();
  TextColumn get notebookId => text().references(Notebooks, #id, onDelete: KeyAction.cascade)();
  TextColumn get sectionId => text().nullable().references(Sections, #id, onDelete: KeyAction.setNull)();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get paperType => text().withDefault(const Constant('blank'))(); // blank / ruled / grid / dotted
  IntColumn get backgroundColor => integer().withDefault(const Constant(0xFFFFFFFF))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PluginState')
class PluginStates extends Table {
  TextColumn get pluginId => text()();
  BoolColumn get enabled => boolean()();
  IntColumn get sortOrder => integer()();
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {pluginId};
}

@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
