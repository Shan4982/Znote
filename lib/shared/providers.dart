import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/storage/database.dart';
import '../core/storage/file_storage.dart';
import '../core/plugin/plugin_manager.dart';
import '../core/plugin/plugin_interface.dart';
import '../core/plugin/plugins/pen_tool.dart';
import '../core/plugin/plugins/eraser_tool.dart';
import '../core/plugin/plugins/lasso_tool.dart';
import '../core/ink/ink_engine.dart';
import '../core/ink/document_engine.dart';

part 'providers.g.dart';

@riverpod
Future<AppDatabase> database(DatabaseRef ref) async {
  final db = await AppDatabase.create();
  ref.onDispose(() => db.close());
  return db;
}

@riverpod
Future<FileStorage> fileStorage(FileStorageRef ref) async {
  final fs = FileStorage();
  await fs.init();
  return fs;
}

@riverpod
Future<PluginManager> pluginManager(PluginManagerRef ref) async {
  final db = await ref.watch(databaseProvider.future);
  final pm = PluginManager(db);

  // Register all built-in plugins
  pm.register(PenTool());
  pm.register(EraserTool());
  pm.register(LassoTool());

  await pm.loadStates();
  return pm;
}

@riverpod
class InkEngineNotifier extends _$InkEngineNotifier {
  @override
  InkEngine build() => InkEngine();

  void setColor(Color c) => state.setColor(c);
  void setWidth(double w) => state.setWidth(w);
  void onPointerDown(dynamic event) => state.onPointerDown(event);
  void onPointerMove(dynamic event) => state.onPointerMove(event);
  void onPointerUp(dynamic event) => state.onPointerUp(event);
  void undo() => state.undo();
  void clear() => state.clear();
}

@riverpod
DocumentEngine documentEngine(DocumentEngineRef ref) => DocumentEngine();
